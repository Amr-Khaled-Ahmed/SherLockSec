#!/bin/bash
# Installs commit-guard into the current git repo.
# Usage: run this script from inside your repo root.

set -e

if [ ! -d ".git" ]; then
    echo "Error: run this from your git repo root (.git not found here)."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p .commit-guard
cp "$SCRIPT_DIR/scan.py" .commit-guard/scan.py

cp "$SCRIPT_DIR/post-commit" .git/hooks/post-commit
chmod +x .git/hooks/post-commit

echo "✅ commit-guard installed."
echo "   - Scanner: .commit-guard/scan.py"
echo "   - Hook:    .git/hooks/post-commit"
echo ""
echo "It will now run automatically after every 'git commit'."
