# commit-guard

A local, offline, rule-based security scanner for git repos. No network calls,
no external services — everything runs on your machine with plain Python + regex.

Two modes:

| Mode | When it runs | What it scans |
|---|---|---|
| **Incremental** (`post-commit` hook) | Automatically after every `git commit` | Only the diff of the commit you just made — fast |
| **Full scan** (`--full` flag) | Manually, whenever you want | The entire working tree: source files, `.env`, `Dockerfile`, `docker-compose.yml`, dependency manifests, GitHub Actions workflows, and anything tracked in git that shouldn't be |

---

## What it checks

**Code patterns:** hardcoded API keys/secrets, AWS access keys, private key
blocks, `eval()`/`exec()`, `os.system()`, `subprocess(shell=True)`,
unsafe `pickle.loads()`, unsafe `yaml.load()`, SQL string concatenation,
debug flags left on, security TODOs.

**`.env` files:** flags any `.env*` file that's tracked in git (should never
be committed), and flags likely-real secret values inside it. `.env.example`
/ `.env.sample` files are treated leniently since they're meant to hold
placeholders.

**Docker:** `FROM ...:latest`, `curl | bash` / `wget | sh` patterns, secrets
baked into `ENV`/`ARG`, `ADD` fetching remote URLs, missing `USER` (container
running as root).

**docker-compose:** `privileged: true`, the Docker socket mounted into a
container, `network_mode: host`.

**Dependencies:** unpinned versions in `requirements.txt`/`Pipfile`, floating
`*`/`latest` versions in `package.json`, packages fetched over plain HTTP.

**GitHub Actions:** workflows triggered on `pull_request_target` (can run
with access to secrets on forked PRs), untrusted PR/issue text interpolated
directly into a `run:` step (script injection risk).

**`.gitignore`, tailored to your actual stack:** the full scan detects which
language(s)/frameworks are in play (via manifest files like
`requirements.txt`/`pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`,
`pom.xml`/`build.gradle`, `composer.json`, `Gemfile` — with file-extension
counting as a fallback), then checks your `.gitignore` against a rule set
built for *that* stack instead of a generic list. Examples: a Python repo
gets checked for `__pycache__/`, `venv/`/`.venv/`, `*.pyc`, `*.egg-info/`; a
Node repo gets checked for `node_modules/`, `dist/`, `npm-debug.log*`. On top
of the language-specific rules, it always checks for `.env`, `*.pem`, and
`*.key` regardless of stack. If `.gitignore` is missing entirely, that's
flagged too, with the fix message naming the detected language(s).

Every finding comes with a **suggested fix**, and each is rated
🔴 HIGH / 🟠 MEDIUM / 🟡 LOW.

### ⚠️ What it does NOT do (be aware of this)

This tool does **not** check your dependencies against a real CVE/vulnerability
database (like `pip-audit` or `npm audit` do) — that requires querying an
online advisory database, which isn't possible while staying fully offline.
Instead it flags *risky patterns* (unpinned versions, floating tags, insecure
protocols) that increase your exposure to supply-chain risk. If you also want
real CVE-level scanning, you can run these **separately, on demand** (they do
require network access to query vulnerability databases):

- Python: [`pip-audit`](https://github.com/pypa/pip-audit) — official PyPA tool
- Node: `npm audit` (built into npm)

---

## Installation

### Linux / macOS

```bash
# 1. Download/clone this folder somewhere, e.g. ~/tools/commit-guard

# 2. cd into the repo you want to protect
cd /path/to/your/repo

# 3. Run the installer
bash ~/tools/commit-guard/install.sh
```

### Windows

Requires **Git for Windows** (which you already have if you use `git` from
PowerShell/CMD — it ships with Git Bash) and **Python** installed and on PATH.

**Option A — Git Bash (recommended, simplest):**

```bash
# Open "Git Bash" (right-click in folder -> Git Bash Here, or search Start Menu)
cd /path/to/your/repo
bash /path/to/commit-guard/install.sh
```

**Option B — PowerShell / CMD:**

Git hooks are always executed through Git's bundled `sh.exe`, so the hook
itself works fine even if you never open Git Bash directly — but the
*installer* script (`install.sh`) is a bash script, so run it once via Git
Bash (Option A) or manually do the 3 copy steps yourself:

```powershell
cd C:\path\to\your\repo
mkdir .commit-guard
copy C:\path\to\commit-guard\scan.py .commit-guard\scan.py
copy C:\path\to\commit-guard\post-commit .git\hooks\post-commit
```

> Make sure `python` (or `python3`) is available on PATH — test with
> `python --version` in PowerShell. The hook auto-detects whichever one exists.

---

## Usage

**Automatic (incremental):** just commit normally.

```bash
git commit -m "your message"
# commit-guard runs automatically and prints a report
```

**Manual full-repo deep scan** (run anytime, e.g. before a release or PR):

```bash
python3 .commit-guard/scan.py --full
```

(On Windows, use `python` instead of `python3` if that's what's on your PATH.)

---

## Customizing / adding rules

Everything lives in `.commit-guard/scan.py` — no other file needs to change.

- **Add a new code pattern** → add a tuple to the `PATTERNS` list:
  ```python
  ("Your check name", r'your_regex_here', "HIGH", "Suggested fix text here."),
  ```
- **Reduce false positives for a keyword** → add a lowercase substring to
  `PLACEHOLDER_HINTS`; any line containing it gets skipped.
- **Exclude a file or folder** → add a regex to `EXCLUDED_FILE_PATTERNS`
  (line-pattern scan) or add the folder name to `IGNORED_DIRS` (full-repo walk).
- **Add a new structural check** (like the Dockerfile/compose ones) → write a
  `check_xxx(relpath, content)` function returning a list of findings via
  `make_finding(...)`, then call it from `scan_full_repo()` based on filename.
- **Support another language for the `.gitignore` audit** → add an entry to
  `LANG_MARKER_FILES` (manifest filename → language) and/or
  `EXT_LANG_FALLBACK` (file extension → language), then add its recommended
  entries to `LANGUAGE_GITIGNORE_RULES`.

After editing `scan.py`, if you already ran `install.sh` once, re-copy it into
the repo (`.commit-guard/scan.py`) or just re-run `install.sh` again — it
overwrites the old copy.

---

## Uninstalling

```bash
rm -rf .commit-guard
rm .git/hooks/post-commit
```
