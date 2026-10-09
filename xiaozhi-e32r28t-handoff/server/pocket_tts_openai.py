#!/usr/bin/env python3
"""OpenAI-compatible /v1/audio/speech shim over Kyutai Pocket TTS (CPU, local, HF weights).

xiaozhi-server's `type: openai` TTS posts JSON {model, input, voice, response_format, speed};
Pocket's own `serve` expects multipart form on /tts, hence this shim.

- Loads the English and French models once (kept in RAM).
- voice "auto" (default): French model + French voice if the text looks French, else English.
- voice "<name>" : built-in Pocket voice; "<path>.wav|.safetensors" : cloned voice.
Run:  python pocket_tts_openai.py --port 8090 [--quantize] [--voice-en alba] [--voice-fr estelle]
"""
import argparse
import io
import re
import threading

import scipy.io.wavfile as wavfile
import torch
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pocket_tts import TTSModel
from pydantic import BaseModel

FR_HINT = re.compile(
    r"[àâçéèêëîïôûùüÿœæ]|\b(le|la|les|des|une|est|et|pas|que|qui|pour|avec|dans|sur|vous|nous|je|tu|il|elle|c'est|n'est|bonjour|merci|oui)\b",
    re.IGNORECASE,
)


def looks_french(text: str) -> bool:
    words = max(1, len(text.split()))
    return len(FR_HINT.findall(text)) / words >= 0.15


class SpeechRequest(BaseModel):
    input: str
    model: str | None = None
    voice: str | None = "auto"
    response_format: str | None = "wav"
    speed: float | None = 1.0


def build_app(args) -> FastAPI:
    torch.set_num_threads(args.threads)
    engines = {}
    for lang, default_voice in (("english", args.voice_en), ("french", args.voice_fr)):
        model = TTSModel.load_model(language=lang, quantize=args.quantize)
        engines[lang] = {
            "model": model,
            "state": model.get_state_for_audio_prompt(default_voice),
            "lock": threading.Lock(),  # generate_audio is not thread-safe
        }
    voice_cache: dict[tuple[str, str], object] = {}
    app = FastAPI(title="pocket-tts-openai")

    @app.get("/health")
    def health():
        return {"ok": True, "languages": list(engines)}

    @app.post("/v1/audio/speech")
    def speech(req: SpeechRequest):
        text = (req.input or "").strip()
        if not text:
            raise HTTPException(400, "empty input")
        lang = "french" if looks_french(text) else "english"
        eng = engines[lang]
        state = eng["state"]
        if req.voice and req.voice != "auto":
            key = (lang, req.voice)
            if key not in voice_cache:
                voice_cache[key] = eng["model"].get_state_for_audio_prompt(req.voice)
            state = voice_cache[key]
        with eng["lock"]:
            audio = eng["model"].generate_audio(state, text)
        buf = io.BytesIO()
        pcm = (audio.squeeze().clamp(-1, 1).numpy() * 32767).astype("int16")
        wavfile.write(buf, eng["model"].sample_rate, pcm)
        return Response(buf.getvalue(), media_type="audio/wav")

    return app


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8090)
    ap.add_argument("--threads", type=int, default=2)
    ap.add_argument("--quantize", action="store_true", help="int8 weights: less RAM, faster")
    ap.add_argument("--voice-en", default="alba")
    ap.add_argument("--voice-fr", default="estelle")
    a = ap.parse_args()
    uvicorn.run(build_app(a), host=a.host, port=a.port, log_level="warning")
