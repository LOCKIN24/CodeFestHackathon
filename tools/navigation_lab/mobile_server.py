#!/usr/bin/env python3
"""Explicitly opted-in, read-only development API for one LAN client."""
import argparse, hmac, ipaddress, json, os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from matching import hybrid
from simulator import preview, paths, CONTROLS

PRIVATE = tuple(ipaddress.ip_network(x) for x in ('10.0.0.0/8','172.16.0.0/12','192.168.0.0/16','127.0.0.0/8'))
def private_ip(value):
    try: ip = ipaddress.ip_address(value)
    except ValueError as exc: raise argparse.ArgumentTypeError('Use a numeric private IPv4 address') from exc
    if ip.version != 4 or not any(ip in network for network in PRIVATE): raise argparse.ArgumentTypeError('Only loopback or RFC1918 IPv4 addresses are permitted')
    return str(ip)

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def reply(self, status, obj):
        data=json.dumps(obj,ensure_ascii=False).encode(); self.send_response(status)
        self.send_header('Content-Type','application/json; charset=utf-8'); self.send_header('Content-Length',str(len(data)))
        self.send_header('Cache-Control','no-store'); self.send_header('X-Content-Type-Options','nosniff'); self.end_headers(); self.wfile.write(data)
    def do_POST(self):
        if self.path != '/api/mobile/preview': return self.reply(404,{'error':'Not found'})
        if self.client_address[0] != self.server.allowed_client: return self.reply(403,{'error':'Client not permitted'})
        if self.headers.get('Origin') is not None: return self.reply(403,{'error':'Browser origins are not permitted'})
        supplied=self.headers.get('Authorization','')
        if not hmac.compare_digest(supplied,'Bearer '+self.server.token): return self.reply(401,{'error':'Unauthorized'})
        if self.headers.get_content_type() != 'application/json': return self.reply(415,{'error':'JSON required'})
        try:
            length=int(self.headers.get('Content-Length','0'))
            if not 0<length<=8192: raise ValueError('Invalid request length')
            payload=json.loads(self.rfile.read(length)); query=payload['query']
            if set(payload) != {'query'} or not isinstance(query,str) or not query.strip() or len(query)>2000: raise ValueError('Invalid query')
            choice=hybrid(query.strip())
            result=preview(query.strip(),choice['feature_id']) if choice['decision']=='matched' else {'status':choice['decision'],'reason':choice.get('reason')}
            for boundary in result.get('recorded_boundary_edges',[]):
                prefix=paths(boundary['source_screen_id'])
                if prefix is not None:
                    boundary['prefix_steps']=[{'edge_id':e['edge_id'],'from':e['source_screen_id'],'to':e['destination_screen_id'],'control_id':e['trigger_control_id'],'control_label':CONTROLS[e['trigger_control_id']].get('label'),'required_parameters':e.get('required_parameters',[]),'prerequisites':e.get('prerequisites',[]),'source':f"{e.get('source_file')}:{e.get('source_line')}"} for e in prefix]
            self.reply(200,{'choice':choice,'preview':result, 'navigation_eligible': (choice.get('decision') == 'matched' and choice.get('intent') == 'browse_or_navigate' and choice.get('action_allowed') is False and choice.get('source') == 'name_or_alias' and ((choice.get('feature_id') == 'language_settings' and result.get('status') == 'preview') or (choice.get('feature_id') == 'activity_information' and result.get('status') == 'incomplete')) and result.get('feature_id') == choice.get('feature_id'))})
        except (ValueError,KeyError,TypeError,json.JSONDecodeError): self.reply(400,{'error':'Invalid JSON request'})
        except Exception: self.reply(500,{'error':'Preview failed'})
    def do_GET(self): self.reply(405,{'error':'Method not allowed'})

def main():
    p=argparse.ArgumentParser(description='Trusted LAN preview API; token is read from NAV_LAB_TOKEN environment variable.')
    p.add_argument('--bind',type=private_ip,required=True,help='Specific Mac private IPv4 address, or 127.0.0.1 for simulator')
    p.add_argument('--allow-client',type=private_ip,required=True,help='One permitted iPhone private IPv4 address, or 127.0.0.1 for simulator')
    p.add_argument('--port',type=int,default=8766); a=p.parse_args(); token=os.environ.get('NAV_LAB_TOKEN','')
    if len(token)<32 or not token.isascii() or any(c.isspace() for c in token): p.error('Set NAV_LAB_TOKEN to a non-whitespace ASCII secret of at least 32 characters')
    if not 1<=a.port<=65535: p.error('Invalid port')
    server=ThreadingHTTPServer((a.bind,a.port),Handler); server.allowed_client=a.allow_client; server.token=token
    print(f'Read-only development API listening on {a.bind}:{a.port} for {a.allow_client}; Ctrl-C to stop.',flush=True)
    try: server.serve_forever()
    except KeyboardInterrupt: pass
    finally: server.server_close()
if __name__=='__main__': main()
