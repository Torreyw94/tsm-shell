"""
tsm_bridge_v2.py — TSM Sovereign Bridge (Client-Data Mode)
Replaces the hard-coded $600k baseline with live client metrics.
Integrates with data_ingestion.py and prompt_engine.py.

Run: python tsm_bridge_v2.py
Then POST to: http://localhost:8080/analyze
"""

import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

# Local modules
from data_ingestion import ingest
from prompt_engine import build_prompt, call_claude

PORT = int(os.environ.get("PORT", 8080))


class TSMBridgeHandler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        print(f"[TSM] {self.address_string()} — {format % args}")

    # ── GET: Health check + status ─────────────────────────────────────────
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        if path == "/health":
            self._respond(200, {"status": "TSM Bridge LIVE", "mode": "CLIENT_DATA"})

        elif path == "/demo":
            # Demo mode: returns dummy metrics without hitting any client system
            from data_ingestion import empty_metrics
            demo = empty_metrics()
            demo.update({
                "client_name": "Demo Client",
                "source_type": "Demo",
                "overdue_exclusion_screenings": 47,
                "total_billed": 3_200_000,
                "total_denied": 600_000,
                "denial_rate_pct": 18.75,
                "revenue_at_risk": 600_000,
                "staff_total": 210,
                "compliance_gaps": [
                    "47 staff overdue for OIG exclusion screening (42 CFR § 1001.501)",
                    "Denial rate 18.75% — claims submission controls review required (42 CFR § 405.874)",
                ],
            })
            result = call_claude(build_prompt(demo))
            self._respond(200, {"metrics": demo, "analysis": result})

        else:
            self._respond(404, {"error": "Endpoint not found. Use POST /analyze"})

    # ── POST: Main analysis endpoint ───────────────────────────────────────
    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        if path != "/analyze":
            self._respond(404, {"error": "Unknown endpoint"})
            return

        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length)) if length else {}
        except json.JSONDecodeError:
            self._respond(400, {"error": "Invalid JSON body"})
            return

        # ── Validate required fields ───────────────────────────────────────
        source = body.get("source")          # file path, DB connection string, or "api"
        client_name = body.get("client_name", "Unknown Client")
        domain = body.get("domain", "compliance")  # compliance | music | legal | financial

        if not source:
            self._respond(400, {"error": "Missing required field: source"})
            return

        # ── Ingest client data ─────────────────────────────────────────────
        db_type = body.get("db_type")
        use_ocr = body.get("use_ocr", False)
        custom_queries = body.get("custom_queries")
        api_headers = body.get("api_headers")

        ingest_kwargs = {}
        if db_type: ingest_kwargs["db_type"] = db_type
        if use_ocr: ingest_kwargs["use_ocr"] = use_ocr
        if custom_queries: ingest_kwargs["custom_queries"] = custom_queries
        if api_headers: ingest_kwargs["api_headers"] = api_headers

        print(f"[TSM] Ingesting: {source} | Client: {client_name} | Domain: {domain}")
        metrics = ingest(source, client_name=client_name, **ingest_kwargs)

        if not metrics or (not metrics.get("raw_snapshot") and not metrics.get("compliance_gaps")):
            self._respond(422, {"error": "Ingestion returned no usable data", "metrics": metrics})
            return

        # ── Build constrained prompt + call Claude ─────────────────────────
        prompt = build_prompt(metrics, domain=domain)
        analysis = call_claude(prompt)

        # ── Return structured response ─────────────────────────────────────
        response = {
            "status": "LIVE_INTEGRATION",
            "client": client_name,
            "domain": domain,
            "source": os.path.basename(source) if os.path.exists(source) else source,
            "metrics": {k: v for k, v in metrics.items() if k != "raw_snapshot"},  # strip raw from response
            "analysis": analysis,
        }

        self._respond(200, response)

    # ── OPTIONS: CORS preflight ────────────────────────────────────────────
    def do_OPTIONS(self):
        self.send_response(200)
        self._cors_headers()
        self.end_headers()

    # ── Helpers ────────────────────────────────────────────────────────────
    def _respond(self, code: int, payload: dict):
        body = json.dumps(payload, indent=2, default=str).encode()
        self.send_response(code)
        self._cors_headers()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print(f"[TSM] Bridge starting on port {PORT}")
    print(f"[TSM] Mode: CLIENT_DATA (live ingestion)")
    print(f"[TSM] Endpoints:")
    print(f"       GET  /health  — status check")
    print(f"       GET  /demo    — demo analysis (no client file needed)")
    print(f"       POST /analyze — live client analysis")
    print()
    print(f"[TSM] Example POST body:")
    print(json.dumps({
        "client_name": "Acme Health System",
        "domain": "compliance",
        "source": "/path/to/client_claims.csv",
    }, indent=2))
    print()

    server = HTTPServer(("0.0.0.0", PORT), TSMBridgeHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[TSM] Bridge stopped.")
        server.server_close()
