#!/usr/bin/env python3
"""
AIRA Local SMTP Bridge Daemon
Receives HTTP POST requests from Flutter Web / Mobile and sends emails
directly through Gmail SMTP using SSL/TLS.
"""

import sys
import json
import smtplib
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime

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
DEFAULT_PASSWORD = os.environ.get("SMTP_APP_PASSWORD", "")
SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", 587))

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
            "service": "AIRA Local SMTP Bridge",
            "sender": DEFAULT_SENDER,
            "timestamp": datetime.now().isoformat()
        }
        self.wfile.write(json.dumps(response).encode("utf-8"))

    def do_POST(self):
        if self.path not in ["/send-email", "/send", "/api/send-email"]:
            self.send_response(404)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Endpoint not found"}).encode("utf-8"))
            return

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
        sender_password = (payload.get("password") or DEFAULT_PASSWORD).replace(" ", "")

        if not to_email:
            self.send_response(400)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Missing 'to' recipient email"}).encode("utf-8"))
            return

        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] Incoming email dispatch request to: {to_email}")
        print(f"[{timestamp}] Subject: {subject}")

        # Construct MIME Message
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"AIRA Platform <{sender_email}>"
        msg["To"] = to_email

        if text_body:
            msg.attach(MIMEText(text_body, "plain", "utf-8"))
        if html_body:
            msg.attach(MIMEText(html_body, "html", "utf-8"))
        elif not text_body:
            msg.attach(MIMEText("No content provided", "plain", "utf-8"))

        # Send via Gmail SMTP
        try:
            with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=15) as server:
                server.ehlo()
                server.starttls()
                server.ehlo()
                server.login(sender_email, sender_password)
                server.send_message(msg)

            print(f"[{timestamp}] [SUCCESS] Successfully delivered email via Gmail SMTP to: {to_email}")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {
                "success": True,
                "message": f"Credentials email delivered to {to_email} via Gmail SMTP",
                "to": to_email,
                "timestamp": timestamp
            }
            self.wfile.write(json.dumps(response).encode("utf-8"))

        except Exception as err:
            print(f"[{timestamp}] [ERROR] Failed to send email via SMTP: {err}")
            self.send_response(500)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {
                "success": False,
                "error": str(err),
                "timestamp": timestamp
            }
            self.wfile.write(json.dumps(response).encode("utf-8"))

    def log_message(self, format, *args):
        # Suppress noisy default console access logs
        pass

def run():
    server_address = ("0.0.0.0", PORT)
    httpd = HTTPServer(server_address, SmtpBridgeHandler)
    print(f"==================================================")
    print(f" AIRA SMTP Bridge Server Running on port {PORT}")
    print(f" Ready to receive emails from Flutter Web/Mobile")
    print(f" Sender: {DEFAULT_SENDER}")
    print(f" Local URL: http://127.0.0.1:{PORT}/send-email")
    print(f"==================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down AIRA SMTP Bridge...")
        httpd.server_close()

if __name__ == "__main__":
    run()
