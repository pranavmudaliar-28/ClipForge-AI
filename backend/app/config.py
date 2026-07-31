"""Runtime configuration for the ClipForge AI worker.

Everything is overridable via environment variables so the same code runs on a
laptop (CPU, int8) or a GPU box (cuda, float16) without edits.
"""

from __future__ import annotations

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Where uploaded videos and extracted audio live during dev.
STORAGE_DIR = Path(os.getenv("CLIPFORGE_STORAGE", str(BASE_DIR / "storage")))
STORAGE_DIR.mkdir(parents=True, exist_ok=True)

# faster-whisper model configuration.
#   size:    tiny | base | small | medium | large-v3  (downloaded on first use)
#   device:  cpu | cuda
#   compute: int8 (CPU friendly) | float16 (GPU)
WHISPER_MODEL = os.getenv("CLIPFORGE_WHISPER_MODEL", "base")
WHISPER_DEVICE = os.getenv("CLIPFORGE_WHISPER_DEVICE", "cpu")
WHISPER_COMPUTE = os.getenv("CLIPFORGE_WHISPER_COMPUTE", "int8")

# ffmpeg binary (on PATH by default after `winget install Gyan.FFmpeg`).
FFMPEG_BIN = os.getenv("CLIPFORGE_FFMPEG", "ffmpeg")

# CORS — the Flutter client is not browser-based, but keep this permissive for
# local tooling (Swagger UI, curl from other hosts).
ALLOWED_ORIGINS = os.getenv("CLIPFORGE_ALLOWED_ORIGINS", "*").split(",")
