import json, os, subprocess, sys, datetime
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
def iso(ts):
    try:
        return datetime.datetime.fromisoformat(str(ts).replace("Z", "+00:00")).timestamp()
    except Exception:
        return None
def tail(path, n):
    with open(path, "rb") as f:
        size = os.path.getsize(path); f.seek(max(0, size - n)); return f.read().decode("utf-8", "ignore")
root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
if not root:
    print(""); sys.exit(0)
log = os.path.join(root, ".rolepod", "evidence", "phase-log.jsonl")
route_ts = None
if os.path.isfile(log):
    for line in tail(log, 262144).splitlines():
        if "\"phase\":\"route\"" not in line and "\"phase\": \"route\"" not in line: continue
        try: t = iso(json.loads(line).get("ts", ""))
        except Exception: t = None
        if t and (route_ts is None or t > route_ts): route_ts = t
if route_ts is None:
    print("stale"); sys.exit(0)
now = datetime.datetime.now(datetime.timezone.utc).timestamp()
last_user = None
tp = d.get("transcript_path") or ""
if tp and os.path.isfile(tp):
    for line in tail(tp, 2097152).splitlines():
        if "\"type\":\"user\"" not in line and "\"type\": \"user\"" not in line: continue
        try: e = json.loads(line)
        except Exception: continue
        c = (e.get("message") or {}).get("content")
        if isinstance(c, list):
            if not any(isinstance(b, dict) and b.get("type") == "text" and not str(b.get("text", "")).startswith("<") for b in c): continue
        elif isinstance(c, str):
            if c.startswith("<"): continue
        else:
            continue
        t = iso(e.get("timestamp", "") or "")
        if t and now - t > 5: last_user = t
if last_user is not None:
    print("" if route_ts > last_user else "stale")
else:
    print("" if now - route_ts < 1800 else "stale")
