"""Transcription endpoint — the real slice of the AI pipeline.

Flow: receive video (multipart) -> save -> ffmpeg extract 16 kHz WAV ->
faster-whisper -> return segments + full text. The Flutter AI-processing screen
calls this for its "Transcribe speech" stage; all other stages are simulated.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, File, HTTPException, UploadFile

from ..config import STORAGE_DIR
from ..schemas import TranscriptResponse
from ..services import whisper
from ..services.audio import extract_audio

router = APIRouter(tags=["transcription"])

_CHUNK = 1024 * 1024


@router.post("/transcribe", response_model=TranscriptResponse)
async def transcribe(file: UploadFile = File(...)) -> TranscriptResponse:
    media_id = uuid.uuid4().hex
    video_path = STORAGE_DIR / f"{media_id}_{file.filename}"
    with video_path.open("wb") as out:
        while chunk := await file.read(_CHUNK):
            out.write(chunk)

    audio_path = STORAGE_DIR / f"{media_id}.wav"
    try:
        extract_audio(video_path, audio_path)
    except Exception as exc:  # noqa: BLE001 - surface a clean 500 to the client
        raise HTTPException(status_code=500, detail=f"Audio extraction failed: {exc}") from exc

    try:
        result = whisper.transcribe(audio_path)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Transcription failed: {exc}") from exc

    return TranscriptResponse(media_id=media_id, **result)
