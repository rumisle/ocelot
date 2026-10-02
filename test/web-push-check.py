# End-to-end check of the server side of Web Push (patch cli/web-push) against a dev server
# (scripts/dev-server.sh start). It plays the browser and the push service: subscribes with its own
# keys, points the subscription at a local fake push service, makes sessions do things, and checks
# what arrives. Payloads are decrypted with http_ece (the library behind pywebpush) and the VAPID
# token is verified with cryptography, so the server's own crypto is checked independently.
#
#   uv run --with http_ece,cryptography,requests python test/web-push-check.py

import base64, json, os, queue, threading, time
from http.server import BaseHTTPRequestHandler, HTTPServer

import http_ece, requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature

URL = os.environ.get("URL", "http://127.0.0.1:4852")
AUTH = ("opencode", os.environ.get("OPENCODE_SERVER_PASSWORD", "test"))
PUSH_PORT = 4861
MODEL = {"id": "claude-opus-5-5", "providerID": "anthropic"}
WORK = "/tmp/ocelot-dev/work"

b64 = lambda data: base64.urlsafe_b64encode(data).rstrip(b"=").decode()
unb64 = lambda text: base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))

key = ec.generate_private_key(ec.SECP256R1())
p256dh = key.public_key().public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
secret = os.urandom(16)

received: "queue.Queue[dict]" = queue.Queue()
status = {"code": 201}


class Push(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers["content-length"]))
        received.put({"path": self.path, "headers": {k.lower(): v for k, v in self.headers.items()}, "body": body})
        self.send_response(status["code"])
        self.end_headers()

    def log_message(self, *args):
        pass


server = HTTPServer(("127.0.0.1", PUSH_PORT), Push)
threading.Thread(target=server.serve_forever, daemon=True).start()
endpoint = f"http://127.0.0.1:{PUSH_PORT}/push/device-1"
failures = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + (f": {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def api(method, path, body=None):
    response = requests.request(method, URL + path, auth=AUTH, json=body, timeout=20)
    if response.status_code == 204:
        return None
    data = response.json()
    return data.get("data", data) if isinstance(data, dict) else data


def session(title, **extra):
    return api("POST", "/api/session", {"title": title, "model": MODEL, "location": {"directory": WORK}, **extra})["id"]


def prompt(sid, text):
    api("POST", f"/api/session/{sid}/prompt", {"text": text})


def next_push(timeout=20):
    try:
        return received.get(timeout=timeout)
    except queue.Empty:
        return None


def drain():
    while not received.empty():
        received.get()


def open_push(push, public_key):
    payload = json.loads(http_ece.decrypt(push["body"], private_key=key, auth_secret=secret, version="aes128gcm"))
    # VAPID: "vapid t=<jwt>, k=<server key>", ES256 over header.claims with that key.
    auth = push["headers"]["authorization"]
    token = auth.split("t=")[1].split(",")[0]
    k = auth.split("k=")[1].strip()
    head, claims, signature = token.split(".")
    raw = unb64(signature)
    der = encode_dss_signature(int.from_bytes(raw[:32], "big"), int.from_bytes(raw[32:], "big"))
    ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), unb64(k)).verify(
        der, f"{head}.{claims}".encode(), ec.ECDSA(hashes.SHA256())
    )
    claims = json.loads(unb64(claims))
    return payload, claims, k


public_key = api("GET", "/api/ocelot/push")["publicKey"]
check("public key is an uncompressed P-256 point", len(unb64(public_key)) == 65 and unb64(public_key)[0] == 4)

subscription = {"endpoint": endpoint, "keys": {"p256dh": b64(p256dh), "auth": b64(secret)}}
result = api("PUT", "/api/ocelot/push/subscription",
             {"subscription": subscription, "kinds": ["done", "permission", "error"], "href": "/server/X/session/"})
check("subscribe", result.get("subscribed") is True, result)

# 1. A finished top-level session pushes its reply.
drain()
sid = session("Fix the login bug")
prompt(sid, "ECHO Fixed the **null** check in `auth.ts` and added a test.")
push = next_push()
check("done: pushed", push is not None)
if push:
    payload, claims, k = open_push(push, public_key)
    check("done: VAPID key is the server's", k == public_key)
    check("done: VAPID audience is the push origin", claims["aud"] == f"http://127.0.0.1:{PUSH_PORT}", claims)
    check("done: VAPID expiry within 24h", 0 < claims["exp"] - time.time() <= 24 * 3600, claims)
    check("done: title is the session title", payload["title"] == "Fix the login bug", payload)
    check("done: body is the plain reply", payload["body"] == "Fixed the null check in auth.ts and added a test.", payload)
    check("done: tap opens the session", payload["url"] == "/server/X/session/" + sid, payload)
    headers = push["headers"]
    check("done: headers", headers.get("content-encoding") == "aes128gcm" and headers.get("ttl") == "86400"
          and headers.get("urgency") == "high" and headers.get("topic") == sid[-32:], headers)

# 2. A web app in use holds pushes back; leaving it lets them through.
drain()
api("POST", "/api/ocelot/push/presence", {"client": "page-1", "active": True})
sid2 = session("Quiet while in use")
prompt(sid2, "ECHO first")
check("in use: nothing pushed", next_push(timeout=8) is None)
api("POST", "/api/ocelot/push/presence", {"client": "page-1", "active": False})
prompt(sid2, "ECHO second")
push = next_push()
check("left: pushed again", push is not None and open_push(push, public_key)[0]["body"] == "second")

# 3. A child session finishing is not pushed.
drain()
child = session("child", parentID=sid)
prompt(child, "ECHO from the child")
check("child: nothing pushed", next_push(timeout=8) is None)

# 4. A permission request is pushed, under its session.
drain()
sid3 = session("Clean up", permissions=[{"action": "shell", "resource": "*", "effect": "ask"}])
prompt(sid3, "SHELL rm -rf build")
push = next_push()
if push:
    payload = open_push(push, public_key)[0]
    check("permission: pushed", payload["body"].startswith("Needs permission · ") and "rm -rf build" in payload["body"], payload)
    check("permission: title", payload["title"] == "Clean up", payload)
else:
    check("permission: pushed", False)

# 5. A question is pushed as the question itself.
drain()
sid4 = session("Pick a database")
prompt(sid4, "QUESTION Use Postgres instead of SQLite?")
push = next_push()
payload = open_push(push, public_key)[0] if push else {}
check("question: pushed", payload.get("body") == "Use Postgres instead of SQLite?", payload)

# 6. The test button.
drain()
result = api("POST", "/api/ocelot/push/test", {"endpoint": endpoint})
push = next_push(timeout=5)
check("test: pushed", push is not None and open_push(push, public_key)[0]["body"] == "Test notification")
check("test: delivery recorded", isinstance(result.get("delivered"), (int, float)), result)

# 7. A failing push service is reported; a gone subscription is forgotten.
status["code"] = 500
result = api("POST", "/api/ocelot/push/test", {"endpoint": endpoint})
check("500: failure recorded", (result.get("failed") or "").startswith("500"), result)
status["code"] = 410
result = api("POST", "/api/ocelot/push/test", {"endpoint": endpoint})
check("410: subscription forgotten", result.get("subscribed") is False, result)

# 8. Bad input and missing auth.
check("bad body: 400", requests.put(URL + "/api/ocelot/push/subscription", auth=AUTH, json={"x": 1}).status_code == 400)
check("no auth: 401", requests.get(URL + "/api/ocelot/push").status_code == 401)

server.shutdown()
print("\n" + ("all passed" if not failures else f"{len(failures)} failed: {', '.join(failures)}"))
raise SystemExit(1 if failures else 0)
