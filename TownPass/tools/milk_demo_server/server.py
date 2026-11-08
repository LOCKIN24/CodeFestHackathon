#!/usr/bin/env python3
"""Temporary, in-memory LAN relay for the Town Pass hackathon.

Do not expose publicly. Never submit student names, schools or card numbers.
Restarting clears all families and invalidates all device tokens.
"""
import argparse
import json
import ipaddress
import math
import re
import secrets
import threading
import time
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

lock = threading.RLock()
families = {}
children_tokens = {}
invitations = {}
attempts = {}
demo_parent_tokens = set()
demo_transactions = {}


def token():
    return secrets.token_urlsafe(32)


def invite_code():
    return ''.join(secrets.choice('ABCDEFGHJKLMNPQRSTUVWXYZ23456789') for _ in range(12))


def safe_record(data):
    if not isinstance(data, dict):
        raise ValueError('invalid record')
    week, product, date = data.get('week'), data.get('product'), data.get('date')
    if not isinstance(week, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}', week):
        raise ValueError('invalid week')
    if product not in ('鮮奶', '豆漿') or not isinstance(date, str) or len(date) > 24:
        raise ValueError('invalid record')
    return {'week': week, 'product': product, 'date': date}


def taipei_time():
    return datetime.fromtimestamp(time.time(), timezone(timedelta(hours=8)))


def current_week(now):
    return (now.date() - timedelta(days=now.weekday())).isoformat()


def current_outing(child, now=None):
    outing = child.get('outing')
    if outing and outing['week'] == current_week(now or taipei_time()):
        return outing
    return None


def child_profile(child):
    # Retain the last outing internally, but never present last week's plan as
    # current. A new week starts with revision zero on both devices.
    profile = {key: value for key, value in child.items() if key != 'outing'}
    outing = current_outing(child)
    if outing is not None:
        profile['outing'] = outing
    return profile


def safe_store(data):
    if not isinstance(data, dict) or not {'name', 'latitude', 'longitude'} <= set(data):
        raise ValueError('invalid store')
    if set(data) - {'name', 'latitude', 'longitude', 'address'}:
        raise ValueError('invalid store fields')
    name, address = data['name'], data.get('address', '')
    if not isinstance(name, str) or not 1 <= len(name.strip()) <= 120:
        raise ValueError('invalid store name')
    if not isinstance(address, str) or len(address) > 240:
        raise ValueError('invalid store address')
    if any(ord(character) < 32 or ord(character) == 127 for character in name + address):
        raise ValueError('invalid store text')
    for field, limit in (('latitude', 90), ('longitude', 180)):
        value = data[field]
        if type(value) not in (int, float) or not -limit <= value <= limit or not math.isfinite(value):
            raise ValueError('invalid coordinates')
    return {'name': name.strip(), 'address': address.strip(),
            'latitude': data['latitude'], 'longitude': data['longitude']}


def safe_planned_at(value, now):
    if not isinstance(value, str) or len(value) > 40:
        raise ValueError('invalid planned time')
    try:
        instant = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if instant.tzinfo is None or instant.utcoffset() != timedelta(0):
            raise ValueError('planned time must be UTC')
        local = instant.astimezone(now.tzinfo)
    except (ValueError, OverflowError):
        raise ValueError('invalid planned time') from None
    if instant <= now or current_week(local) != current_week(now):
        raise ValueError('planned time must be future and in this week')
    return instant.isoformat(timespec='seconds')


def add_record(child, record):
    if not any(r['week'] == record['week'] for r in child['records']):
        child['records'].insert(0, record)
    outing = current_outing(child)
    if outing and outing['week'] == record['week'] and outing['status'] in ('requested', 'planned'):
        child['outing'] = {**outing, 'status': 'completed',
                           'revision': outing['revision'] + 1,
                           'updatedAt': taipei_time().isoformat(timespec='seconds')}


class Handler(BaseHTTPRequestHandler):
    server_version = 'MilkDemo/1'

    def log_message(self, fmt, *args):
        # Codes, credentials and personal information must not reach logs.
        pass

    def reply(self, code, value):
        body = json.dumps(value, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_json(self):
        lengths = self.headers.get_all('Content-Length', [])
        if len(lengths) > 1 or self.headers.get('Transfer-Encoding') is not None:
            raise ValueError('unsupported request framing')
        raw_length = lengths[0] if lengths else '0'
        if not re.fullmatch(r'[0-9]+', raw_length):
            raise ValueError('invalid content length')
        length = int(raw_length)
        if length > 8192:
            raise ValueError('request too large')
        self.connection.settimeout(5)
        payload = self.rfile.read(length)
        if len(payload) != length:
            raise ValueError('incomplete request')
        result = json.loads(payload or b'{}')
        if not isinstance(result, dict):
            raise ValueError('invalid request')
        return result

    def auth(self):
        header = self.headers.get('Authorization', '')
        return header[7:] if header.startswith('Bearer ') else ''

    def do_GET(self):
        with lock:
            if self.path == '/v1/health':
                return self.reply(200, {'ok': True})
            credential = self.auth()
            if self.path == '/v1/parent/children' and credential in families:
                return self.reply(200, {'children': [child_profile(child) for child in families[credential].values()]})
            if self.path == '/v1/child/profile' and credential in children_tokens:
                parent, child_id = children_tokens[credential]
                return self.reply(200, {'child': child_profile(families[parent][child_id])})
            self.reply(401, {'error': '連線已失效，請重新連結。'})

    def do_POST(self):
        try:
            body = self.read_json()
            with lock:
                return self.route(body)
        except (ValueError, KeyError, TypeError, TimeoutError):
            self.close_connection = True
            self.reply(400, {'error': '資料格式不正確。'})

    def route(self, body):
        credential = self.auth()
        if self.path.startswith('/v1/demo/'):
            if not getattr(self.server, 'demo_transactions_enabled', False):
                return self.reply(404, {'error': '此服務未開啟模擬交易。'})
            return self.demo_route(body, credential)
        if self.path == '/v1/families':
            parent = token()
            families[parent] = {}
            return self.reply(201, {'parentToken': parent})
        if self.path == '/v1/join':
            addr = self.client_address[0]
            now = time.time()
            attempts[addr] = [t for t in attempts.get(addr, []) if now - t < 60]
            if len(attempts[addr]) >= 12:
                return self.reply(429, {'error': '嘗試次數過多，請稍後再試。'})
            attempts[addr].append(now)
            code = str(body.get('code', '')).upper().replace(' ', '').replace('-', '')
            entry = invitations.get(code)
            if not entry or entry[2] <= now:
                invitations.pop(code, None)
                return self.reply(404, {'error': '邀請碼無效或已過期。'})
            invitations.pop(code)
            parent, child_id, _ = entry
            access = token()
            children_tokens[access] = (parent, child_id)
            return self.reply(200, {'childToken': access, 'child': child_profile(families[parent][child_id])})
        if credential in families:
            family = families[credential]
            if self.path == '/v1/parent/children':
                child_id = body.get('childId', '')
                alias = body.get('alias', '')
                if not re.fullmatch(r'[0-9a-f]{32}', child_id) or not re.fullmatch(r'孩子[1-9][0-9]?', alias):
                    raise ValueError('invalid child')
                child = family.setdefault(child_id, {'id': child_id, 'alias': alias, 'records': []})
                return self.reply(200, {'child': child_profile(child)})
            if self.path == '/v1/parent/invitations':
                child_id = body['childId']
                if child_id not in family:
                    return self.reply(404, {'error': '找不到子女資料。'})
                for old_code, invitation in list(invitations.items()):
                    if invitation[:2] == (credential, child_id):
                        del invitations[old_code]
                code = invite_code()
                invitations[code] = (credential, child_id, time.time() + 600)
                return self.reply(200, {'code': code, 'expiresIn': 600})
            if self.path == '/v1/parent/revoke':
                child_id = body['childId']
                if child_id not in family:
                    return self.reply(404, {'error': '找不到子女資料。'})
                for access, linked in list(children_tokens.items()):
                    if linked == (credential, child_id):
                        del children_tokens[access]
                for code, invite in list(invitations.items()):
                    if invite[:2] == (credential, child_id):
                        del invitations[code]
                return self.reply(200, {'ok': True})
            if self.path == '/v1/parent/outing':
                child_id = body.get('childId')
                if not isinstance(child_id, str):
                    raise ValueError('invalid child')
                if child_id not in family:
                    return self.reply(404, {'error': '找不到子女資料。'})
                return self.outing_route(family[child_id], body, parent=True)
            if self.path == '/v1/parent/record':
                child_id = body['childId']
                if child_id not in family:
                    return self.reply(404, {'error': '找不到子女資料。'})
                add_record(family[child_id], safe_record(body['record']))
                return self.reply(200, {'child': child_profile(family[child_id])})
        if self.path == '/v1/child/outing' and credential in children_tokens:
            parent, child_id = children_tokens[credential]
            return self.outing_route(families[parent][child_id], body, parent=False)
        if self.path == '/v1/child/record' and credential in children_tokens:
            parent, child_id = children_tokens[credential]
            add_record(families[parent][child_id], safe_record(body['record']))
            return self.reply(200, {'child': child_profile(families[parent][child_id])})
        self.reply(401, {'error': '連線已失效，請重新連結。'})

    def outing_route(self, child, body, *, parent):
        action = body.get('action')
        allowed_actions = ('plan', 'cancel') if parent else ('request', 'cancel')
        if action not in allowed_actions:
            raise ValueError('invalid outing action')
        fields = {'action', 'expectedRevision'} | ({'childId'} if parent else set())
        if action == 'plan':
            fields |= {'store', 'plannedAt'}
        if set(body) != fields:
            raise ValueError('invalid outing fields')
        expected = body['expectedRevision']
        if type(expected) is not int or expected < 0:
            raise ValueError('invalid outing revision')
        now = taipei_time()
        week = current_week(now)
        previous = current_outing(child, now)
        revision = previous['revision'] if previous else 0
        if expected != revision:
            return self.reply(409, {'error': '狀態已更新，請重新整理後再試。'})
        status = previous['status'] if previous else None
        if any(record['week'] == week for record in child['records']):
            return self.reply(409, {'error': '本週已記錄領取，請下週再安排同行。'})
        if action == 'request' and status in ('requested', 'planned', 'completed'):
            return self.reply(409, {'error': '已有同行邀請或安排，請先查看目前狀態。'})
        if action == 'cancel' and status not in ('requested', 'planned'):
            return self.reply(409, {'error': '目前沒有可取消的同行安排。'})
        updated = {'week': week, 'status': {'request': 'requested', 'plan': 'planned', 'cancel': 'canceled'}[action],
                   'revision': revision + 1, 'updatedAt': now.isoformat(timespec='seconds')}
        if previous and 'requestedAt' in previous:
            updated['requestedAt'] = previous['requestedAt']
        if action == 'request':
            updated['requestedAt'] = now.isoformat(timespec='seconds')
        elif action == 'plan':
            # Validate before assignment: failed requests must not partially
            # replace a shared plan or advance its revision.
            updated['store'] = safe_store(body['store'])
            updated['plannedAt'] = safe_planned_at(body['plannedAt'], now)
        child['outing'] = updated
        return self.reply(200, {'child': child_profile(child)})

    def demo_route(self, body, credential):
        if self.path == '/v1/demo/families':
            if body:
                raise ValueError('demo families accept no personal information')
            parent = token()
            family = {}
            for index in range(1, 3):
                child_id = secrets.token_hex(16)
                family[child_id] = {
                    'id': child_id,
                    'alias': f'孩子{index}',
                    'cardRef': f'DEMO-CARD-{index:02}',
                    'records': [],
                }
            families[parent] = family
            demo_parent_tokens.add(parent)
            demo_transactions[parent] = {}
            return self.reply(201, {
                'parentToken': parent,
                'children': list(family.values()),
            })
        if self.path != '/v1/demo/transactions':
            return self.reply(404, {'error': '找不到展示功能。'})
        if credential not in families:
            return self.reply(401, {'error': '連線已失效，請重新連結。'})
        if credential not in demo_parent_tokens:
            return self.reply(403, {'error': '模擬交易只適用獨立展示家庭。'})
        if set(body) != {'transactionId', 'cardRef', 'product'}:
            raise ValueError('invalid demo transaction fields')
        transaction_id = body['transactionId']
        card_ref, product = body['cardRef'], body['product']
        if not isinstance(transaction_id, str) or not re.fullmatch(r'[0-9a-f]{32}', transaction_id):
            raise ValueError('invalid transaction id')
        if not isinstance(card_ref, str) or not re.fullmatch(r'DEMO-CARD-0[12]', card_ref):
            raise ValueError('invalid demo card reference')
        if product not in ('鮮奶', '豆漿'):
            raise ValueError('invalid demo product')
        family = families[credential]
        child = next((item for item in family.values() if item.get('cardRef') == card_ref), None)
        if child is None:
            return self.reply(404, {'error': '找不到展示卡片。'})
        fingerprint = (card_ref, product)
        transactions = demo_transactions[credential]
        previous = transactions.get(transaction_id)
        if previous is not None:
            if previous != fingerprint:
                return self.reply(409, {'error': '同一交易編號不可更改卡片或品項。'})
            return self.reply(200, {'result': 'duplicate_transaction', 'child': child_profile(child)})
        now = taipei_time()
        monday = now.date() - timedelta(days=now.weekday())
        week = monday.isoformat()
        transactions[transaction_id] = fingerprint
        if any(record['week'] == week for record in child['records']):
            return self.reply(200, {'result': 'already_recorded', 'child': child_profile(child)})
        add_record(child, {
            'week': week,
            'product': product,
            'date': now.strftime('%Y/%m/%d %H:%M'),
            'source': 'demo_transaction',
            'transactionId': transaction_id,
            'confirmedAt': now.isoformat(timespec='seconds'),
        })
        return self.reply(200, {'result': 'accepted', 'child': child_profile(child)})


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', default='127.0.0.1', help='電腦的私人 Wi-Fi 位址')
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument('--enable-demo-transactions', action='store_true',
                        help='開啟獨立展示家庭與模擬兌領事件；不連接悠遊卡系統')
    args = parser.parse_args()
    try:
        address = ipaddress.IPv4Address(args.host)
    except ipaddress.AddressValueError:
        parser.error('請提供私人 Wi-Fi IPv4 位址。')
    private_networks = [ipaddress.IPv4Network(net) for net in ('127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')]
    if not any(address in network for network in private_networks):
        parser.error('只允許綁定私人或本機 IPv4 位址。')
    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    httpd.demo_transactions_enabled = args.enable_demo_transactions
    print(f'鮮奶週報區網展示服務：http://{args.host}:{args.port}（只限可信任的同一 Wi-Fi）', flush=True)
    print('不保存學生證號；停止程式即清除連線與展示紀錄。', flush=True)
    if args.enable_demo_transactions:
        print('已開啟獨立展示家庭與模擬交易，未連接悠遊卡官方系統。', flush=True)
    httpd.serve_forever()
