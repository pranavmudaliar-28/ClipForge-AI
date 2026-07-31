"""Media upload endpoint.

Kept separate from transcription so the client can upload once and run several
AI jobs against the same `media_id` in later phases.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, File, UploadFile

from ..config import STORAGE_DIR
from ..schemas import UploadResponse

router = APIRouter(prefix="/media", tags=["media"])

_CHUNK = 1024 * 1024  # 1 MiB streaming chunks


@router.post("/upload", response_model=UploadResponse)
async def upload(file: UploadFile = File(...)) -> UploadResponse:
    media_id = uuid.uuid4().hex
    dest = STORAGE_DIR / f"{media_id}_{file.filename}"
    size = 0
    with dest.open("wb") as out:
        while chunk := await file.read(_CHUNK):
            size += len(chunk)
            out.write(chunk)
    return UploadResponse(media_id=media_id, filename=file.filename or "upload.bin", size_bytes=size)
