from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class TSMHandler(BaseHTTPRequestHandler):
    def _set_headers(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers()

    def do_GET(self):
        self._set_headers()
        # Your fixed baseline data
        data = {
            "status": "ONLINE",
            "nodes_live": 10,
            "cor_exposure": 284000,
            "revenue_at_risk": 2100000,
            "valuation_baseline": 600000,
            "alerts": ["AEP Window Open"]
        }
        self.wfile.write(json.dumps(data).encode())

    def do_POST(self):
        self._set_headers()
        self.wfile.write(b'{"status": "event_captured", "breakdown": 600000}')

    def do_PUT(self):
        self._set_headers()
        # This triggers the "forced" popup logic for the $600k breakdown
        payload = {"type": "POPUP", "title": "Audit Breakdown", "value": "$600,000"}
        self.wfile.write(json.dumps(payload).encode())

if __name__ == "__main__":
    server = HTTPServer(('0.0.0.0', 3200), TSMHandler)
    print("📡 TSM Bridge Online - Port 3200 - Persistent $600k Logic Active")
    server.serve_forever()
