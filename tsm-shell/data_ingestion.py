"""
data_ingestion.py — TSM Sovereign Data Ingestion Layer
Handles: CSV/Excel | CMS 837/835 EDI | PDF/OCR | Database/API
Each ingester returns a normalized ClientMetrics dict consumed by tsm_bridge_v2.py
"""

import os
import re
import json
import csv
import sqlite3
from io import StringIO
from typing import Optional


# ─────────────────────────────────────────────────────────────────────────────
# SHARED OUTPUT SCHEMA
# Every ingester must return this structure. Missing fields → None (never fake data).
# ─────────────────────────────────────────────────────────────────────────────

def empty_metrics() -> dict:
    return {
        "client_name": None,
        "client_id": None,
        "source_file": None,
        "source_type": None,

        # Financial
        "total_billed": None,
        "total_paid": None,
        "total_denied": None,
        "denial_rate_pct": None,

        # Compliance
        "overdue_exclusion_screenings": None,
        "last_exclusion_screen_date": None,
        "staff_total": None,
        "npi_verified": None,
        "enrollment_gaps": None,

        # Risk
        "revenue_at_risk": None,
        "high_risk_claims": None,
        "compliance_gaps": [],   # list of plain-English gap strings

        # Raw snapshot for prompt injection (capped at 4000 chars)
        "raw_snapshot": None,
    }


# ─────────────────────────────────────────────────────────────────────────────
# 1. CSV / EXCEL INGESTION
# ─────────────────────────────────────────────────────────────────────────────

def ingest_csv(filepath: str, client_name: str = None) -> dict:
    """
    Accepts: payroll exports, exclusion logs, claim summaries as .csv or .xlsx
    Auto-detects column headers — tolerant of varying export formats.
    """
    try:
        if filepath.endswith(".xlsx") or filepath.endswith(".xls"):
            import openpyxl
            wb = openpyxl.load_workbook(filepath, read_only=True, data_only=True)
            ws = wb.active
            rows = list(ws.iter_rows(values_only=True))
            headers = [str(h).strip().lower().replace(" ", "_") if h else "" for h in rows[0]]
            data = [dict(zip(headers, row)) for row in rows[1:] if any(row)]
        else:
            with open(filepath, newline="", encoding="utf-8-sig") as f:
                reader = csv.DictReader(f)
                headers = [h.strip().lower().replace(" ", "_") for h in reader.fieldnames or []]
                data = [{k.strip().lower().replace(" ", "_"): v for k, v in row.items()} for row in reader]

        metrics = empty_metrics()
        metrics["source_file"] = os.path.basename(filepath)
        metrics["source_type"] = "CSV/Excel"
        metrics["client_name"] = client_name

        # ── Financial columns ──────────────────────────────────────────────
        def col_sum(keys):
            for k in keys:
                vals = [_to_float(row.get(k)) for row in data if _to_float(row.get(k)) is not None]
                if vals:
                    return round(sum(vals), 2)
            return None

        metrics["total_billed"]  = col_sum(["billed_amount", "charge_amount", "total_billed", "amount_billed"])
        metrics["total_paid"]    = col_sum(["paid_amount", "amount_paid", "payment", "total_paid"])
        metrics["total_denied"]  = col_sum(["denied_amount", "denial_amount", "amount_denied", "total_denied"])

        if metrics["total_billed"] and metrics["total_denied"]:
            metrics["denial_rate_pct"] = round(metrics["total_denied"] / metrics["total_billed"] * 100, 2)

        # ── Compliance columns ─────────────────────────────────────────────
        def col_count(keys, filter_fn=None):
            for k in keys:
                if any(k in row for row in data):
                    rows_k = [row for row in data if row.get(k)]
                    return len([r for r in rows_k if filter_fn(r)] if filter_fn else rows_k)
            return None

        overdue_keys = ["exclusion_overdue", "screening_overdue", "overdue"]
        metrics["overdue_exclusion_screenings"] = col_count(
            overdue_keys,
            filter_fn=lambda r: str(list(r.values())[0]).strip().lower() in ("yes", "true", "1", "overdue")
        )

        staff_keys = ["employee_id", "staff_id", "provider_id", "npi"]
        metrics["staff_total"] = col_count(staff_keys)

        # ── Gap detection ──────────────────────────────────────────────────
        gaps = []
        if metrics["overdue_exclusion_screenings"] and metrics["overdue_exclusion_screenings"] > 0:
            gaps.append(f"{metrics['overdue_exclusion_screenings']} staff overdue for OIG exclusion screening (42 CFR § 1001.501)")
        if metrics["denial_rate_pct"] and metrics["denial_rate_pct"] > 10:
            gaps.append(f"Denial rate of {metrics['denial_rate_pct']}% exceeds 10% threshold — review claims submission controls (42 CFR § 405.874)")
        metrics["compliance_gaps"] = gaps

        if metrics["total_denied"]:
            metrics["revenue_at_risk"] = metrics["total_denied"]

        # ── Raw snapshot ───────────────────────────────────────────────────
        snapshot_rows = data[:20]
        metrics["raw_snapshot"] = f"Headers: {headers}\nSample ({len(snapshot_rows)} rows):\n" + \
            "\n".join(str(r) for r in snapshot_rows)
        metrics["raw_snapshot"] = metrics["raw_snapshot"][:4000]

        return metrics

    except Exception as e:
        m = empty_metrics()
        m["compliance_gaps"] = [f"CSV ingestion error: {str(e)}"]
        return m


# ─────────────────────────────────────────────────────────────────────────────
# 2. CMS 837/835 EDI INGESTION
# ─────────────────────────────────────────────────────────────────────────────

def ingest_edi(filepath: str, client_name: str = None) -> dict:
    """
    Parses 837 (claims) and 835 (remittance/ERA) EDI files.
    Extracts: billed amounts, paid amounts, denial codes, NPI, claim counts.
    No external library required — pure segment parsing.
    """
    try:
        with open(filepath, "r", encoding="utf-8-sig") as f:
            content = f.read()

        metrics = empty_metrics()
        metrics["source_file"] = os.path.basename(filepath)
        metrics["client_name"] = client_name

        # Detect file type from ISA/GS/ST segments
        is_835 = "ST*835" in content or "835" in content[:200]
        is_837 = "ST*837" in content or "837" in content[:200]
        metrics["source_type"] = "CMS 835 ERA" if is_835 else "CMS 837 Claims"

        # Normalize delimiters — EDI uses ISA segment to define them
        element_sep = content[3] if len(content) > 3 else "*"
        segment_term = content[105] if len(content) > 105 else "~"
        segments = [s.strip() for s in content.split(segment_term) if s.strip()]

        total_billed = 0.0
        total_paid = 0.0
        total_denied = 0.0
        claim_count = 0
        denial_codes = {}
        npis = set()
        gaps = []

        for seg in segments:
            elements = seg.split(element_sep)
            seg_id = elements[0] if elements else ""

            # 837: Claim-level totals
            if seg_id == "CLM" and len(elements) > 2:
                try:
                    total_billed += float(elements[2])
                    claim_count += 1
                except ValueError:
                    pass

            # 835: Service payment info
            if seg_id == "SVC" and len(elements) > 2:
                try:
                    total_billed += float(elements[2])
                    if len(elements) > 3:
                        total_paid += float(elements[3])
                except ValueError:
                    pass

            # 835: Claim-level adjudication
            if seg_id == "CAS" and len(elements) > 3:
                group_code = elements[1]   # CO, OA, PR, PI
                reason_code = elements[2]
                try:
                    adj_amount = float(elements[3])
                    if group_code == "CO":   # Contractual obligation (denial)
                        total_denied += adj_amount
                        denial_codes[reason_code] = denial_codes.get(reason_code, 0) + adj_amount
                except ValueError:
                    pass

            # NPI extraction (NM1 segment, qualifier XX)
            if seg_id == "NM1" and len(elements) > 9 and elements[8] == "XX":
                npis.add(elements[9])

        metrics["total_billed"]  = round(total_billed, 2) if total_billed else None
        metrics["total_paid"]    = round(total_paid, 2) if total_paid else None
        metrics["total_denied"]  = round(total_denied, 2) if total_denied else None
        metrics["high_risk_claims"] = claim_count
        metrics["npi_verified"]  = len(npis)

        if total_billed and total_denied:
            metrics["denial_rate_pct"] = round(total_denied / total_billed * 100, 2)
            metrics["revenue_at_risk"]  = round(total_denied, 2)

        # Gap detection from denial reason codes
        if denial_codes:
            top = sorted(denial_codes.items(), key=lambda x: x[1], reverse=True)[:3]
            for code, amt in top:
                label = _835_denial_label(code)
                gaps.append(f"Denial code {code} ({label}): ${amt:,.2f} at risk (42 CFR § 405.874)")

        if metrics["denial_rate_pct"] and metrics["denial_rate_pct"] > 5:
            gaps.append(f"Overall denial rate {metrics['denial_rate_pct']}% — claims submission review required")

        metrics["compliance_gaps"] = gaps
        metrics["raw_snapshot"] = f"EDI Type: {metrics['source_type']}\nClaims parsed: {claim_count}\n" \
                                  f"NPIs found: {list(npis)[:10]}\nTop denial codes: {denial_codes}"
        metrics["raw_snapshot"] = metrics["raw_snapshot"][:4000]

        return metrics

    except Exception as e:
        m = empty_metrics()
        m["compliance_gaps"] = [f"EDI ingestion error: {str(e)}"]
        return m


# ─────────────────────────────────────────────────────────────────────────────
# 3. PDF / OCR INGESTION
# ─────────────────────────────────────────────────────────────────────────────

def ingest_pdf(filepath: str, client_name: str = None, use_ocr: bool = False) -> dict:
    """
    Extracts text from PDFs. 
    use_ocr=False → pdfplumber (text-layer PDFs)
    use_ocr=True  → pdf2image + pytesseract (scanned documents)
    Install: pip install pdfplumber pdf2image pytesseract
    """
    try:
        metrics = empty_metrics()
        metrics["source_file"] = os.path.basename(filepath)
        metrics["source_type"] = "PDF (OCR)" if use_ocr else "PDF (text)"
        metrics["client_name"] = client_name

        if use_ocr:
            import pytesseract
            from pdf2image import convert_from_path
            pages = convert_from_path(filepath, dpi=300)
            full_text = "\n\n".join(pytesseract.image_to_string(p) for p in pages)
        else:
            import pdfplumber
            with pdfplumber.open(filepath) as pdf:
                full_text = "\n\n".join(p.extract_text() or "" for p in pdf.pages)

        # ── Pattern extraction from raw text ──────────────────────────────
        def find_currency(patterns):
            for p in patterns:
                m = re.search(p, full_text, re.IGNORECASE)
                if m:
                    return _to_float(m.group(1).replace(",", ""))
            return None

        def find_int(patterns):
            for p in patterns:
                m = re.search(p, full_text, re.IGNORECASE)
                if m:
                    return int(m.group(1).replace(",", ""))
            return None

        metrics["total_billed"] = find_currency([
            r"total(?:\s+amount)?\s+billed[:\s]+\$?([\d,]+\.?\d*)",
            r"charges?[:\s]+\$?([\d,]+\.?\d*)",
        ])
        metrics["total_paid"] = find_currency([
            r"(?:total\s+)?(?:amount\s+)?paid[:\s]+\$?([\d,]+\.?\d*)",
            r"payment[:\s]+\$?([\d,]+\.?\d*)",
        ])
        metrics["total_denied"] = find_currency([
            r"(?:total\s+)?denied[:\s]+\$?([\d,]+\.?\d*)",
            r"denial(?:s)?[:\s]+\$?([\d,]+\.?\d*)",
        ])
        metrics["overdue_exclusion_screenings"] = find_int([
            r"(\d+)\s+(?:staff|employee|provider)s?\s+overdue",
            r"exclusion\s+screening[s]?[:\s]+(\d+)\s+overdue",
        ])
        metrics["staff_total"] = find_int([
            r"(?:total\s+)?staff[:\s]+(\d+)",
            r"(\d+)\s+(?:total\s+)?employees",
        ])

        if metrics["total_billed"] and metrics["total_denied"]:
            metrics["denial_rate_pct"] = round(metrics["total_denied"] / metrics["total_billed"] * 100, 2)
            metrics["revenue_at_risk"] = metrics["total_denied"]

        # ── Gap detection ──────────────────────────────────────────────────
        gaps = []
        gap_patterns = [
            (r"(exclusion\s+screen\w*\s+overdue)", "Exclusion screening overdue (42 CFR § 1001.501)"),
            (r"(enrollment\s+(?:gap|issue|missing))", "Provider enrollment gap (42 CFR § 424.510)"),
            (r"(improper\s+payment)", "Improper payment risk (42 CFR § 405.874)"),
            (r"(npi\s+(?:missing|invalid|unverified))", "NPI verification gap (42 CFR § 455.104)"),
        ]
        for pattern, label in gap_patterns:
            if re.search(pattern, full_text, re.IGNORECASE):
                gaps.append(label)

        if metrics["overdue_exclusion_screenings"] and metrics["overdue_exclusion_screenings"] > 0:
            gaps.append(f"{metrics['overdue_exclusion_screenings']} staff overdue for OIG exclusion screening")

        metrics["compliance_gaps"] = gaps
        metrics["raw_snapshot"] = full_text[:4000]

        return metrics

    except Exception as e:
        m = empty_metrics()
        m["compliance_gaps"] = [f"PDF ingestion error: {str(e)}"]
        return m


# ─────────────────────────────────────────────────────────────────────────────
# 4. DATABASE / API INGESTION
# ─────────────────────────────────────────────────────────────────────────────

def ingest_database(
    connection_string: str,
    client_name: str = None,
    db_type: str = "sqlite",   # sqlite | postgres | mysql | sqlserver | api
    api_endpoint: str = None,
    api_headers: dict = None,
    custom_queries: dict = None,
) -> dict:
    """
    Connects to client's database or REST API.
    custom_queries overrides default SQL — use when client schema differs.

    Default queries assume a normalized claims/compliance schema.
    Swap in client-specific table/column names via custom_queries dict:
      {
        "total_billed": "SELECT SUM(charge) FROM billing_ledger",
        "overdue_screenings": "SELECT COUNT(*) FROM staff WHERE screen_date < CURDATE()",
      }
    """
    metrics = empty_metrics()
    metrics["client_name"] = client_name

    # ── API mode ───────────────────────────────────────────────────────────
    if db_type == "api" and api_endpoint:
        try:
            import urllib.request
            req = urllib.request.Request(api_endpoint, headers=api_headers or {})
            with urllib.request.urlopen(req, timeout=10) as resp:
                raw = json.loads(resp.read().decode())
            metrics["source_type"] = "REST API"
            metrics["raw_snapshot"] = json.dumps(raw, indent=2)[:4000]
            # Map known API response shapes
            _map_api_response(raw, metrics)
            return metrics
        except Exception as e:
            metrics["compliance_gaps"] = [f"API connection error: {str(e)}"]
            return metrics

    # ── SQL mode ──────────────────────────────────────────────────────────
    metrics["source_type"] = f"Database ({db_type})"

    default_queries = {
        "total_billed":              "SELECT COALESCE(SUM(billed_amount), 0) FROM claims",
        "total_paid":                "SELECT COALESCE(SUM(paid_amount), 0) FROM claims",
        "total_denied":              "SELECT COALESCE(SUM(denied_amount), 0) FROM claims",
        "overdue_screenings":        "SELECT COUNT(*) FROM staff WHERE exclusion_screen_overdue = 1",
        "staff_total":               "SELECT COUNT(*) FROM staff",
        "enrollment_gaps":           "SELECT COUNT(*) FROM providers WHERE npi_verified = 0 OR enrollment_status != 'active'",
        "high_risk_claims":          "SELECT COUNT(*) FROM claims WHERE denial_reason IS NOT NULL",
    }

    queries = {**default_queries, **(custom_queries or {})}

    try:
        if db_type == "sqlite":
            conn = sqlite3.connect(connection_string)
        elif db_type == "postgres":
            import psycopg2
            conn = psycopg2.connect(connection_string)
        elif db_type == "mysql":
            import pymysql
            conn = pymysql.connect(**_parse_mysql_dsn(connection_string))
        elif db_type == "sqlserver":
            import pyodbc
            conn = pyodbc.connect(connection_string)
        else:
            raise ValueError(f"Unsupported db_type: {db_type}")

        cur = conn.cursor()
        results = {}

        for key, sql in queries.items():
            try:
                cur.execute(sql)
                row = cur.fetchone()
                results[key] = row[0] if row else None
            except Exception as qe:
                results[key] = None  # Query failed — field stays None, not fabricated

        conn.close()

        metrics["total_billed"]                  = _to_float(results.get("total_billed"))
        metrics["total_paid"]                     = _to_float(results.get("total_paid"))
        metrics["total_denied"]                   = _to_float(results.get("total_denied"))
        metrics["overdue_exclusion_screenings"]   = results.get("overdue_screenings")
        metrics["staff_total"]                    = results.get("staff_total")
        metrics["enrollment_gaps"]                = results.get("enrollment_gaps")
        metrics["high_risk_claims"]               = results.get("high_risk_claims")

        if metrics["total_billed"] and metrics["total_denied"]:
            metrics["denial_rate_pct"] = round(metrics["total_denied"] / metrics["total_billed"] * 100, 2)
            metrics["revenue_at_risk"] = metrics["total_denied"]

        gaps = []
        if metrics["overdue_exclusion_screenings"] and metrics["overdue_exclusion_screenings"] > 0:
            gaps.append(f"{metrics['overdue_exclusion_screenings']} staff overdue for OIG exclusion screening (42 CFR § 1001.501)")
        if metrics["enrollment_gaps"] and metrics["enrollment_gaps"] > 0:
            gaps.append(f"{metrics['enrollment_gaps']} providers with enrollment/NPI gaps (42 CFR § 424.510, 42 CFR § 455.104)")
        if metrics["denial_rate_pct"] and metrics["denial_rate_pct"] > 10:
            gaps.append(f"Denial rate {metrics['denial_rate_pct']}% — claims submission controls review required (42 CFR § 405.874)")

        metrics["compliance_gaps"] = gaps
        metrics["raw_snapshot"] = json.dumps(results, indent=2)[:4000]

        return metrics

    except Exception as e:
        metrics["compliance_gaps"] = [f"Database connection error: {str(e)}"]
        return metrics


# ─────────────────────────────────────────────────────────────────────────────
# UNIFIED ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────

def ingest(source: str, client_name: str = None, **kwargs) -> dict:
    """
    Auto-routes to the correct ingester based on file extension or source type.
    
    Usage:
        metrics = ingest("path/to/claims.csv", client_name="Acme Health")
        metrics = ingest("path/to/remittance.835", client_name="Acme Health")
        metrics = ingest("path/to/report.pdf", client_name="Acme Health", use_ocr=True)
        metrics = ingest("sqlite:///client.db", client_name="Acme Health", db_type="sqlite")
    """
    ext = os.path.splitext(source)[-1].lower()

    if ext in (".csv", ".xlsx", ".xls"):
        return ingest_csv(source, client_name)
    elif ext in (".835", ".837", ".edi", ".txt") or "837" in source or "835" in source:
        return ingest_edi(source, client_name)
    elif ext == ".pdf":
        return ingest_pdf(source, client_name, use_ocr=kwargs.get("use_ocr", False))
    elif source.startswith(("sqlite", "postgresql", "mysql", "mssql")) or kwargs.get("db_type"):
        return ingest_database(source, client_name, **kwargs)
    else:
        m = empty_metrics()
        m["compliance_gaps"] = [f"Unknown source format: {ext}"]
        return m


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def _to_float(val) -> Optional[float]:
    if val is None:
        return None
    try:
        return float(str(val).replace(",", "").replace("$", "").strip())
    except (ValueError, TypeError):
        return None

def _835_denial_label(code: str) -> str:
    labels = {
        "1": "Deductible", "2": "Coinsurance", "3": "Co-payment",
        "4": "Contract adj", "45": "Charge exceeds fee schedule",
        "97": "Non-covered benefit", "96": "Non-covered charge",
        "B7": "Not authorized/certified", "CO": "Contractual obligation",
        "PR": "Patient responsibility", "OA": "Other adjustment",
        "PI": "Payer initiated reduction", "MA01": "Appeal rights notice",
    }
    return labels.get(code, "Unknown reason")

def _map_api_response(raw: dict, metrics: dict):
    """Maps common API response shapes to the metrics schema."""
    field_map = {
        "total_billed": ["total_billed", "totalBilled", "charges", "amount_billed"],
        "total_paid": ["total_paid", "totalPaid", "paid", "amount_paid"],
        "total_denied": ["total_denied", "totalDenied", "denied", "amount_denied"],
        "overdue_exclusion_screenings": ["overdue_screenings", "overdueScreenings", "overdue"],
        "staff_total": ["staff_count", "staffTotal", "employee_count"],
    }
    for metric_key, api_keys in field_map.items():
        for ak in api_keys:
            if ak in raw:
                metrics[metric_key] = raw[ak]
                break

def _parse_mysql_dsn(dsn: str) -> dict:
    """Minimal DSN parser for mysql://user:pass@host:port/db"""
    m = re.match(r"mysql://(\w+):(\w+)@([\w.]+):?(\d+)?/(\w+)", dsn)
    if m:
        return {"user": m[1], "password": m[2], "host": m[3],
                "port": int(m[4] or 3306), "database": m[5]}
    raise ValueError(f"Cannot parse MySQL DSN: {dsn}")
