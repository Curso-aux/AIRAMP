#!/usr/bin/env python3
"""
AIRA SMTP Bridge & Cloud Queue Daemon (Cloud & Local Edition)
--------------------------------------------------------------
Dual-delivery engine:
1. Brevo HTTPS REST API (Port 443) — primary cloud transport (never blocked by Render/AWS).
2. Gmail SMTP Direct (Port 587/465) — fallback for local execution.
3. Firestore Queue Consumer — polls Cloud Firestore `mail` collection
   for pending emails dispatched from Deployed Web (Firebase Hosting).
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

# Unbuffered stdout logging
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(line_buffering=True)
except Exception:
    pass

# ── Configuration (Environment Variables with Fallbacks) ───────
PORT = int(os.environ.get("PORT", 10000))
BREVO_API_KEY = os.environ.get("BREVO_API_KEY", "").strip()
BREVO_SENDER_EMAIL = os.environ.get("BREVO_SENDER_EMAIL", "luyahan007@gmail.com").strip()
DEFAULT_SENDER = os.environ.get("SMTP_SENDER_EMAIL", "evangelistachristian88@gmail.com").strip()
DEFAULT_PASSWORD = os.environ.get("SMTP_APP_PASSWORD", "ljvh jvre qasx serr").strip()
SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com").strip()
SMTP_PORT = int(os.environ.get("SMTP_PORT", 587))
FIREBASE_PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "aira-app-database").strip()
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", 5))

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


def send_via_brevo_api(to_email, subject, text_body, html_body):
    """
    Sends email via Brevo HTTPS REST API on Port 443.
    Never blocked by cloud hosts (Render, AWS, DigitalOcean).
    """
    if not BREVO_API_KEY:
        return False, "Brevo API key not configured"

    url = "https://api.brevo.com/v3/smtp/email"
    headers = {
        "accept": "application/json",
        "api-key": BREVO_API_KEY,
        "content-type": "application/json",
    }
    payload = {
        "sender": {
            "name": "AIRAMP Platform",
            "email": BREVO_SENDER_EMAIL or "luyahan007@gmail.com",
        },
        "to": [{"email": to_email.strip()}],
        "subject": subject,
        "htmlContent": html_body if html_body else f"<p>{text_body}</p>",
        "textContent": text_body if text_body else "",
    }

    try:
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            msg_id = data.get("messageId", "ok")
            return True, f"Delivered via Brevo HTTPS API (messageId: {msg_id})"
    except urllib.error.HTTPError as http_err:
        err_body = http_err.read().decode("utf-8", errors="ignore")
        return False, f"Brevo HTTP {http_err.code}: {err_body}"
    except Exception as e:
        return False, f"Brevo connection error: {e}"


def send_via_smtp_fallback(to_email, subject, text_body, html_body):
    """
    Fallback method: direct SMTP via Gmail (Port 587/465).
    Works on local PC or non-blocked environments.
    """
    clean_sender = DEFAULT_SENDER.strip()
    clean_password = DEFAULT_PASSWORD.replace(" ", "").strip()
    clean_to = to_email.strip()

    if not clean_sender or not clean_password:
        return False, "SMTP credentials missing"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"AIRAMP Platform <{clean_sender}>"
    msg["To"] = clean_to

    if text_body:
        msg.attach(MIMEText(text_body, "plain", "utf-8"))
    if html_body:
        msg.attach(MIMEText(html_body, "html", "utf-8"))

    # Try 587 STARTTLS
    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(clean_sender, clean_password)
            server.send_message(msg)
        return True, "Delivered via Gmail SMTP (Port 587 STARTTLS)"
    except Exception as err587:
        # Try 465 SSL
        try:
            with smtplib.SMTP_SSL(SMTP_HOST, 465, timeout=10) as server:
                server.login(clean_sender, clean_password)
                server.send_message(msg)
            return True, "Delivered via Gmail SMTP (Port 465 SSL)"
        except Exception as err465:
            return False, f"SMTP error (587: {err587} | 465: {err465})"


def send_email_multi_transport(to_email, subject, text_body, html_body):
    """
    Primary: Brevo HTTPS REST API (port 443 - 100% works on cloud)
    Secondary / Fallback: Gmail Direct SMTP (ports 587/465)
    """
    # 1. Primary: Brevo API
    success, detail = send_via_brevo_api(to_email, subject, text_body, html_body)
    if success:
        return True, detail

    # 2. Secondary fallback: Gmail SMTP
    print(f"[WARN] Brevo delivery failed: {detail}. Attempting SMTP fallback...")
    smtp_ok, smtp_detail = send_via_smtp_fallback(to_email, subject, text_body, html_body)
    if smtp_ok:
        return True, smtp_detail

    return False, f"All transports failed: Brevo ({detail}) | SMTP ({smtp_detail})"


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
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        response = {
            "status": "online",
            "service": "AIRAMP Email Bridge (Brevo HTTPS + SMTP Relay)",
            "primary_transport": "Brevo HTTPS API (Port 443)",
            "firebase_project": FIREBASE_PROJECT_ID,
            "sender": BREVO_SENDER_EMAIL,
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
        subject = payload.get("subject", "AIRAMP Notification")
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
        print(f"[{ts}] [HTTP] Incoming email dispatch request to: {to_email}")

        success, detail = send_email_multi_transport(to_email, subject, text_body, html_body)

        status_code = 200 if success else 500
        self.send_response(status_code)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        res = {"success": success, "detail": detail, "to": to_email, "timestamp": ts}
        if success:
            res["message"] = f"Email delivered to {to_email}"
            print(f"[{ts}] [HTTP] ✅ Delivered to {to_email} via {detail}")
        else:
            res["error"] = detail
            print(f"[{ts}] [HTTP] ❌ Failed for {to_email}: {detail}")
        self.wfile.write(json.dumps(res).encode("utf-8"))

    def log_message(self, fmt, *args):
        pass


# ── Firestore Queue Consumer ───────────────────────────────────
def run_firestore_queue_consumer():
    query_url = (
        f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}"
        f"/databases/(default)/documents:runQuery"
    )
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
                subject = fields.get("subject", {}).get("stringValue", "AIRAMP Platform Notification")
                text_body = fields.get("text", {}).get("stringValue", "")
                html_body = fields.get("html", {}).get("stringValue", "")

                if not to_email:
                    continue

                _processed_queue_docs.add(doc_name)
                ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                print(f"[{ts}] [CLOUD-QUEUE] Discovered pending email in Firestore for: {to_email}")

                allowed, rate_msg, _ = check_rate_limit(to_email)
                if not allowed:
                    print(f"[{ts}] [RATE-LIMIT] Rate-limited for: {to_email} ({rate_msg})")
                    _processed_queue_docs.remove(doc_name)
                    continue

                success, detail = send_email_multi_transport(to_email, subject, text_body, html_body)

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
                    print(f"[{ts}] [WARN] Could not patch Firestore status: {patch_err}")

                if success:
                    print(f"[{ts}] [SUCCESS] [CLOUD-QUEUE] Delivered email to: {to_email} via {detail}")
                else:
                    print(f"[{ts}] [ERROR] [CLOUD-QUEUE] Failed delivering email to {to_email}: {detail}")

        except Exception:
            pass

        time.sleep(POLL_INTERVAL)


# ── Main ────────────────────────────────────────────────────────
def run():
    server_address = ("0.0.0.0", PORT)
    try:
        httpd = ReusableHTTPServer(server_address, SmtpBridgeHandler)
    except OSError as e:
        print(f"[!] Could not bind to port {PORT}: {e}")
        return

    consumer = threading.Thread(target=run_firestore_queue_consumer, daemon=True)
    consumer.start()

    print("=" * 60)
    print(f"  AIRAMP Email Relay & Cloud Queue (Brevo HTTPS Edition)")
    print(f"  HTTP:      http://0.0.0.0:{PORT}/send-email")
    print(f"  Transport: Brevo REST API (Port 443 HTTPS - Cloud Approved)")
    print(f"  Sender:    {BREVO_SENDER_EMAIL}")
    print(f"  Project:   {FIREBASE_PROJECT_ID}")
    print("=" * 60)

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down AIRAMP Email Relay...")
        httpd.server_close()


if __name__ == "__main__":
    run()
