#!/usr/bin/env python3
"""Local upload fixture. Binds loopback by default; no external service required."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import argparse, json, time
class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        count = int(self.headers.get('Content-Length', '0'))
        received = 0
        while received < count:
            chunk = self.rfile.read(min(16384, count-received))
            if not chunk: break
            received += len(chunk)
            time.sleep(0.005)
        data = json.dumps({'receivedBytes': received, 'contentType': self.headers.get('Content-Type')}).encode()
        self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--bind',default='127.0.0.1'); parser.add_argument('--port',type=int,default=8765); args=parser.parse_args()
    HTTPServer((args.bind,args.port),Handler).serve_forever()
