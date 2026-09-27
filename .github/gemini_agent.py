#!/usr/bin/env python3
import json
import os
import pathlib
import re
import urllib.request
import urllib.error
import time

ROOT = pathlib.Path(".").resolve()
API_KEY = os.environ["GEMINI_API_KEY"]
TASK = os.environ["VEYRA_TASK"].strip()
SCOPE = [x.strip().strip("/") for x in os.environ.get("VEYRA_SCOPE", "scripts,scenes,tests").split(",") if x.strip()]
MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.8-flash")
FALLBACK_MODELS = [x.strip() for x in os.environ.get("GEMINI_FALLBACK_MODELS", "gemini-3.7-flash").split(",") if x.strip()]

ALLOWED_ROOTS = ("scripts/", "scenes/", "tests/", "docs/")
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

def extract_dependencies(rel: str, data: str):
    """Return local repository files referenced by common Godot/GDScript path forms."""
    refs = set()
    patterns = [
        r"""(?:"|')((?:res://)?(?:scripts|scenes|tests)/[^"']+)""",
        r"""preload\\(["']([^"']+)["']\\)""",
        r"""load\\(["']([^"']+)["']\\)""",
    ]
    for pattern in patterns:
        for raw in re.findall(pattern, data):
            ref = raw
            if ref.startswith("res://"):
                ref = ref[6:]
            ref = ref.replace("\\\\", "/")
            if allowed(ref):
                refs.add(ref)
    return refs

def collect_files():
    terms = task_terms()
    candidates = {}
    all_files = {}

    # Read the compact architecture memory first.
    if CONTEXT_FILE.exists():
        data = read_text(CONTEXT_FILE)
        if data:
            candidates["docs/AI_ARCHITECTURE_CONTEXT.md"] = ("docs/AI_ARCHITECTURE_CONTEXT.md", data, 1000)

    # Index source files once. This enables dependency expansion without loading everything into the prompt.
    for base in ("scripts", "scenes", "tests", ".github", "docs"):
        base_path = ROOT / base
        if not base_path.exists():
            continue
        for p in base_path.rglob("*"):
            if not p.is_file():
                continue
            rel = p.relative_to(ROOT).as_posix()
            if not allowed(rel) or p.suffix.lower() not in TEXT_SUFFIXES:
                continue
            data = read_text(p)
            if data is not None:
                all_files[rel] = data

    # Explicit scope remains the first relevance source.
    for rel, data in all_files.items():
        in_scope = any(rel == base or rel.startswith(base + "/") for base in SCOPE)
        if in_scope:
            candidates[rel] = (rel, data, score_file(rel, data, terms))

    # Task-relevant files outside the requested scope are included when strongly related.
    for rel, data in all_files.items():
        if rel in candidates:
            continue
        score = score_file(rel, data, terms)
        if score >= 10:
            candidates[rel] = (rel, data, score)

    # Expand one hop through local Godot dependencies from already-selected files.
    # This catches contracts such as a water system referencing terrain/world generators
    # even when the task words do not explicitly name those files.
    queue = list(candidates.keys())
    visited = set(queue)
    while queue:
        rel = queue.pop(0)
        data = all_files.get(rel)
        if data is None:
            continue
        for dep in extract_dependencies(rel, data):
            if dep in visited or dep not in all_files:
                continue
            visited.add(dep)
            score = max(score_file(dep, all_files[dep], terms), 14)
            candidates[dep] = (dep, all_files[dep], score)
            queue.append(dep)

    ranked = sorted(candidates.values(), key=lambda x: (-x[2], x[0]))

    # Hard context budget. The compact architecture memory is protected.
    budget = 115000
    used = 0
    out = []
    max_files = 70
    for rel, data, _score in ranked:
        block = f"\\n===== {rel} =====\\n{data}\\n"
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

The context loader supplied {file_count} relevant files using {context_chars} characters of repository context, including one-hop local dependency expansion.

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


RETRYABLE_HTTP_CODES = {429, 500, 502, 503, 504}

def post_gemini(url, payload, label, attempts=5):
    """Call Gemini with bounded retry/backoff for transient service/rate-limit failures."""
    body = json.dumps(payload).encode("utf-8")
    last_error = None
    for attempt in range(1, attempts + 1):
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:
            details = e.read().decode("utf-8", "replace")
            last_error = f"Gemini {label} API HTTP {e.code}: {details}"
            if e.code not in RETRYABLE_HTTP_CODES or attempt >= attempts:
                raise RuntimeError(last_error)
            delay = min(30, 2 ** (attempt - 1))
            print(f"Gemini {label} transient HTTP {e.code}; retry {attempt + 1}/{attempts} in {delay}s", flush=True)
            time.sleep(delay)
        except (urllib.error.URLError, TimeoutError) as e:
            last_error = f"Gemini {label} request failed: {e}"
            if attempt >= attempts:
                raise RuntimeError(last_error)
            delay = min(30, 2 ** (attempt - 1))
            print(f"Gemini {label} transient request error; retry {attempt + 1}/{attempts} in {delay}s", flush=True)
            time.sleep(delay)
    raise RuntimeError(last_error or f"Gemini {label} request failed")

def call_with_fallback(model, payload, label):
    models = [model] + [m for m in FALLBACK_MODELS if m != model]
    last_error = None
    for index, candidate in enumerate(models):
        endpoint = "https://generativelanguage.googleapis.com/v1beta/models/" + candidate + ":generateContent?key=" + API_KEY
        try:
            print("Gemini " + label + ": trying " + candidate, flush=True)
            return candidate, post_gemini(endpoint, payload, label)
        except RuntimeError as e:
            last_error = str(e)
            if index + 1 < len(models):
                print("Gemini " + label + ": " + candidate + " unavailable; falling back to " + models[index + 1], flush=True)
    raise SystemExit(last_error or f"Gemini {label} failed")

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
implementation_model, raw = call_with_fallback(MODEL, payload, "implementation")

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
    "model": implementation_model,
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


# Independent self-review gate: review only the generated diff plus bounded relevant context.
import subprocess

def git_diff():
    proc = subprocess.run(
        ["git", "diff", "--", "scripts/", "scenes/", "tests/", ".github/", "docs/"],
        capture_output=True, text=True, check=False,
    )
    if proc.returncode != 0:
        raise SystemExit(f"git diff failed: {proc.stderr}")
    return proc.stdout

def review_generated_changes(diff_text):
    review_model = os.environ.get("GEMINI_REVIEW_MODEL", MODEL)
    changed_blocks = []
    used = 0
    for item in report["files"]:
        path = item["path"]
        data = read_text(ROOT / path)
        if data is None:
            continue
        block = f"\n===== CHANGED FILE: {path} =====\n{data}\n"
        if used + len(block) > 90000:
            continue
        changed_blocks.append(block)
        used += len(block)

    architecture = read_text(CONTEXT_FILE) if CONTEXT_FILE.exists() else ""
    review_prompt = f"""Review this generated Veyra change as an independent senior Godot engineer.

TASK:
{TASK}

ARCHITECTURE CONTEXT:
{architecture}

GENERATED DIFF:
{diff_text}

CHANGED FILE CONTENT:
{"".join(changed_blocks)}

Check for:
- duplicate authorities, catalogs, managers, or state
- save/load contract changes or unsanitized persisted data
- changed/broken resource IDs
- interaction authority or eligibility bypasses
- future multiplayer authority violations
- unbounded per-frame/distant simulation
- excessive nodes, materials, physics bodies, allocations, or expensive mobile work
- unrelated file modifications
- missing/weak regression coverage
- likely Godot 4.7.2 parser/runtime/API errors
- invented APIs or contracts unsupported by the supplied repository
- changes that look complete but do not materially implement the task

Return ONLY JSON:
{{
  "approved": true,
  "risk_level": "low|medium|high|critical",
  "findings": [{{"severity":"info|warning|error|critical","path":"path","issue":"specific finding"}}],
  "required_changes": ["specific change required before PR"],
  "summary": "short audit summary"
}}
Set approved=false for any error/critical finding or required architectural correction."""

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{review_model}:generateContent?key={API_KEY}"
    payload = {
        "system_instruction": {"parts": [{"text": "You are Veyra's independent code-review gate. Do not rewrite code. Judge only supplied evidence. Do not invent repository facts. Approval is not a device-test claim."}]},
        "contents": [{"role": "user", "parts": [{"text": review_prompt}]}],
        "generationConfig": {"temperature": 0.0, "responseMimeType": "application/json", "maxOutputTokens": 16000},
    }
    review_model_used, raw = call_with_fallback(review_model, payload, "review")
    try:
        text = raw["candidates"][0]["content"]["parts"][0]["text"]
        review = json.loads(text)
    except (KeyError, IndexError, TypeError, json.JSONDecodeError) as e:
        raise SystemExit(f"Gemini reviewer returned unusable JSON: {e}")
    if not isinstance(review.get("approved"), bool):
        raise SystemExit("Gemini reviewer did not return a boolean approved field.")
    return review_model_used, review

diff_text = git_diff()
review_model, review = review_generated_changes(diff_text)
report["review"] = {
    "model": review_model,
    "approved": review["approved"],
    "risk_level": review.get("risk_level", "unknown"),
    "findings": review.get("findings", []),
    "required_changes": review.get("required_changes", []),
    "summary": review.get("summary", ""),
}
pathlib.Path("gemini_agent_output.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
if not review["approved"]:
    raise SystemExit("Gemini self-review rejected the generated change; no PR will be created.")
