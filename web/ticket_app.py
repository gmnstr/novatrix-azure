#!/usr/bin/env python3
"""Novatrix AB support ticket app — guest VM code (NOT repo automation).

This file runs ON the Azure VM (installed by web/cloud-init.yaml), not in the
repo toolchain. The vault "no Python scripts" rule applies to repository
automation; this is the course application itself.

Behaviour:
  GET  /        -> serves the ticket form (web/index.html)
  POST /ticket  -> validates the submission and writes a JSON ticket to
                   /var/lib/novatrix/tickets/<id>.json

If the optional azure-identity and azure-storage-blob packages are installed
and the VM's managed identity works, the ticket is ALSO uploaded to the
`tickets` blob container. Blob upload is best-effort: the app fails closed to
local disk, so a ticket is never lost because Azure is unreachable.

Runs on 127.0.0.1:8080 behind the nginx reverse proxy (port 80).
"""

import json
import os
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse
from urllib.request import Request, urlopen

TICKET_DIR = os.environ.get("NOVATRIX_TICKET_DIR", "/var/lib/novatrix/tickets")
FORM_PATH = os.environ.get("NOVATRIX_FORM_PATH", "/var/www/novatrix/index.html")
STORAGE_ACCOUNT = os.environ.get("NOVATRIX_STORAGE_ACCOUNT", "")
BLOB_CONTAINER = os.environ.get("NOVATRIX_BLOB_CONTAINER", "tickets")
FLOW_URL = os.environ.get("NOVATRIX_FLOW_URL", "").strip()
HOST = os.environ.get("NOVATRIX_LISTEN_HOST", "127.0.0.1")
PORT = int(os.environ.get("NOVATRIX_LISTEN_PORT", "8080"))

FALLBACK_FORM = """<!DOCTYPE html>
<html lang="sv"><head><meta charset="utf-8"><title>Novatrix AB — Supportärende</title></head>
<body><h1>Novatrix AB — Supportärende</h1>
<form method="post" action="/ticket">
  <label>Namn <input type="text" name="name" required></label><br>
  <label>E-post <input type="email" name="email" required></label><br>
  <label>Kategori <input type="text" name="category" required></label><br>
  <label>Beskrivning <textarea name="description" required></textarea></label><br>
  <label>Fil (valfritt) <input type="text" name="file_note"></label><br>
  <button type="submit">Skicka ärende</button>
</form></body></html>
"""


def upload_to_blob(ticket):
    """Best-effort upload. Raises on any failure; caller keeps the local copy."""
    if not STORAGE_ACCOUNT:
        raise RuntimeError("NOVATRIX_STORAGE_ACCOUNT is empty")
    from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
    from azure.storage.blob import BlobServiceClient

    client_id = os.environ.get("AZURE_CLIENT_ID", "").strip()
    credential = (
        ManagedIdentityCredential(client_id=client_id)
        if client_id
        else DefaultAzureCredential()
    )
    account_url = f"https://{STORAGE_ACCOUNT}.blob.core.windows.net"
    client = BlobServiceClient(account_url, credential=credential)
    blob_name = f"{ticket['id']}.json"
    client.get_container_client(BLOB_CONTAINER).upload_blob(
        blob_name, json.dumps(ticket, ensure_ascii=False), overwrite=False
    )


def notify_flow(ticket):
    """Best-effort POST to Power Automate HTTP trigger. No-op if unset."""
    if not FLOW_URL:
        return
    payload = json.dumps(ticket, ensure_ascii=False).encode("utf-8")
    req = Request(
        FLOW_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urlopen(req, timeout=10) as resp:
        resp.read()


class TicketHandler(BaseHTTPRequestHandler):
    server_version = "NovatrixTicket/1.0"

    def do_GET(self):
        if urlparse(self.path).path in ("/", "/index.html"):
            self._send_form()
        else:
            self.send_error(404)

    def do_POST(self):
        if urlparse(self.path).path != "/ticket":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", 0) or 0)
            body = self.rfile.read(length).decode("utf-8", "replace")
            ticket = self._parse_ticket(body)
            self._save_ticket(ticket)
            self._json(201, {"ok": True, "id": ticket["id"]})
        except ValueError as exc:
            self.log_error("ticket rejected: %s", exc)
            self._json(400, {"ok": False, "error": str(exc)})
        except Exception as exc:  # noqa: BLE001 — guest app must keep serving
            self.log_error("ticket failed: %s", exc)
            self._json(500, {"ok": False, "error": "internal error"})

    def _parse_ticket(self, body):
        if not body:
            raise ValueError("empty body")
        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            data = {k: v[0] for k, v in parse_qs(body).items()}
        required = ("name", "email", "category", "description")
        missing = [k for k in required if not str(data.get(k, "")).strip()]
        if missing:
            raise ValueError("missing fields: " + ", ".join(missing))
        return {
            "id": uuid.uuid4().hex,
            "received_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "name": str(data.get("name", "")).strip(),
            "email": str(data.get("email", "")).strip(),
            "category": str(data.get("category", "")).strip(),
            "description": str(data.get("description", "")).strip(),
            "file_note": str(data.get("file_note", "")).strip(),
        }

    def _save_ticket(self, ticket):
        os.makedirs(TICKET_DIR, exist_ok=True)
        path = os.path.join(TICKET_DIR, f"{ticket['id']}.json")
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(ticket, fh, ensure_ascii=False, indent=2)
        try:
            upload_to_blob(ticket)
        except Exception as exc:  # noqa: BLE001 — fail closed to local disk
            self.log_error("blob upload skipped/failed (local copy kept): %s", exc)
        try:
            notify_flow(ticket)
        except Exception as exc:  # noqa: BLE001 — flow is optional
            self.log_error("flow notify skipped/failed (local copy kept): %s", exc)

    def _send_form(self):
        try:
            with open(FORM_PATH, encoding="utf-8") as fh:
                html = fh.read()
        except OSError:
            html = FALLBACK_FORM
        payload = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _json(self, code, payload):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main():
    os.makedirs(TICKET_DIR, exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), TicketHandler)
    print(f"Novatrix ticket app listening on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()