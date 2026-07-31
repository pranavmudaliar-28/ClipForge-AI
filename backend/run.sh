#!/usr/bin/env bash
# Creates a Python 3.12 venv, installs deps, and runs the ClipForge AI worker.
set -euo pipefail
cd "$(dirname "$0")"

PY312="${PYTHON312:-py -3.12}"

if [ ! -d ".venv" ]; then
  echo "Creating Python 3.12 venv..."
  $PY312 -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/Scripts/activate 2>/dev/null || source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

echo "Starting worker on http://0.0.0.0:8000 (emulator: http://10.0.2.2:8000)"
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
