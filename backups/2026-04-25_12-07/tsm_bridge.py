import http.server, socketserver, json, os, csv
PORT = 3200
CLIENT_DATA_FILE = 'client_ingestion.csv'

class TSM_CoreHandler(http.server.BaseHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
        # Hard-coded Strategic Baseline
        base_val = 600000
        risk = 2100000
        status = "DEMO_MODE"
        alerts = ["AEP Window Open", "HIPAA Audit Pending"]

        if os.path.exists(CLIENT_DATA_FILE):
            try:
                with open(CLIENT_DATA_FILE, mode='r') as f:
                    count = len(list(csv.DictReader(f)))
                    risk = count * 7500
                    status = "LIVE_SYNC"
                    alerts = [f"Audit: {count} Active PII Gaps Identified"]
            except: pass

        data = {
            "status": status,
            "valuation_baseline": base_val,
            "revenue_at_risk": risk,
            "alerts": alerts,
            "nodes_live": 10
        }
        self.wfile.write(json.dumps(data).encode())

with socketserver.TCPServer(("", PORT), TSM_CoreHandler) as httpd:
    httpd.serve_forever()
