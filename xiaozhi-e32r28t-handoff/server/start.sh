#!/usr/bin/env bash
# Start xiaozhi-server with LLM auto-selection at launch:
#   WS-002 LM Studio answering -> LMStudioLLM (local inference)
#   otherwise                  -> $FALLBACK_LLM (ZaiGLMLLM | DeepSeekLLM)
# Selection happens at start only; the server has no runtime failover.
# Usage: WS002_IP=192.168.1.x ./start.sh [ZaiGLMLLM|DeepSeekLLM]
set -euo pipefail
SRV="$HOME/xiaozhi-esp32-server/main/xiaozhi-server"
CFG="$SRV/data/.config.yaml"
WS002_IP="${WS002_IP:?set WS002_IP}"
FALLBACK_LLM="${1:-ZaiGLMLLM}"

if curl -fsS -m 3 "http://$WS002_IP:1234/v1/models" >/dev/null 2>&1; then
  LLM=LMStudioLLM
else
  LLM="$FALLBACK_LLM"
fi
# rewrite the LLM line inside selected_module only
sed -i "/^selected_module:/,/^[^ ]/ s/^\(  LLM: \)[A-Za-z0-9_]*/\1$LLM/" "$CFG"
echo "LLM -> $LLM"

# Local TTS shim (Pocket TTS, FR+EN, int8) — only if PocketTTS is the selected TTS
POCKET="$HOME/pocket-tts"
if grep -qE '^  TTS: PocketTTS' "$CFG" && ! curl -fsS -m 2 http://127.0.0.1:8090/health >/dev/null 2>&1; then
  nohup "$POCKET/.venv/bin/python" "$POCKET/pocket_tts_openai.py" --port 8090 --quantize \
    > "$POCKET/shim.log" 2>&1 &
  for _ in $(seq 1 60); do curl -fsS -m 2 http://127.0.0.1:8090/health >/dev/null 2>&1 && break; sleep 2; done
  curl -fsS -m 2 http://127.0.0.1:8090/health >/dev/null || { echo "Pocket TTS failed, see $POCKET/shim.log"; exit 1; }
  echo "TTS -> PocketTTS (127.0.0.1:8090)"
fi

cd "$SRV"
# shellcheck disable=SC1091
. .venv/bin/activate
exec python app.py
