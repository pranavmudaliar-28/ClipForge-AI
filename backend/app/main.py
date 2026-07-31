"""ClipForge AI worker — FastAPI application entrypoint.

Run (from backend/, inside the Python 3.12 venv):
    uvicorn app.main:app --host 0.0.0.0 --port 8000

The Android emulator reaches this host at http://10.0.2.2:8000.
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import ALLOWED_ORIGINS, WHISPER_MODEL
from .routers import media, transcription
from .services.audio import ffmpeg_available

app = FastAPI(title="ClipForge AI Worker", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(media.router)
app.include_router(transcription.router)


@app.get("/health", tags=["meta"])
def health() -> dict:
    """Liveness + a quick view of the environment the worker sees."""
    return {
        "status": "ok",
        "service": "clipforge-ai-worker",
        "whisper_model": WHISPER_MODEL,
        "ffmpeg": ffmpeg_available(),
    }
