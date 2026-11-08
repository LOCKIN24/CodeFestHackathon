import http.client
import json
import socket
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from unittest.mock import patch

import server


class FamilyFlowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.httpd = server.ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()
        cls.port = cls.httpd.server_address[1]

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()

    def setUp(self):
        with server.lock:
            server.families.clear()
            server.children_tokens.clear()
            server.invitations.clear()
            server.attempts.clear()
            server.demo_parent_tokens.clear()
            server.demo_transactions.clear()
            self.httpd.demo_transactions_enabled = False

    def request(self, method, path, body=None, credential=None):
        conn = http.client.HTTPConnection('127.0.0.1', self.port, timeout=3)
        headers = {'Content-Type': 'application/json'}
        if credential:
            headers['Authorization'] = 'Bearer ' + credential
        conn.request(method, path, json.dumps(body).encode() if body is not None else None, headers)
        response = conn.getresponse()
        data = json.loads(response.read())
        conn.close()
        return response.status, data

    def create_family(self, child_ids=('a' * 32, 'b' * 32)):
        status, family = self.request('POST', '/v1/families', {})
        self.assertEqual(status, 201)
        parent = family['parentToken']
        for index, child_id in enumerate(child_ids):
            status, _ = self.request('POST', '/v1/parent/children', {
                'childId': child_id, 'alias': f'孩子{index + 1}',
            }, parent)
            self.assertEqual(status, 200)
        return parent

    def invitation(self, parent, child_id='a' * 32):
        status, invitation = self.request('POST', '/v1/parent/invitations', {
            'childId': child_id,
        }, parent)
        self.assertEqual(status, 200)
        self.assertEqual(invitation['expiresIn'], 600)
        return invitation['code']

    def link(self, parent, child_id='a' * 32):
        status, joined = self.request('POST', '/v1/join', {
            'code': self.invitation(parent, child_id),
        })
        self.assertEqual(status, 200)
        return joined['childToken']

    def create_demo(self):
        self.httpd.demo_transactions_enabled = True
        status, family = self.request('POST', '/v1/demo/families', {})
        self.assertEqual(status, 201)
        return family['parentToken'], family['children']

    def transaction(self, parent, transaction_id='1' * 32, card_ref='DEMO-CARD-02', product='鮮奶'):
        return self.request('POST', '/v1/demo/transactions', {
            'transactionId': transaction_id,
            'cardRef': card_ref,
            'product': product,
        }, parent)

    def raw_request(self, headers, body=b'', end_body=False):
        with socket.create_connection(('127.0.0.1', self.port), timeout=3) as conn:
            payload = ('POST /v1/families HTTP/1.0\r\n'
                       'Host: localhost\r\n' + headers + '\r\n').encode() + body
            conn.sendall(payload)
            if end_body:
                conn.shutdown(socket.SHUT_WR)
            response = http.client.HTTPResponse(conn)
            response.begin()
            return response.status, json.loads(response.read())

    def test_two_children_invite_sync_single_use_and_revoke(self):
        _, family = self.request('POST', '/v1/families', {})
        parent = family['parentToken']
        ids = ['a' * 32, 'b' * 32]
        for index, child_id in enumerate(ids):
            status, _ = self.request('POST', '/v1/parent/children', {'childId': child_id, 'alias': f'孩子{index + 1}', 'cardNumber': 'must-not-be-stored'}, parent)
            self.assertEqual(status, 200)
        _, invite = self.request('POST', '/v1/parent/invitations', {'childId': ids[0]}, parent)
        status, joined = self.request('POST', '/v1/join', {'code': invite['code']})
        self.assertEqual(status, 200)
        child_token = joined['childToken']
        second_token = self.link(parent, ids[1])
        self.assertEqual(self.request('POST', '/v1/join', {'code': invite['code']})[0], 404)
        record = {'week': '2026-11-02', 'product': '鮮奶', 'date': '2026/11/04 09:00'}
        self.assertEqual(self.request('POST', '/v1/child/record', {'record': record}, child_token)[0], 200)
        self.request('POST', '/v1/child/record', {'record': record}, child_token)
        _, result = self.request('GET', '/v1/parent/children', credential=parent)
        self.assertEqual(len(result['children'][0]['records']), 1)
        self.assertEqual(result['children'][1]['records'], [])
        _, second_profile = self.request('GET', '/v1/child/profile', credential=second_token)
        self.assertEqual(second_profile['child']['id'], ids[1])
        self.assertEqual(second_profile['child']['records'], [])
        # A child-supplied identifier cannot redirect its write to its sibling.
        second_record = {'week': '2026-11-02', 'product': '豆漿', 'date': '2026/11/04 10:00'}
        self.assertEqual(self.request('POST', '/v1/child/record', {
            'childId': ids[0], 'record': second_record,
        }, second_token)[0], 200)
        _, first_profile = self.request('GET', '/v1/child/profile', credential=child_token)
        _, second_profile = self.request('GET', '/v1/child/profile', credential=second_token)
        self.assertEqual(first_profile['child']['records'], [record])
        self.assertEqual(second_profile['child']['records'], [second_record])
        parent_record = {'week': '2026-11-09', 'product': '豆漿', 'date': '2026/11/09 10:00'}
        self.assertEqual(self.request('POST', '/v1/parent/record', {'childId': ids[0], 'record': parent_record}, parent)[0], 200)
        _, child_profile = self.request('GET', '/v1/child/profile', credential=child_token)
        self.assertEqual(child_profile['child']['records'][0]['product'], '豆漿')
        self.assertNotIn('cardNumber', result['children'][0])
        self.assertEqual(self.request('GET', '/v1/parent/children', credential=child_token)[0], 401)
        self.assertEqual(self.request('POST', '/v1/parent/revoke', {'childId': ids[0]}, parent)[0], 200)
        self.assertEqual(self.request('GET', '/v1/child/profile', credential=child_token)[0], 401)
        self.assertEqual(self.request('POST', '/v1/child/record', {'record': record}, child_token)[0], 401)
        self.assertEqual(self.request('GET', '/v1/child/profile', credential=second_token)[0], 200)

    def test_invitation_expires_at_its_deadline(self):
        parent = self.create_family()
        code = self.invitation(parent)
        deadline = server.invitations[code][2]
        with patch.object(server.time, 'time', return_value=deadline):
            self.assertEqual(self.request('POST', '/v1/join', {'code': code})[0], 404)
        self.assertNotIn(code, server.invitations)

    def test_replacing_invitation_invalidates_previous_code(self):
        parent = self.create_family()
        old_code = self.invitation(parent)
        new_code = self.invitation(parent)
        self.assertNotEqual(old_code, new_code)
        self.assertEqual(self.request('POST', '/v1/join', {'code': old_code})[0], 404)
        self.assertEqual(self.request('POST', '/v1/join', {'code': new_code.lower()})[0], 200)

    def test_concurrent_join_consumes_invitation_once(self):
        code = self.invitation(self.create_family())
        with ThreadPoolExecutor(max_workers=2) as executor:
            responses = list(executor.map(
                lambda _: self.request('POST', '/v1/join', {'code': code})[0], range(2),
            ))
        self.assertEqual(sorted(responses), [200, 404])

    def test_revoke_invalidates_pending_invite_and_every_link_for_one_child(self):
        parent = self.create_family()
        tokens = [self.link(parent), self.link(parent)]
        sibling_token = self.link(parent, 'b' * 32)
        pending_code = self.invitation(parent)
        sibling_code = self.invitation(parent, 'b' * 32)
        self.assertEqual(self.request('POST', '/v1/parent/revoke', {'childId': 'a' * 32}, parent)[0], 200)
        self.assertEqual(self.request('POST', '/v1/join', {'code': pending_code})[0], 404)
        for access in tokens:
            self.assertEqual(self.request('GET', '/v1/child/profile', credential=access)[0], 401)
        self.assertEqual(self.request('GET', '/v1/child/profile', credential=sibling_token)[0], 200)
        self.assertEqual(self.request('POST', '/v1/join', {'code': sibling_code})[0], 200)

    def test_parent_and_child_tokens_cannot_access_another_family(self):
        parent = self.create_family(('a' * 32,))
        other_parent = self.create_family(('b' * 32,))
        child = self.link(parent)
        record = {'week': '2026-11-02', 'product': '鮮奶', 'date': '2026/11/04 09:00'}
        for path, body in (
            ('/v1/parent/invitations', {'childId': 'b' * 32}),
            ('/v1/parent/revoke', {'childId': 'b' * 32}),
            ('/v1/parent/record', {'childId': 'b' * 32, 'record': record}),
        ):
            self.assertEqual(self.request('POST', path, body, parent)[0], 404)
            self.assertEqual(self.request('POST', path, body, child)[0], 401)
        self.assertEqual(self.request('GET', '/v1/child/profile', credential=other_parent)[0], 401)

    def test_restart_invalidates_old_credentials_and_allows_fresh_link(self):
        parent = self.create_family()
        child = self.link(parent)
        code = self.invitation(parent)
        # A process restart starts with these in-memory registries empty.
        self.setUp()
        self.assertEqual(self.request('GET', '/v1/parent/children', credential=parent)[0], 401)
        self.assertEqual(self.request('GET', '/v1/child/profile', credential=child)[0], 401)
        self.assertEqual(self.request('POST', '/v1/join', {'code': code})[0], 404)
        fresh_parent = self.create_family()
        fresh_child = self.link(fresh_parent)
        self.assertNotEqual(parent, fresh_parent)
        self.assertNotEqual(child, fresh_child)
        self.assertEqual(self.request('GET', '/v1/child/profile', credential=fresh_child)[0], 200)

    def test_malformed_records_return_json_errors_without_changing_records(self):
        parent = self.create_family()
        child = self.link(parent)
        for record in (None, [], 7, 'invalid', {}, {'week': []}, {
            'week': '2026-11-02', 'product': 'invalid', 'date': '2026/11/04',
        }):
            for path, access, body in (
                ('/v1/parent/record', parent, {'childId': 'a' * 32, 'record': record}),
                ('/v1/child/record', child, {'record': record}),
            ):
                with self.subTest(record=record, path=path):
                    status, response = self.request('POST', path, body, access)
                    self.assertEqual(status, 400)
                    self.assertIn('error', response)
        _, profile = self.request('GET', '/v1/child/profile', credential=child)
        self.assertEqual(profile['child']['records'], [])

    def test_malformed_json_and_non_object_bodies_return_json_errors(self):
        for payload in (b'[]', b'null', b'1', b'"text"', b'{', b'\xff'):
            with self.subTest(payload=payload):
                status, response = self.raw_request(f'Content-Length: {len(payload)}\r\n', payload)
                self.assertEqual(status, 400)
                self.assertIn('error', response)
        self.assertEqual(server.families, {})

    def test_invalid_content_lengths_and_framing_are_rejected_before_reading(self):
        for headers in (
            'Content-Length: -1\r\n',
            'Content-Length: invalid\r\n',
            'Content-Length: 8193\r\n',
            'Content-Length: 0\r\nContent-Length: 0\r\n',
            'Transfer-Encoding: chunked\r\n',
        ):
            with self.subTest(headers=headers):
                status, response = self.raw_request(headers)
                self.assertEqual(status, 400)
                self.assertIn('error', response)
        self.assertEqual(server.families, {})

    def test_truncated_body_is_rejected(self):
        status, response = self.raw_request('Content-Length: 10\r\n', b'{}', end_body=True)
        self.assertEqual(status, 400)
        self.assertIn('error', response)

    def test_demo_routes_require_explicit_opt_in(self):
        for path in ('/v1/demo/families', '/v1/demo/transactions'):
            status, response = self.request('POST', path, {})
            self.assertEqual(status, 404)
            self.assertIn('error', response)
        self.assertEqual(server.families, {})

    def test_demo_families_are_separate_synthetic_profiles(self):
        regular_parent = self.create_family()
        parent, children = self.create_demo()
        self.assertNotEqual(regular_parent, parent)
        self.assertEqual([child['alias'] for child in children], ['孩子1', '孩子2'])
        self.assertEqual([child['cardRef'] for child in children], ['DEMO-CARD-01', 'DEMO-CARD-02'])
        for child in children:
            self.assertRegex(child['id'], r'^[0-9a-f]{32}$')
            self.assertEqual(set(child), {'id', 'alias', 'cardRef', 'records'})
            self.assertEqual(child['records'], [])
        self.assertNotEqual(children[0]['id'], children[1]['id'])
        self.assertEqual(self.request('GET', '/v1/parent/children', credential=regular_parent)[1]['children'][0]['records'], [])
        self.assertEqual(self.request('POST', '/v1/demo/families', {'name': 'not accepted'})[0], 400)

    def test_demo_transaction_uses_server_taipei_clock_and_syncs_to_child(self):
        parent, children = self.create_demo()
        child_access = self.link(parent, children[1]['id'])
        # Sunday UTC is already Monday in Taipei; the client cannot choose it.
        timestamp = datetime(2026, 11, 8, 16, 0, 4, tzinfo=timezone.utc).timestamp()
        with patch.object(server.time, 'time', return_value=timestamp):
            status, response = self.transaction(parent)
        self.assertEqual(status, 200)
        self.assertEqual(response['result'], 'accepted')
        record = response['child']['records'][0]
        self.assertEqual(record, {
            'week': '2026-11-09', 'product': '鮮奶', 'date': '2026/11/09 00:00',
            'source': 'demo_transaction', 'transactionId': '1' * 32,
            'confirmedAt': '2026-11-09T00:00:04+08:00',
        })
        profile = self.request('GET', '/v1/child/profile', credential=child_access)[1]['child']
        self.assertEqual(profile['records'], [record])
        all_children = self.request('GET', '/v1/parent/children', credential=parent)[1]['children']
        self.assertEqual(all_children[0]['records'], [])
        self.assertEqual(all_children[1]['records'], [record])

    def test_demo_duplicate_transactions_are_atomic_and_keep_original_record(self):
        parent, _ = self.create_demo()
        with ThreadPoolExecutor(max_workers=2) as executor:
            responses = list(executor.map(lambda _: self.transaction(parent), range(2)))
        self.assertTrue(all(status == 200 for status, _ in responses))
        self.assertEqual(sorted(value['result'] for _, value in responses), ['accepted', 'duplicate_transaction'])
        records = responses[0][1]['child']['records']
        self.assertEqual(len(records), 1)
        original = records[0].copy()
        later = datetime.fromisoformat(original['confirmedAt']).timestamp() + 86400 * 14
        with patch.object(server.time, 'time', return_value=later):
            status, replay = self.transaction(parent)
        self.assertEqual(status, 200)
        self.assertEqual(replay['result'], 'duplicate_transaction')
        self.assertEqual(replay['child']['records'], [original])

    def test_demo_reused_transaction_id_with_different_payload_conflicts(self):
        parent, _ = self.create_demo()
        self.transaction(parent)
        for card_ref, product in (('DEMO-CARD-01', '鮮奶'), ('DEMO-CARD-02', '豆漿')):
            status, response = self.transaction(parent, card_ref=card_ref, product=product)
            self.assertEqual(status, 409)
            self.assertIn('error', response)
        children = self.request('GET', '/v1/parent/children', credential=parent)[1]['children']
        self.assertEqual(children[0]['records'], [])
        self.assertEqual(len(children[1]['records']), 1)
        self.assertEqual(children[1]['records'][0]['product'], '鮮奶')

    def test_demo_new_transaction_cannot_redeem_same_week_twice(self):
        parent, _ = self.create_demo()
        first = self.transaction(parent)[1]['child']['records'][0]
        status, second = self.transaction(parent, transaction_id='2' * 32, product='豆漿')
        self.assertEqual(status, 200)
        self.assertEqual(second['result'], 'already_recorded')
        self.assertEqual(second['child']['records'], [first])
        replay = self.transaction(parent, transaction_id='2' * 32, product='豆漿')[1]
        self.assertEqual(replay['result'], 'duplicate_transaction')

    def test_demo_transactions_cannot_modify_regular_families_or_use_child_credentials(self):
        regular = self.create_family()
        parent, children = self.create_demo()
        child = self.link(parent, children[1]['id'])
        for access, status in ((regular, 403), (child, 401), ('unknown', 401), (None, 401)):
            self.assertEqual(self.transaction(access)[0], status)
        for access in (regular, parent):
            profiles = self.request('GET', '/v1/parent/children', credential=access)[1]['children']
            self.assertTrue(all(not value['records'] for value in profiles))

    def test_demo_transaction_ids_are_scoped_to_each_family(self):
        first, first_children = self.create_demo()
        second, second_children = self.create_demo()
        self.assertEqual(self.transaction(first)[1]['result'], 'accepted')
        second_profiles = self.request('GET', '/v1/parent/children', credential=second)[1]['children']
        self.assertTrue(all(not child['records'] for child in second_profiles))
        result = self.transaction(second)[1]
        self.assertEqual(result['result'], 'accepted')
        self.assertEqual(result['child']['id'], second_children[1]['id'])
        self.assertNotEqual(result['child']['id'], first_children[1]['id'])

    def test_demo_transaction_rejects_malformed_fields_and_client_timestamps(self):
        parent, _ = self.create_demo()
        valid = {'transactionId': '1' * 32, 'cardRef': 'DEMO-CARD-02', 'product': '鮮奶'}
        invalid = [
            {}, {**valid, 'week': '2000-01-01'}, {**valid, 'confirmedAt': 'client time'},
            {**valid, 'transactionId': 'bad'}, {**valid, 'transactionId': None},
            {**valid, 'cardRef': '0123456789012345'}, {**valid, 'cardRef': []},
            {**valid, 'product': 'invalid'}, {**valid, 'product': {}},
        ]
        for body in invalid:
            with self.subTest(body=body):
                self.assertEqual(self.request('POST', '/v1/demo/transactions', body, parent)[0], 400)
        children = self.request('GET', '/v1/parent/children', credential=parent)[1]['children']
        self.assertTrue(all(not child['records'] for child in children))

    def test_demo_transaction_does_not_overwrite_an_existing_manual_record(self):
        parent, children = self.create_demo()
        timestamp = datetime(2026, 11, 8, 16, 0, 4, tzinfo=timezone.utc).timestamp()
        record = {'week': '2026-11-09', 'product': '豆漿', 'date': '2026/11/09 00:00'}
        self.request('POST', '/v1/parent/record', {'childId': children[1]['id'], 'record': record}, parent)
        with patch.object(server.time, 'time', return_value=timestamp):
            status, response = self.transaction(parent)
        self.assertEqual(status, 200)
        self.assertEqual(response['result'], 'already_recorded')
        self.assertEqual(response['child']['records'], [record])


    def outing(self, credential, action, revision=0, *, child_id=None, **extra):
        path = '/v1/parent/outing' if child_id is not None else '/v1/child/outing'
        body = {'action': action, 'expectedRevision': revision, **extra}
        if child_id is not None:
            body['childId'] = child_id
        return self.request('POST', path, body, credential)

    @staticmethod
    def outing_plan():
        return {'plannedAt': '2026-11-08T09:00:00.000Z', 'store': {
            'name': '全家 測試門市', 'latitude': 25.03, 'longitude': 121.56,
            'address': '臺北市公開門市地址',
        }}

    @staticmethod
    def outing_clock():
        # Sunday afternoon in Taipei; selected plan is one hour later.
        return patch.object(server.time, 'time', return_value=datetime(
            2026, 11, 8, 8, 0, tzinfo=timezone.utc).timestamp())

    def test_outing_request_plan_visible_to_both_devices_and_record_completes(self):
        parent = self.create_family()
        child, sibling = self.link(parent), self.link(parent, 'b' * 32)
        with self.outing_clock():
            status, requested = self.outing(child, 'request')
            self.assertEqual(status, 200)
            first = requested['child']['outing']
            self.assertEqual(first['status'], 'requested')
            self.assertEqual(first['revision'], 1)
            self.assertEqual(first['week'], '2026-11-02')
            self.assertEqual(first['requestedAt'], '2026-11-08T16:00:00+08:00')
            status, planned = self.outing(parent, 'plan', 1, child_id='a' * 32, **self.outing_plan())
            self.assertEqual(status, 200)
            plan = planned['child']['outing']
            self.assertEqual(plan['status'], 'planned')
            self.assertEqual(plan['revision'], 2)
            self.assertEqual(plan['plannedAt'], '2026-11-08T09:00:00+00:00')
            self.assertEqual(plan['store'], self.outing_plan()['store'])
            self.assertEqual(plan['requestedAt'], first['requestedAt'])
            profile = self.request('GET', '/v1/child/profile', credential=child)[1]['child']
            self.assertEqual(profile['outing'], plan)
            children = self.request('GET', '/v1/parent/children', credential=parent)[1]['children']
            self.assertEqual(children[0]['outing'], plan)
            self.assertNotIn('outing', children[1])
            record = {'week': '2026-11-02', 'product': '豆漿', 'date': '2026/11/08 17:10'}
            status, complete = self.request('POST', '/v1/child/record', {'record': record}, child)
            self.assertEqual(status, 200)
            self.assertEqual(complete['child']['outing']['status'], 'completed')
            self.assertEqual(complete['child']['outing']['revision'], 3)
            repeated = self.request('POST', '/v1/child/record', {'record': record}, child)[1]
            self.assertEqual(repeated['child']['outing']['revision'], 3)
            self.assertEqual(len(repeated['child']['records']), 1)
            self.assertNotIn('outing', self.request('GET', '/v1/child/profile', credential=sibling)[1]['child'])
            self.assertEqual(self.outing(child, 'request', 3)[0], 409)
            self.assertEqual(self.outing(parent, 'plan', 3, child_id='a' * 32, **self.outing_plan())[0], 409)

    def test_outing_stale_revision_does_not_overwrite_new_plan(self):
        parent = self.create_family()
        child = self.link(parent)
        with self.outing_clock():
            self.outing(child, 'request')
            self.outing(parent, 'plan', 1, child_id='a' * 32, **self.outing_plan())
            for action, revision in (('request', 1), ('cancel', 1), ('request', 2)):
                self.assertEqual(self.outing(child, action, revision)[0], 409)
            self.assertEqual(self.outing(parent, 'plan', 1, child_id='a' * 32, **self.outing_plan())[0], 409)
            profile = self.request('GET', '/v1/child/profile', credential=child)[1]['child']
            self.assertEqual(profile['outing']['status'], 'planned')
            self.assertEqual(profile['outing']['revision'], 2)
            # Parent can revise a currently observed plan.
            revised = self.outing_plan()
            revised['plannedAt'] = '2026-11-08T10:00:00Z'
            self.assertEqual(self.outing(parent, 'plan', 2, child_id='a' * 32, **revised)[0], 200)
            self.assertEqual(self.outing(child, 'cancel', 3)[1]['child']['outing']['status'], 'canceled')
            self.assertEqual(self.outing(child, 'request', 4)[1]['child']['outing']['revision'], 5)
            self.assertEqual(self.outing(parent, 'cancel', 5, child_id='a' * 32)[1]['child']['outing']['status'], 'canceled')

    def test_outing_plan_without_child_request_and_without_address(self):
        parent = self.create_family()
        child = self.link(parent)
        plan = self.outing_plan()
        del plan['store']['address']
        with self.outing_clock():
            status, response = self.outing(parent, 'plan', child_id='a' * 32, **plan)
            self.assertEqual(status, 200)
            self.assertEqual(response['child']['outing']['store']['address'], '')
            self.assertNotIn('requestedAt', response['child']['outing'])
            self.assertEqual(self.outing(child, 'request', 1)[0], 409)

    def test_outing_week_rollover_hides_old_plan_and_starts_revision_zero(self):
        parent = self.create_family()
        child = self.link(parent)
        with self.outing_clock():
            self.outing(parent, 'plan', child_id='a' * 32, **self.outing_plan())
        monday = datetime(2026, 11, 8, 16, 0, tzinfo=timezone.utc).timestamp()
        with patch.object(server.time, 'time', return_value=monday):
            self.assertNotIn('outing', self.request('GET', '/v1/child/profile', credential=child)[1]['child'])
            self.assertNotIn('outing', self.request('GET', '/v1/parent/children', credential=parent)[1]['children'][0])
            self.assertEqual(server.families[parent]['a' * 32]['outing']['week'], '2026-11-02')
            self.assertEqual(self.outing(child, 'request', 1)[0], 409)
            status, response = self.outing(child, 'request')
            self.assertEqual(status, 200)
            self.assertEqual(response['child']['outing']['week'], '2026-11-09')
            self.assertEqual(response['child']['outing']['revision'], 1)

    def test_outing_unauthorized_family_role_and_revoked_child_cannot_change_plan(self):
        parent = self.create_family()
        other = self.create_family(('c' * 32,))
        child = self.link(parent)
        with self.outing_clock():
            self.outing(child, 'request')
            self.assertEqual(self.outing(other, 'plan', 1, child_id='a' * 32, **self.outing_plan())[0], 404)
            self.assertEqual(self.outing(child, 'plan', 1, child_id='a' * 32, **self.outing_plan())[0], 401)
            self.assertEqual(self.outing(parent, 'request', 1)[0], 401)
            self.assertEqual(self.outing(child, 'plan', 1, **self.outing_plan())[0], 400)
            self.assertEqual(self.outing(parent, 'request', 1, child_id='a' * 32)[0], 400)
            self.request('POST', '/v1/parent/revoke', {'childId': 'a' * 32}, parent)
            self.assertEqual(self.outing(child, 'cancel', 1)[0], 401)
            self.assertEqual(server.families[parent]['a' * 32]['outing']['revision'], 1)

    def test_outing_strict_schema_rejects_private_fields_and_invalid_revisions(self):
        parent = self.create_family()
        child = self.link(parent)
        with self.outing_clock():
            for revision in (None, -1, True, '0', 0.5):
                self.assertEqual(self.outing(child, 'request', revision)[0], 400)
            for field in ('childId', 'name', 'school', 'home', 'cardNumber', 'requestedAt', 'week'):
                self.assertEqual(self.outing(child, 'request', **{field: 'private'})[0], 400)
            valid = {'action': 'plan', 'childId': 'a' * 32, 'expectedRevision': 0, **self.outing_plan()}
            for field in ('name', 'school', 'home', 'cardNumber', 'week'):
                self.assertEqual(self.request('POST', '/v1/parent/outing', {**valid, field: 'private'}, parent)[0], 400)
            self.assertNotIn('outing', server.families[parent]['a' * 32])

    def test_outing_invalid_stores_and_dates_do_not_partially_mutate(self):
        parent = self.create_family()
        plan = self.outing_plan()
        bad_stores = [None, [], {}, {**plan['store'], 'home': 'private'},
                      {**plan['store'], 'name': ''}, {**plan['store'], 'name': 'x' * 121},
                      {**plan['store'], 'address': 'x' * 241}, {**plan['store'], 'name': 'x\ny'},
                      {**plan['store'], 'latitude': True}, {**plan['store'], 'latitude': 91},
                      {**plan['store'], 'longitude': -181}, {**plan['store'], 'latitude': float('nan')},
                      {**plan['store'], 'latitude': float('inf')}, {**plan['store'], 'latitude': 10 ** 400}]
        bad_times = [None, '', 'not a time', '2026-11-08T09:00:00',
                     '2026-11-08T17:00:00+08:00', '2026-11-08T08:00:00Z',
                     '2026-11-08T07:59:59Z', '2026-11-08T16:00:00Z',
                     '2026-11-09T09:00:00Z', '9999-12-31T23:59:59Z']
        with self.outing_clock():
            for store in bad_stores:
                self.assertEqual(self.outing(parent, 'plan', child_id='a' * 32, **{**plan, 'store': store})[0], 400)
            for planned_at in bad_times:
                self.assertEqual(self.outing(parent, 'plan', child_id='a' * 32, **{**plan, 'plannedAt': planned_at})[0], 400)
            self.assertNotIn('outing', server.families[parent]['a' * 32])

    def test_outing_concurrent_parent_plans_have_one_winner(self):
        parent = self.create_family()
        with self.outing_clock():
            with ThreadPoolExecutor(max_workers=2) as executor:
                responses = list(executor.map(lambda _: self.outing(
                    parent, 'plan', child_id='a' * 32, **self.outing_plan())[0], range(2)))
            self.assertEqual(sorted(responses), [200, 409])
            self.assertEqual(server.families[parent]['a' * 32]['outing']['revision'], 1)

    def test_parent_record_completes_outing_only_for_its_week(self):
        parent = self.create_family()
        with self.outing_clock():
            self.outing(parent, 'plan', child_id='a' * 32, **self.outing_plan())
            record = {'week': '2026-10-26', 'product': '鮮奶', 'date': '2026/10/28 09:00'}
            self.request('POST', '/v1/parent/record', {'childId': 'a' * 32, 'record': record}, parent)
            self.assertEqual(server.families[parent]['a' * 32]['outing']['status'], 'planned')
            record['week'] = '2026-11-02'
            self.request('POST', '/v1/parent/record', {'childId': 'a' * 32, 'record': record}, parent)
            self.assertEqual(server.families[parent]['a' * 32]['outing']['status'], 'completed')

    def test_demo_transaction_completes_outing_without_claiming_official_status(self):
        parent, children = self.create_demo()
        with self.outing_clock():
            status, _ = self.outing(parent, 'plan', child_id=children[1]['id'], **self.outing_plan())
            self.assertEqual(status, 200)
            status, result = self.transaction(parent)
            self.assertEqual(status, 200)
            self.assertEqual(result['child']['outing']['status'], 'completed')
            self.assertEqual(result['child']['records'][0]['source'], 'demo_transaction')
            self.assertNotIn('outing', server.families[parent][children[0]['id']])


if __name__ == '__main__':
    unittest.main()
