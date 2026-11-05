#!/usr/bin/env python3
"""
AIRA SMTP Bridge — Cloud Deployment Version
---------------------------------------------
Runs on Render.com (or any cloud host) to deliver emails for the
deployed Firebase-hosted AIRA web application.

Two jobs run in parallel:
1. HTTP Server — accepts POST /send-email from your Flutter app directly.
2. Firestore Queue Consumer — polls the Cloud Firestore `mail` collection
   every few seconds for documents with status "pending", sends them via
   Gmail SMTP, then updates the document status.

All secrets are read from environment variables (set in Render dashboard).
"""

import sys
import json
import smtplib
import os
import time
import threading
import urllib.request
import urllib.error
from collections import defaultdict
from http.server import HTTPServer, BaseHTTPRequestHandler
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime

# Unbuffered stdout so Render logs appear in real time
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(line_buffering=True)
except Exception:
    pass

# ── Configuration (all from environment variables) ──────────────
PORT = int(os.environ.get("PORT", 10000))
DEFAULT_SENDER = os.environ.get("SMTP_SENDER_EMAIL", "")
DEFAULT_PASSWORD = os.environ.get("SMTP_APP_PASSWORD", "")
SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", 587))
FIREBASE_PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "aira-app-database")
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", 5))  # seconds between queue checks

# ── Rate Limiting ───────────────────────────────────────────────
IP_MAX_PER_MINUTE = 60
RECIPIENT_MAX_PER_3MIN = 25
RECIPIENT_COOLDOWN_SECONDS = 2

_ip_history = defaultdict(list)
_recipient_history = defaultdict(list)
_recipient_last_dispatch = {}
_processed_queue_docs = set()


def check_rate_limit(recipient_email, client_ip=None):
    now = time.time()
    clean_recipient = recipient_email.lower().strip()

    if client_ip:
        _ip_history[client_ip] = [t for t in _ip_history[client_ip] if now - t < 60]
        if len(_ip_history[client_ip]) >= IP_MAX_PER_MINUTE:
            oldest = _ip_history[client_ip][0]
            retry_after = max(1, int(60 - (now - oldest)))
            return False, f"IP rate limit exceeded. Wait {retry_after}s.", retry_after

    last_sent = _recipient_last_dispatch.get(clean_recipient)
    if last_sent and (now - last_sent < RECIPIENT_COOLDOWN_SECONDS):
        cooldown_wait = max(1, int(RECIPIENT_COOLDOWN_SECONDS - (now - last_sent)))
        return False, f"Wait {cooldown_wait}s before sending another email to this address.", cooldown_wait

    _recipient_history[clean_recipient] = [t for t in _recipient_history[clean_recipient] if now - t < 180]
    if len(_recipient_history[clean_recipient]) >= RECIPIENT_MAX_PER_3MIN:
        oldest = _recipient_history[clean_recipient][0]
        retry_after = max(1, int(180 - (now - oldest)))
        return False, f"Recipient rate limit reached. Wait {retry_after}s.", retry_after

    if client_ip:
        _ip_history[client_ip].append(now)
    _recipient_history[clean_recipient].append(now)
    _recipient_last_dispatch[clean_recipient] = now
    return True, "", 0


def send_smtp_email(to_email, subject, text_body, html_body, sender_email=None, sender_password=None):
    clean_sender = (sender_email or DEFAULT_SENDER).strip()
    clean_password = (sender_password or DEFAULT_PASSWORD).replace(" ", "").strip()
    clean_to = to_email.strip()

    if not clean_sender or not clean_password:
        return False, "SMTP credentials not configured. Set SMTP_SENDER_EMAIL and SMTP_APP_PASSWORD."

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"AIRAMP Platform <{clean_sender}>"
    msg["To"] = clean_to

    if text_body:
        msg.attach(MIMEText(text_body, "plain", "utf-8"))
    if html_body:
        msg.attach(MIMEText(html_body, "html", "utf-8"))
    elif not text_body:
        msg.attach(MIMEText("No content provided", "plain", "utf-8"))

    # Strategy 1: Port 587 STARTTLS
    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=15) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(clean_sender, clean_password)
            server.send_message(msg)
        return True, "Delivered via Gmail SMTP (587 STARTTLS)"
    except Exception as err587:
        # Strategy 2: Port 465 direct SSL
        try:
            with smtplib.SMTP_SSL(SMTP_HOST, 465, timeout=15) as server:
                server.login(clean_sender, clean_password)
                server.send_message(msg)
            return True, "Delivered via Gmail SMTP (465 SSL)"
        except Exception as err465:
            return False, f"SMTP Error (587: {err587} | 465: {err465})"


# ── HTTP Server ─────────────────────────────────────────────────
class ReusableHTTPServer(HTTPServer):
    allow_reuse_address = True


class SmtpBridgeHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        """Health check endpoint — Render pings this to know the service is alive."""
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        response = {
            "status": "online",
            "service": "AIRA SMTP Bridge (Cloud)",
            "firebase_project": FIREBASE_PROJECT_ID,
            "timestamp": datetime.now().isoformat(),
        }
        self.wfile.write(json.dumps(response).encode("utf-8"))

    def do_POST(self):
        clean_path = self.path.split("?")[0].rstrip("/")
        if clean_path not in ["/send-email", "/send", "/api/send-email", ""]:
            self.send_response(404)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Endpoint not found"}).encode("utf-8"))
            return

        client_ip = self.client_address[0]
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length)

        try:
            payload = json.loads(post_data.decode("utf-8"))
        except Exception as e:
            self.send_response(400)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": f"Invalid JSON: {e}"}).encode("utf-8"))
            return

        to_email = payload.get("to") or payload.get("toEmail") or payload.get("recipient")
        subject = payload.get("subject", "AIRA Platform Notification")
        text_body = payload.get("text") or payload.get("textContent") or ""
        html_body = payload.get("html") or payload.get("htmlContent") or ""

        if not to_email:
            self.send_response(400)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Missing 'to' recipient"}).encode("utf-8"))
            return

        allowed, rate_msg, retry_after = check_rate_limit(to_email, client_ip)
        if not allowed:
            self.send_response(429)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Retry-After", str(retry_after))
            self.end_headers()
            self.wfile.write(json.dumps({"success": False, "error": rate_msg, "retry_after": retry_after}).encode("utf-8"))
            return

        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{ts}] [HTTP] Email request → {to_email} | Subject: {subject[:60]}")

        success, detail = send_smtp_email(to_email, subject, text_body, html_body)

        status_code = 200 if success else 500
        self.send_response(status_code)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        result = {"success": success, "detail": detail, "to": to_email, "timestamp": ts}
        if success:
            result["message"] = f"Email delivered to {to_email}"
            print(f"[{ts}] [HTTP] ✅ Delivered to {to_email}")
        else:
            result["error"] = detail
            print(f"[{ts}] [HTTP] ❌ Failed for {to_email}: {detail}")
        self.wfile.write(json.dumps(result).encode("utf-8"))

    def log_message(self, fmt, *args):
        pass  # Suppress noisy default access logs


# ── Firestore Queue Consumer ───────────────────────────────────
def run_firestore_queue_consumer():
    query_url = (
        f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}"
        f"/databases/(default)/documents:runQuery"
    )
    print(f"[*] Firestore Queue Consumer started — project: {FIREBASE_PROJECT_ID}")

    while True:
        try:
            query = {
                "structuredQuery": {
                    "from": [{"collectionId": "mail"}],
                    "where": {
                        "fieldFilter": {
                            "field": {"fieldPath": "status"},
                            "op": "EQUAL",
                            "value": {"stringValue": "pending"},
                        }
                    },
                    "limit": 15,
                }
            }

            req = urllib.request.Request(
                query_url,
                data=json.dumps(query).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )

            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode("utf-8"))

            documents = [item["document"] for item in data if "document" in item]

            for doc in documents:
                doc_name = doc.get("name", "")
                if not doc_name or doc_name in _processed_queue_docs:
                    continue

                fields = doc.get("fields", {})
                to_email = fields.get("to", {}).get("stringValue", "").strip()
                subject = fields.get("subject", {}).get("stringValue", "AIRA Notification")
                text_body = fields.get("text", {}).get("stringValue", "")
                html_body = fields.get("html", {}).get("stringValue", "")

                if not to_email:
                    continue

                _processed_queue_docs.add(doc_name)
                ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                print(f"[{ts}] [QUEUE] Found pending email → {to_email}")

                allowed, rate_msg, _ = check_rate_limit(to_email)
                if not allowed:
                    print(f"[{ts}] [QUEUE] Rate-limited: {rate_msg}")
                    _processed_queue_docs.remove(doc_name)
                    continue

                success, detail = send_smtp_email(to_email, subject, text_body, html_body)

                # Update Firestore document status
                patch_url = (
                    f"https://firestore.googleapis.com/v1/{doc_name}"
                    f"?updateMask.fieldPaths=status&updateMask.fieldPaths=sent_at"
                )
                status_val = "sent_via_smtp" if success else "failed"
                patch_fields = {
                    "status": {"stringValue": status_val},
                    "sent_at": {"stringValue": datetime.now().isoformat()},
                }
                if not success:
                    patch_fields["error"] = {"stringValue": detail[:500]}
                    patch_url += "&updateMask.fieldPaths=error"

                try:
                    patch_req = urllib.request.Request(
                        patch_url,
                        data=json.dumps({"fields": patch_fields}).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="PATCH",
                    )
                    with urllib.request.urlopen(patch_req, timeout=10):
                        pass
                except Exception as patch_err:
                    print(f"[{ts}] [WARN] Could not patch Firestore: {patch_err}")

                if success:
                    print(f"[{ts}] [QUEUE] ✅ Delivered to {to_email}")
                else:
                    print(f"[{ts}] [QUEUE] ❌ Failed for {to_email}: {detail}")

        except Exception:
            pass  # Silent backoff on transient errors

        time.sleep(POLL_INTERVAL)


# ── Main ────────────────────────────────────────────────────────
def run():
    if not DEFAULT_SENDER or not DEFAULT_PASSWORD:
        print("=" * 55)
        print("  ⚠  SMTP_SENDER_EMAIL and SMTP_APP_PASSWORD must be")
        print("     set as environment variables in Render dashboard!")
        print("=" * 55)

    server_address = ("0.0.0.0", PORT)
    try:
        httpd = ReusableHTTPServer(server_address, SmtpBridgeHandler)
    except OSError as e:
        print(f"[!] Could not bind to port {PORT}: {e}")
        return

    # Start Firestore queue consumer in background
    consumer = threading.Thread(target=run_firestore_queue_consumer, daemon=True)
    consumer.start()

    print("=" * 55)
    print(f"  AIRA SMTP Bridge — Cloud Edition")
    print(f"  HTTP:  http://0.0.0.0:{PORT}/send-email")
    print(f"  Queue: Polling Firestore `mail` every {POLL_INTERVAL}s")
    print(f"  Project: {FIREBASE_PROJECT_ID}")
    print(f"  Sender: {DEFAULT_SENDER or '(not set!)'}")
    print("=" * 55)

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        httpd.server_close()


if __name__ == "__main__":
    run()

