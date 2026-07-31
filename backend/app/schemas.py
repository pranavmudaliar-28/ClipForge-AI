"""Pydantic request/response contracts shared with the Flutter client.

These field names are mirrored by the Dart models in
`lib/data/models/transcript.dart` — keep the two in sync.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class TranscriptSegment(BaseModel):
    id: int
    start: float = Field(description="Segment start time in seconds.")
    end: float = Field(description="Segment end time in seconds.")
    text: str


class TranscriptResponse(BaseModel):
    media_id: str
    language: str
    duration: float = Field(description="Total media duration in seconds.")
    text: str = Field(description="Full concatenated transcript.")
    segments: list[TranscriptSegment]


class UploadResponse(BaseModel):
    media_id: str
    filename: str
    size_bytes: int
