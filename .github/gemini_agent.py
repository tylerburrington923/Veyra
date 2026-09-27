#!/usr/bin/env python3
import json
import os
import pathlib
import re
import urllib.request
import urllib.error

ROOT = pathlib.Path(".").resolve()
API_KEY = os.environ["GEMINI_API_KEY"]
TASK = os.environ["VEYRA_TASK"].strip()
SCOPE = [x.strip().strip("/") for x in os.environ.get("VEYRA_SCOPE", "scripts,scenes,tests").split(",") if x.strip()]
MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.8-flash")

ALLOWED_ROOTS = ("scripts/", "scenes/", "tests/", ".github/", "docs/")
BLOCKED = (".godot/", ".git/", "build/", ".env", "project.godot")
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".cfg", ".yml", ".yaml", ".md"}
CONTEXT_FILE = ROOT / "docs/AI_ARCHITECTURE_CONTEXT.md"

def allowed(path: str) -> bool:
    p = path.replace("\\", "/").lstrip("/")
    return p.startswith(ALLOWED_ROOTS) and not any(p == b or p.startswith(b) for b in BLOCKED)

def read_text(path: pathlib.Path):
    try:
        return path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return None

def task_terms():
    words = re.findall(r"[a-zA-Z0-9_]+", TASK.lower())
    stop = {"the", "and", "for", "with", "from", "into", "this", "that", "implement", "add", "make", "fix", "system"}
    return {w for w in words if len(w) >= 3 and w not in stop}

def score_file(rel: str, data: str, terms):
    low = rel.lower()
    score = 0
    for term in terms:
        if term in low:
            score += 12
        # A few hundred characters of identifiers/names are enough for relevance scoring.
        if term in data[:12000].lower():
            score += 2
    if rel.startswith("tests/"):
        score += 4
    if rel.endswith("catalog.gd"):
        score += 3
    return score

def collect_files():
    terms = task_terms()
    candidates = []
    seen = set()

    # Compact architecture memory is always included.
    if CONTEXT_FILE.exists():
        data = read_text(CONTEXT_FILE)
        if data:
            candidates.append(("docs/AI_ARCHITECTURE_CONTEXT.md", data, 1000))

    # Prefer explicitly requested scope, but rank files inside that scope by relevance.
    for base in SCOPE:
        base_path = ROOT / base
        if not base_path.exists():
            continue
        for p in base_path.rglob("*"):
            if not p.is_file():
                continue
            rel = p.relative_to(ROOT).as_posix()
            if rel in seen or not allowed(rel) or p.suffix.lower() not in TEXT_SUFFIXES:
                continue
            data = read_text(p)
            if data is None:
                continue
            seen.add(rel)
            candidates.append((rel, data, score_file(rel, data, terms)))

    # Relevant architecture/test files outside a narrow task scope get a small bonus.
    # This prevents a scope like "scripts/water*" from hiding the terrain contract.
    for base in ("scripts", "tests"):
        base_path = ROOT / base
        if not base_path.exists():
            continue
        for p in base_path.rglob("*"):
            if not p.is_file():
                continue
            rel = p.relative_to(ROOT).as_posix()
            if rel in seen or not allowed(rel) or p.suffix.lower() not in TEXT_SUFFIXES:
                continue
            data = read_text(p)
            if data is None:
                continue
            score = score_file(rel, data, terms)
            if score >= 10:
                candidates.append((rel, data, score))
                seen.add(rel)

    candidates.sort(key=lambda x: (-x[2], x[0]))

    # Hard context budget. The lead agent's compact context is protected.
    budget = 115000
    used = 0
    out = []
    max_files = 70
    for rel, data, _score in candidates:
        block = f"\n===== {rel} =====\n{data}\n"
        if used + len(block) > budget:
            continue
        out.append(block)
        used += len(block)
        if len(out) >= max_files:
            break
    return "".join(out), len(out), used

context, file_count, context_chars = collect_files()

system = """You are the secondary backend engineering agent for the Veyra Godot 4.7.2 mobile game.
A lead developer owns architecture, integration, final review, and merge decisions.
The supplied architecture context is compact memory, not permission to invent code. The checked-out repository is authoritative.

Rules:
- Android/mobile-first, Compatibility renderer, roughly 4 GB RAM target.
- Be conservative, deterministic, bounded, data-driven, and performance-conscious.
- Reuse existing catalogs, managers, interaction, save/load, and simulation authorities. Do not create parallel authorities.
- Never modify project.godot, credentials, secrets, or unrelated systems.
- Preserve existing resource IDs, save contracts, interaction authority, and future multiplayer boundaries.
- Avoid per-frame work for distant/static content, unnecessary nodes/materials/physics bodies, and giant manager scripts.
- For water/streams/lakes, prefer deterministic terrain-integrated features, shared materials/meshes, cheap collision, bounded simulation, and explicit interfaces for future ecology.
- For wildlife/workers, separate simulation state from presentation and keep simulation bounded.
- Do not claim that code is device-correct; CI validation and human device testing are separate.
- If supplied context is insufficient, make the smallest safe change or report that more repository context is required rather than inventing APIs.
- Return ONLY valid JSON matching the requested schema."""

prompt = f"""Engineering task:
{TASK}

Requested priority scope:
{", ".join(SCOPE)}

The context loader supplied {file_count} relevant files using {context_chars} characters of repository context.

Repository context:
{context}

Before writing code, reason about:
1. Which existing authority owns the state.
2. Which existing interfaces should be reused.
3. What the smallest safe change is.
4. What regression tests prove the important contract.
5. What should explicitly NOT be changed.

Then produce the smallest complete implementation that materially advances the task.
For changed files, return full file contents, not snippets.
Do not rewrite files merely to reformat them.
Do not create duplicate systems to work around an existing one.

JSON shape:
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
    "generationConfig": {
        "temperature": 0.1,
        "responseMimeType": "application/json",
        "maxOutputTokens": 50000
    }
}
req = urllib.request.Request(
    url,
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=300) as resp:
        raw = json.load(resp)
except urllib.error.HTTPError as e:
    raise SystemExit(f"Gemini API HTTP {e.code}: {e.read().decode('utf-8', 'replace')}")

try:
    text = raw["candidates"][0]["content"]["parts"][0]["text"]
except (KeyError, IndexError, TypeError) as e:
    raise SystemExit(f"Gemini response contained no usable candidate: {e}")

try:
    result = json.loads(text)
except json.JSONDecodeError as e:
    raise SystemExit(f"Gemini returned invalid JSON: {e}")

if not isinstance(result.get("files"), list):
    raise SystemExit("Gemini response has no files array.")

report = {
    "task": TASK,
    "model": MODEL,
    "context_files": file_count,
    "context_chars": context_chars,
    "summary": result.get("summary", ""),
    "files": []
}

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
