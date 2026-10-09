#!/usr/bin/env bash
# Bare-metal xiaozhi-esp32-server on Perlinpinpin (Xubuntu 26.04). No Docker, no conda.
# Two isolated uv venvs:
#   xiaozhi-server : Python 3.10 (upstream pins torch 2.2.2)
#   pocket-tts     : Python 3.12, torch >= 2.5 CPU (Kyutai Pocket TTS)
# Voice models come from Hugging Face, run locally on CPU:
#   ASR  nvidia Parakeet-TDT 0.6B v3 (sherpa-onnx int8, ~640 MB)  — FR + EN + 23 EU languages
#   TTS  kyutai/pocket-tts (~100M params)                          — FR + EN + DE/ES/IT/PT/NL
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
ROOT="$HOME/xiaozhi-esp32-server"
SRV="$ROOT/main/xiaozhi-server"
POCKET="$HOME/pocket-tts"
CPU_IDX="https://download.pytorch.org/whl/cpu"

sudo apt-get install -y ffmpeg libopus0
command -v uv >/dev/null || pipx install uv

# --- xiaozhi-server -------------------------------------------------------
[ -d "$ROOT/.git" ] || git clone --depth 1 https://github.com/xinnan-tech/xiaozhi-esp32-server "$ROOT"
cd "$SRV"
[ -d .venv ] || uv venv -p 3.10 .venv
# CPU-only torch first, so requirements.txt does not pull the CUDA wheels
uv pip install -p .venv/bin/python torch==2.2.2 torchaudio==2.2.2 --index-url "$CPU_IDX"
uv pip install -p .venv/bin/python -r requirements.txt

# Patch 1: GLM "thinking" off for the Z.AI international endpoint (upstream: bigmodel.cn only)
F=core/providers/llm/openai/openai.py
grep -q '"api.z.ai"' "$F" || sed -i 's|^    "bigmodel.cn": {"thinking": {"type": "disabled"}},|&\n    "api.z.ai": {"thinking": {"type": "disabled"}},|' "$F"
# Patch 2: Parakeet (nemo_transducer) support in SherpaASR
.venv/bin/python "$HERE/patch-parakeet.py"

# Parakeet-TDT 0.6B v3 int8 from Hugging Face
PK=models/parakeet-tdt-0.6b-v3-int8
mkdir -p "$PK" data tmp
for f in encoder.int8.onnx decoder.int8.onnx joiner.int8.onnx tokens.txt; do
  [ -s "$PK/$f" ] || curl -fL -o "$PK/$f" \
    "https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/main/$f"
done

[ -f data/.config.yaml ] || cp "$HERE/.config.yaml" data/.config.yaml
chmod 600 data/.config.yaml   # holds the Z.AI key

# --- Pocket TTS (OpenAI-compatible shim) ----------------------------------
mkdir -p "$POCKET"
cp "$HERE/pocket_tts_openai.py" "$POCKET/"
[ -d "$POCKET/.venv" ] || uv venv -p 3.12 "$POCKET/.venv"
uv pip install -p "$POCKET/.venv/bin/python" pocket-tts fastapi uvicorn scipy --extra-index-url "$CPU_IDX" --index-strategy unsafe-best-match
# pre-fetch FR + EN weights (non-cloning weights are public; cloning needs HF login + accepted terms)
"$POCKET/.venv/bin/python" -c "from pocket_tts import TTSModel; [TTSModel.load_model(language=l) for l in ('english','french')]"

echo "Edit $SRV/data/.config.yaml (IPs, LM Studio model id, DeepSeek key), then:"
echo "  WS002_IP=<ip> $HERE/start.sh              # LLM fallback = ZaiGLMLLM"
echo "  WS002_IP=<ip> $HERE/start.sh DeepSeekLLM"
echo "OTA URL for the device: http://<PERLINPINPIN_IP>:8003/xiaozhi/ota/"
