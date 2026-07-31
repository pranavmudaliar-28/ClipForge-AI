# ClipForge AI — Worker (FastAPI)

The real slice of the AI pipeline: **video → ffmpeg audio extraction → faster-whisper transcript**.
Everything else in the app's AI-processing screen is simulated; this service produces the real
transcript that becomes the caption track in the editor.

## Why a separate Python 3.12 venv?

The machine default is Python **3.14**, which has no `torch` / `CTranslate2` wheels yet, so
`faster-whisper` can't install there. The worker pins **3.12** (installed via
`winget install Python.Python.3.12`).

## Run

```powershell
# from backend/
./run.ps1
```

This creates `.venv` (Python 3.12), installs deps, and starts uvicorn on `0.0.0.0:8000`.

Prerequisite: `ffmpeg` on PATH (`winget install Gyan.FFmpeg`). Check `/health` — it reports whether
ffmpeg is visible.

## Endpoints

| Method | Path          | Purpose                                                        |
|--------|---------------|----------------------------------------------------------------|
| GET    | `/health`     | Liveness + model name + ffmpeg availability                    |
| POST   | `/media/upload` | Store a file, return `media_id` (for future multi-job reuse)  |
| POST   | `/transcribe` | multipart `file` → `{media_id, language, duration, text, segments[]}` |

Interactive docs at `http://localhost:8000/docs`.

## Client networking

- Android **emulator** → host: `http://10.0.2.2:8000`
- Physical device on same LAN → `http://<host-ip>:8000`

Configured in the Flutter app at `lib/data/remote/api_client.dart`.

## Config (env vars)

| Var                        | Default | Notes                                   |
|----------------------------|---------|-----------------------------------------|
| `CLIPFORGE_WHISPER_MODEL`  | `base`  | `tiny`/`base`/`small`/`medium`/`large-v3` |
| `CLIPFORGE_WHISPER_DEVICE` | `cpu`   | `cuda` on a GPU box                     |
| `CLIPFORGE_WHISPER_COMPUTE`| `int8`  | `float16` on GPU                        |
| `CLIPFORGE_STORAGE`        | `./storage` | Upload + extracted-audio dir        |
| `CLIPFORGE_FFMPEG`         | `ffmpeg` | Path to ffmpeg binary                  |

> First `/transcribe` downloads the model (~150 MB for `base`) and is slow; later calls reuse it.
