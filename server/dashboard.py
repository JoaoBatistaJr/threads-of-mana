#!/usr/bin/env python3
"""Painel do servidor Threads of Mana (só biblioteca padrão).
  python3 dashboard.py            sobe o painel (porta 8787)
  python3 dashboard.py --status   imprime o estado real e sai
"""
import http.server
import json
import os
import re
import secrets
import socketserver
import subprocess
import sys

PORT = int(os.environ.get("DASH_PORT", "8787"))
TOKEN_FILE = os.environ.get("DASH_TOKEN_FILE", "/etc/threads/dashboard.token")
REPO = "/opt/threads/repo"
UNIT = "threads-server"
LOG_CMD = os.environ.get("DASH_LOG_CMD", f"journalctl -u {UNIT} -f -n 300 -o short-iso --no-pager")
FATAL = re.compile(r"Failed to load script|Compile Error|Failed to compile")
TOTAL = re.compile(r"\(total (\d+)\)")
HERE = os.path.dirname(os.path.abspath(__file__))


def sh(cmd, timeout=60):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return (r.stdout + r.stderr).strip()
    except Exception as e:  # noqa: BLE001
        return f"erro: {e}"


def status():
    active = sh(f"systemctl is-active {UNIT}")
    tunnel = sh("systemctl is-active playit")
    inv = sh(f"systemctl show {UNIT} -p InvocationID --value")
    since = sh(f"systemctl show {UNIT} -p ActiveEnterTimestamp --value")
    log = sh(f"journalctl _SYSTEMD_INVOCATION_ID={inv} --no-pager -o cat") if inv and not inv.startswith("erro") else ""
    if active != "active":
        state = "parado"
    elif FATAL.search(log):
        state = "erro"
    elif "[server] ouvindo" in log:
        state = "online"
    else:
        state = "iniciando"
    totals = TOTAL.findall(log)
    players = int(totals[-1]) if totals else 0
    errors = sum(1 for ln in log.splitlines() if "SCRIPT ERROR" in ln or "ERROR:" in ln)
    commit = sh(f"git -C {REPO} -c safe.directory={REPO} log -1 --format='%h %s'")
    return {"state": state, "service": active, "tunnel": tunnel, "players": players,
            "errors": errors, "since": since, "commit": commit}


def read_token():
    try:
        return open(TOKEN_FILE).read().strip()
    except OSError:
        return ""


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _ok(self, token):
        t = self.headers.get("X-Token") or self.path.partition("t=")[2].split("&")[0]
        return bool(token) and secrets.compare_digest(t, token)

    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype + "; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/":
            return self._send(200, open(os.path.join(HERE, "dashboard.html"), "rb").read(), "text/html")
        token = read_token()
        if not self._ok(token):
            return self._send(401, '{"error":"token"}')
        if path == "/api/status":
            return self._send(200, json.dumps(status()))
        if path == "/api/stream":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            p = subprocess.Popen(LOG_CMD, shell=True, stdout=subprocess.PIPE, text=True, errors="replace")
            try:
                for line in p.stdout:
                    line = re.sub(r"^(\S+) \S+ \S+?: ", r"\1 ", line.rstrip("\n"))
                    self.wfile.write(("data: " + line + "\n\n").encode())
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
            finally:
                p.kill()
            return None
        self._send(404, "{}")

    def do_POST(self):
        if not self._ok(read_token()):
            return self._send(401, '{"error":"token"}')
        path = self.path.split("?")[0]
        if path == "/api/restart":
            out = sh(f"systemctl restart {UNIT}")
            return self._send(200, json.dumps({"out": out or "servidor reiniciado"}))
        if path == "/api/update":
            out = sh(f"bash {REPO}/server/update.sh", timeout=300)
            # o painel também pode ter mudado: reinicia depois de responder
            subprocess.Popen("sleep 2; systemctl restart threads-dashboard", shell=True, start_new_session=True)
            return self._send(200, json.dumps({"out": out[-1500:]}))
        self._send(404, "{}")


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    if "--status" in sys.argv:
        s = status()
        print(f"{s['state']}|{s['players']}|{s['tunnel']}|{s['errors']}|{s['commit']}")
        sys.exit(0)
    print(f"painel em http://0.0.0.0:{PORT}", flush=True)
    Server(("0.0.0.0", PORT), Handler).serve_forever()
