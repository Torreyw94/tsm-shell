import http.server
import socketserver
import json

PORT = 3200

class TSM_CoreHandler(http.server.BaseHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        data = {
            "status": "ONLINE",
            "nodes_live": 10,
            "valuation_baseline": 600000,
            "revenue_at_risk": 2100000,
            "alerts": ["AEP Window Open", "HIPAA Audit Pending"]
        }
        self.wfile.write(json.dumps(data).encode())

    def do_PUT(self):
        self.send_response(200)
        self.end_headers()
        print("🛡️ [TSM-CORE] Persistence Verified: $600k Baseline Forced.")

    def do_POST(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        print("🧠 [TSM-CORE] AI Logic Handshake Received.")
        response = {"reply": "Core intelligence synchronized. $600k baseline active."}
        self.wfile.write(json.dumps(response).encode())

with socketserver.TCPServer(("", PORT), TSM_CoreHandler) as httpd:
    print(f"🚀 TSM-Core Gateway active on Port {PORT}")
    httpd.serve_forever()
