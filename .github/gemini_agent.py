#!/usr/bin/env python3
import json
import os
import pathlib
import urllib.request
import urllib.error

ROOT = pathlib.Path(".").resolve()
API_KEY = os.environ["GEMINI_API_KEY"]
TASK = os.environ["VEYRA_TASK"].strip()
SCOPE = [x.strip().strip("/") for x in os.environ.get("VEYRA_SCOPE", "scripts,scenes,tests").split(",") if x.strip()]
MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.8-flash")

ALLOWED_ROOTS = ("scripts/", "scenes/", "tests/", ".github/")
BLOCKED = (".godot/", ".git/", "build/", ".env", "project.godot")

def allowed(path: str) -> bool:
    p = path.replace("\\", "/").lstrip("/")
    return p.startswith(ALLOWED_ROOTS) and not any(p == b or p.startswith(b) for b in BLOCKED)

def collect_files():
    files = []
    for base in SCOPE:
        base_path = ROOT / base
        if not base_path.exists():
            continue
        for p in base_path.rglob("*"):
            if not p.is_file():
                continue
            rel = p.relative_to(ROOT).as_posix()
            if not allowed(rel):
                continue
            if p.suffix.lower() not in {".gd", ".tscn", ".tres", ".cfg", ".yml", ".yaml", ".md"}:
                continue
            try:
                data = p.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            files.append((rel, data))
    files.sort()
    # Keep enough context for architecture while preventing accidental prompt overflow.
    budget = 180000
    out = []
    used = 0
    for rel, data in files:
        block = f"\n===== {rel} =====\n{data}\n"
        if used + len(block) > budget:
            continue
        out.append(block)
        used += len(block)
    return "".join(out)

context = collect_files()

system = """You are the backend engineering agent for the Veyra Godot 4.7.2 mobile game.
You are assisting a lead developer. Be conservative, architecture-aware, performance-conscious, and repository-grounded.
The game targets Android/mobile devices around 4 GB RAM using the Compatibility renderer.
Prefer deterministic, simple Godot systems, reusable components, low draw calls, bounded simulation, and data-driven catalogs.
Never invent APIs or files you cannot justify from the supplied repository.
Do not rewrite unrelated systems.
Do not modify project.godot, credentials, CI secrets, or files outside the allowed paths.
For water/streams/lakes, prioritize a performant representation: shared materials/meshes, bounded simulation, deterministic generation, cheap collision, and no per-frame work for distant water.
Animals/workers and future multiplayer must remain compatible with authoritative state and save/load.
Every change must be implementable as plain repository files.
Return ONLY valid JSON matching the requested schema."""

prompt = f"""Task:
{TASK}

Priority scope:
{", ".join(SCOPE)}

Repository context:
{context}

Produce the smallest complete implementation that materially advances the task.
If code is needed, provide full file contents for changed/new files, not snippets.
Include tests for important contracts.
Do not change unrelated behavior.
Use this JSON shape exactly:
{{
  "summary": "short description",
  "files": [
    {{"path": "scripts/example.gd", "operation": "update", "content": "FULL FILE CONTENT"}},
    {{"path": "tests/example_test.gd", "operation": "create", "content": "FULL FILE CONTENT"}}
  ]
}}
"""

url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
payload = {
    "system_instruction": {"parts": [{"text": system}]},
    "contents": [{"role": "user", "parts": [{"text": prompt}]}],
    "generationConfig": {"temperature": 0.15, "responseMimeType": "application/json"}
}
req = urllib.request.Request(
    url,
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=240) as resp:
        raw = json.load(resp)
except urllib.error.HTTPError as e:
    raise SystemExit(f"Gemini API HTTP {e.code}: {e.read().decode('utf-8', 'replace')}")

text = raw["candidates"][0]["content"]["parts"][0]["text"]
try:
    result = json.loads(text)
except json.JSONDecodeError as e:
    raise SystemExit(f"Gemini returned invalid JSON: {e}")

if not isinstance(result.get("files"), list):
    raise SystemExit("Gemini response has no files array.")

report = {"task": TASK, "model": MODEL, "summary": result.get("summary", ""), "files": []}

for item in result["files"]:
    path = str(item.get("path", "")).replace("\\", "/").lstrip("/")
    operation = item.get("operation")
    content = item.get("content")
    if not path or operation not in {"create", "update"} or not isinstance(content, str):
        raise SystemExit(f"Invalid Gemini file operation: {item}")
    if not allowed(path):
        raise SystemExit(f"Gemini attempted forbidden path: {path}")
    target = ROOT / path
    if operation == "create" and target.exists():
        raise SystemExit(f"Gemini marked existing file as create: {path}")
    if operation == "update" and not target.exists():
        raise SystemExit(f"Gemini marked missing file as update: {path}")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
    report["files"].append({"path": path, "operation": operation})

pathlib.Path("gemini_agent_output.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
