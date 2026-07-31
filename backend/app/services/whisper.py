"""Speech-to-text using faster-whisper.

The model is loaded lazily and cached for the process lifetime — the first
`/transcribe` call downloads the weights (~150 MB for `base`) and is therefore
slow; subsequent calls reuse the in-memory model.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from ..config import WHISPER_COMPUTE, WHISPER_DEVICE, WHISPER_MODEL
from ..schemas import TranscriptSegment


@lru_cache(maxsize=1)
def _model():
    # Imported lazily so the server can boot (and serve /health) even before
    # faster-whisper is installed in the venv.
    from faster_whisper import WhisperModel

    return WhisperModel(WHISPER_MODEL, device=WHISPER_DEVICE, compute_type=WHISPER_COMPUTE)


def transcribe(audio_path: Path) -> dict:
    """Return {language, duration, text, segments[]} for a 16 kHz WAV file."""
    model = _model()
    segments_iter, info = model.transcribe(str(audio_path), vad_filter=True, beam_size=1)

    segments: list[TranscriptSegment] = []
    texts: list[str] = []
    for index, seg in enumerate(segments_iter):
        text = seg.text.strip()
        segments.append(
            TranscriptSegment(id=index, start=round(seg.start, 3), end=round(seg.end, 3), text=text)
        )
        texts.append(text)

    return {
        "language": info.language,
        "duration": round(info.duration, 3),
        "text": " ".join(texts).strip(),
        "segments": segments,
    }
