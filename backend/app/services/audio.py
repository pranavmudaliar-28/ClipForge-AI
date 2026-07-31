"""Audio extraction via ffmpeg.

Whisper models expect 16 kHz mono PCM, so we down-mix and resample here rather
than feeding the raw video to the model.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from ..config import FFMPEG_BIN


def ffmpeg_available() -> bool:
    return shutil.which(FFMPEG_BIN) is not None


def extract_audio(video_path: Path, out_path: Path) -> Path:
    """Extract a 16 kHz mono WAV from `video_path` into `out_path`."""
    if not ffmpeg_available():
        raise RuntimeError(
            f"ffmpeg not found (looked for '{FFMPEG_BIN}'). "
            "Install it with `winget install Gyan.FFmpeg` and restart the shell."
        )
    cmd = [
        FFMPEG_BIN,
        "-y",
        "-i", str(video_path),
        "-vn",            # drop video
        "-ac", "1",       # mono
        "-ar", "16000",   # 16 kHz
        "-f", "wav",
        str(out_path),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"ffmpeg failed (code {proc.returncode}): {proc.stderr[-2000:]}")
    return out_path
