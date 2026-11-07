#!/usr/bin/env python3
"""Loopback-only, read-only browser front end for the navigation lab."""
import argparse,json
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
from matching import hybrid
from simulator import preview, paths, CONTROLS

HERE=Path(__file__).resolve().parent
FILES={'/':('preview.html','text/html; charset=utf-8'),'/preview.js':('preview.js','text/javascript; charset=utf-8'),'/preview.css':('preview.css','text/css; charset=utf-8')}
class Handler(BaseHTTPRequestHandler):
    def log_message(self,fmt,*args): pass
    def allowed_host(self): return self.headers.get('Host','') in (f'127.0.0.1:{self.server.server_port}',f'localhost:{self.server.server_port}')
    def reply(self,status,body,content_type='application/json; charset=utf-8'):
        self.send_response(status); self.send_header('Content-Type',content_type); self.send_header('Content-Length',str(len(body)))
        self.send_header('Cache-Control','no-store'); self.send_header('X-Content-Type-Options','nosniff')
        self.send_header('Content-Security-Policy',"default-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'")
        self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        if not self.allowed_host(): return self.reply(403,b'{}')
        item=FILES.get(urlsplit(self.path).path)
        if item is None: return self.reply(404,b'{}')
        name,kind=item; self.reply(200,(HERE/name).read_bytes(),kind)
    def do_POST(self):
        if not self.allowed_host(): return self.reply(403,b'{}')
        origin=self.headers.get('Origin')
        if origin and origin not in (f'http://127.0.0.1:{self.server.server_port}',f'http://localhost:{self.server.server_port}'): return self.reply(403,b'{}')
        if self.path!='/api/preview' or self.headers.get_content_type()!='application/json': return self.reply(404,b'{}')
        try:
            length=int(self.headers.get('Content-Length','0'))
            if not 0<length<=8192: raise ValueError('Request too large or empty')
            payload=json.loads(self.rfile.read(length)); query=payload['query']
            if set(payload)!={'query'} or not isinstance(query,str) or not query.strip() or len(query)>2000: raise ValueError('Enter a request of at most 2,000 characters.')
            choice=hybrid(query.strip())
            output=preview(query.strip(),choice['feature_id']) if choice['decision']=='matched' else {'status':choice['decision'],'reason':choice.get('reason')}
            for boundary in output.get('recorded_boundary_edges',[]):
                prefix=paths(boundary['source_screen_id'])
                if prefix is not None:
                    boundary['prefix_steps']=[{'edge_id':e['edge_id'],'from':e['source_screen_id'],'to':e['destination_screen_id'],'control_id':e['trigger_control_id'],'control_label':CONTROLS[e['trigger_control_id']].get('label'),'required_parameters':e.get('required_parameters',[]),'prerequisites':e.get('prerequisites',[]),'source':f"{e.get('source_file')}:{e.get('source_line')}"} for e in prefix]
            body=json.dumps({'choice':choice,'preview':output},ensure_ascii=False).encode()
            return self.reply(200,body)
        except (ValueError,KeyError,TypeError,json.JSONDecodeError) as exc:
            return self.reply(400,json.dumps({'error':str(exc)}).encode())
        except Exception:
            return self.reply(500,b'{"error":"Preview failed; check the local server."}')

def main():
    p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8765);args=p.parse_args()
    if not 1<=args.port<=65535:p.error('Port must be between 1 and 65535')
    server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
    print(f'Read-only preview: http://127.0.0.1:{args.port}/ (Ctrl-C to stop)',flush=True)
    try: server.serve_forever()
    except KeyboardInterrupt: pass
    finally: server.server_close()
if __name__=='__main__': main()
