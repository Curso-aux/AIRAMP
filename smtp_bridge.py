#!/usr/bin/env python3
"""
AIRA SMTP Bridge & Cloud Queue Daemon
--------------------------------------
Dual-mode email delivery engine:
1. HTTP Server on port 8088: Serves instant local POST requests from Flutter Web/Mobile.
2. Cloud Firestore Queue Consumer: Continuously polls Cloud Firestore `mail` collection
   for pending emails dispatched from Deployed Web (Firebase Hosting), delivering them
   directly through Gmail SMTP using SSL/TLS.
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

# Enable unbuffered stdout logging
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(line_buffering=True)
except Exception:
    pass

# Load environment configuration from .env if present
def _load_env_file():
    candidates = [
        os.path.join(os.path.dirname(__file__), ".env"),
        os.path.join(os.path.dirname(__file__), "airamp_flutter", ".env"),
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
            except Exception:
                pass

_load_env_file()

PORT = int(os.environ.get("PORT", 8088))
DEFAULT_SENDER = os.environ.get("SMTP_SENDER_EMAIL", "evangelistachristian88@gmail.com")
DEFAULT_PASSWORD = os.environ.get("SMTP_APP_PASSWORD", "ljvh jvre qasx serr")
SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", 587))
FIREBASE_PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "aira-app-database")

# ─────────────────────────────────────────────────────────────
# Rate Limiting Engine: protects SMTP from abuse & quota exhaustion
# ─────────────────────────────────────────────────────────────
IP_MAX_PER_MINUTE = 60
RECIPIENT_MAX_PER_3MIN = 25
RECIPIENT_COOLDOWN_SECONDS = 2

_ip_history = defaultdict(list)
_recipient_history = defaultdict(list)
_recipient_last_dispatch = {}
_processed_queue_docs = set()

def check_rate_limit(recipient_email, client_ip=None):
    """Checks rate limits for a given recipient and optional client IP."""
    now = time.time()
    clean_recipient = recipient_email.lower().strip()

    if client_ip:
        _ip_history[client_ip] = [t for t in _ip_history[client_ip] if now - t < 60]
        if len(_ip_history[client_ip]) >= IP_MAX_PER_MINUTE:
            oldest = _ip_history[client_ip][0]
            retry_after = max(1, int(60 - (now - oldest)))
            return False, f"IP rate limit exceeded ({IP_MAX_PER_MINUTE} req/min). Please wait {retry_after}s.", retry_after

    last_sent = _recipient_last_dispatch.get(clean_recipient)
    if last_sent and (now - last_sent < RECIPIENT_COOLDOWN_SECONDS):
        cooldown_wait = max(1, int(RECIPIENT_COOLDOWN_SECONDS - (now - last_sent)))
        return False, f"Please wait {cooldown_wait}s before sending another email to this address.", cooldown_wait

    _recipient_history[clean_recipient] = [t for t in _recipient_history[clean_recipient] if now - t < 180]
    if len(_recipient_history[clean_recipient]) >= RECIPIENT_MAX_PER_3MIN:
        oldest = _recipient_history[clean_recipient][0]
        retry_after = max(1, int(180 - (now - oldest)))
        return False, f"Recipient rate limit reached (max {RECIPIENT_MAX_PER_3MIN} per 3 mins). Please wait {retry_after}s.", retry_after

    # Record allowed dispatch
    if client_ip:
        _ip_history[client_ip].append(now)
    _recipient_history[clean_recipient].append(now)
    _recipient_last_dispatch[clean_recipient] = now
    return True, "", 0

def send_smtp_email(to_email, subject, text_body, html_body, sender_email=None, sender_password=None):
    """
    Delivers an email using Gmail SMTP with dual-strategy fallback:
    Strategy 1: Port 587 STARTTLS
    Strategy 2: Port 465 direct SSL
    """
    clean_sender = (sender_email or DEFAULT_SENDER).strip()
    clean_password = (sender_password or DEFAULT_PASSWORD).replace(" ", "").strip()
    clean_to = to_email.strip()

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"AIRA Platform <{clean_sender}>"
    msg["To"] = clean_to

    if text_body:
        msg.attach(MIMEText(text_body, "plain", "utf-8"))
    if html_body:
        msg.attach(MIMEText(html_body, "html", "utf-8"))
    elif not text_body:
        msg.attach(MIMEText("No content provided", "plain", "utf-8"))

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Strategy 1: Port 587 STARTTLS
    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=14) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(clean_sender, clean_password)
            server.send_message(msg)
        return True, "Delivered via Gmail SMTP (Port 587 STARTTLS)"
    except Exception as err587:
        # Strategy 2: Port 465 direct SSL
        try:
            with smtplib.SMTP_SSL(SMTP_HOST, 465, timeout=14) as server:
                server.login(clean_sender, clean_password)
                server.send_message(msg)
            return True, "Delivered via Gmail SMTP (Port 465 SSL Fallback)"
        except Exception as err465:
            return False, f"SMTP Error (587: {err587} | 465: {err465})"

class ReusableHTTPServer(HTTPServer):
    allow_reuse_address = True

class SmtpBridgeHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With, Access-Control-Request-Private-Network")
        self.send_header("Access-Control-Allow-Private-Network", "true")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        response = {
            "status": "online",
            "service": "AIRA Dual-Mode SMTP Bridge & Cloud Queue Daemon",
            "sender": DEFAULT_SENDER,
            "port": PORT,
            "firebase_project": FIREBASE_PROJECT_ID,
            "rate_limits": {
                "ip_max_per_minute": IP_MAX_PER_MINUTE,
                "recipient_max_per_3min": RECIPIENT_MAX_PER_3MIN,
                "recipient_cooldown_seconds": RECIPIENT_COOLDOWN_SECONDS
            },
            "timestamp": datetime.now().isoformat()
        }
        self.wfile.write(json.dumps(response).encode("utf-8"))

    def do_POST(self):
        clean_path = self.path.split('?')[0].rstrip('/')
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
            self.wfile.write(json.dumps({"error": f"Invalid JSON payload: {e}"}).encode("utf-8"))
            return

        to_email = payload.get("to") or payload.get("toEmail") or payload.get("recipient")
        subject = payload.get("subject", "AIRA Platform Notification")
        text_body = payload.get("text") or payload.get("textContent") or ""
        html_body = payload.get("html") or payload.get("htmlContent") or ""
        sender_email = payload.get("sender") or DEFAULT_SENDER
        sender_password = payload.get("password") or DEFAULT_PASSWORD

        if not to_email:
            self.send_response(400)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Missing 'to' recipient email"}).encode("utf-8"))
            return

        # Check rate limits
        allowed, rate_msg, retry_after = check_rate_limit(to_email, client_ip)
        if not allowed:
            self.send_response(429)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Retry-After", str(retry_after))
            self.end_headers()
            self.wfile.write(json.dumps({
                "success": False,
                "error": rate_msg,
                "retry_after": retry_after
            }).encode("utf-8"))
            return

        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [HTTP-API] Incoming email dispatch request to: {to_email}")
        print(f"[{timestamp}] [HTTP-API] Subject: {subject}")

        success, detail = send_smtp_email(to_email, subject, text_body, html_body, sender_email, sender_password)

        if success:
            print(f"[{timestamp}] [SUCCESS] Delivered email via Gmail SMTP to: {to_email}")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {
                "success": True,
                "message": f"Credentials email delivered to {to_email} via Gmail SMTP",
                "detail": detail,
                "to": to_email,
                "timestamp": timestamp
            }
            self.wfile.write(json.dumps(response).encode("utf-8"))
        else:
            print(f"[{timestamp}] [ERROR] Failed to send email via SMTP: {detail}")
            self.send_response(500)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {
                "success": False,
                "error": detail,
                "timestamp": timestamp
            }
            self.wfile.write(json.dumps(response).encode("utf-8"))

    def log_message(self, format, *args):
        # Suppress noisy default console access logs
        pass

# ─────────────────────────────────────────────────────────────
# Cloud Firestore Queue Consumer Thread
# ─────────────────────────────────────────────────────────────
def run_firestore_queue_consumer():
    """
    Continuously polls Cloud Firestore `mail` collection for pending
    emails created by Deployed Web (Firebase Hosting) or client fallbacks.
    Dispatches each email via Gmail SMTP and marks document status.
    """
    query_url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery"
    print(f"[*] Cloud Firestore Queue Consumer active for project: {FIREBASE_PROJECT_ID}")

    while True:
        try:
            query = {
                "structuredQuery": {
                    "from": [{"collectionId": "mail"}],
                    "where": {
                        "fieldFilter": {
                            "field": {"fieldPath": "status"},
                            "op": "EQUAL",
                            "value": {"stringValue": "pending"}
                        }
                    },
                    "limit": 15
                }
            }

            req = urllib.request.Request(
                query_url,
                data=json.dumps(query).encode("utf-8"),
                headers={"Content-Type": "application/json"}
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
                subject = fields.get("subject", {}).get("stringValue", "AIRA Platform Notification")
                text_body = fields.get("text", {}).get("stringValue", "")
                html_body = fields.get("html", {}).get("stringValue", "")

                if not to_email:
                    continue

                _processed_queue_docs.add(doc_name)
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                print(f"[{timestamp}] [CLOUD-QUEUE] Discovered pending email in Firestore for: {to_email}")
                print(f"[{timestamp}] [CLOUD-QUEUE] Subject: {subject}")

                allowed, rate_msg, _ = check_rate_limit(to_email)
                if not allowed:
                    print(f"[{timestamp}] [RATE-LIMIT] Cloud queue rate-limited for: {to_email} ({rate_msg})")
                    # We will retry on next poll cycle after cooldown
                    _processed_queue_docs.remove(doc_name)
                    continue

                success, detail = send_smtp_email(to_email, subject, text_body, html_body)

                patch_url = f"https://firestore.googleapis.com/v1/{doc_name}?updateMask.fieldPaths=status&updateMask.fieldPaths=sent_at"
                status_val = "sent_via_smtp" if success else "failed"

                patch_fields = {
                    "status": {"stringValue": status_val},
                    "sent_at": {"stringValue": datetime.now().isoformat()}
                }
                if not success:
                    patch_fields["error"] = {"stringValue": detail[:500]}
                    patch_url += "&updateMask.fieldPaths=error"

                try:
                    patch_req = urllib.request.Request(
                        patch_url,
                        data=json.dumps({"fields": patch_fields}).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="PATCH"
                    )
                    with urllib.request.urlopen(patch_req, timeout=10):
                        pass
                except Exception as patch_err:
                    print(f"[{timestamp}] [WARN] Could not patch Firestore status for {doc_name}: {patch_err}")

                if success:
                    print(f"[{timestamp}] [SUCCESS] [CLOUD-QUEUE] Delivered email via Gmail SMTP to: {to_email}")
                else:
                    print(f"[{timestamp}] [ERROR] [CLOUD-QUEUE] Failed delivering email to {to_email}: {detail}")

        except Exception as e:
            # Silent backoff on transient network errors
            pass

        time.sleep(3)

def run():
    server_address = ("0.0.0.0", PORT)
    try:
        httpd = ReusableHTTPServer(server_address, SmtpBridgeHandler)
    except OSError as e:
        print(f"[!] Could not bind to port {PORT}: {e}")
        return

    # Start Cloud Firestore Queue consumer in background daemon thread
    consumer_thread = threading.Thread(target=run_firestore_queue_consumer, daemon=True)
    consumer_thread.start()

    print("==================================================")
    print(f" AIRA SMTP Bridge & Cloud Queue Daemon Running")
    print(f" HTTP Endpoint: http://127.0.0.1:{PORT}/send-email")
    print(f" Cloud Queue: Listening to Firestore `mail` (project: {FIREBASE_PROJECT_ID})")
    print(f" Sender Account: {DEFAULT_SENDER}")
    print(f" Gmail SMTP Host: {SMTP_HOST}:{SMTP_PORT}")
    print("==================================================")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down AIRA SMTP Bridge...")
        httpd.server_close()

if __name__ == "__main__":
    run()
