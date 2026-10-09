# xiaozhi on LCDWiki E32R28T — Claude Code handoff (Perlinpinpin)

**v1.1 · 2026-10-01** (voice stack: local Parakeet ASR + Pocket TTS from Hugging Face) · Host: Perlinpinpin (Xubuntu 26.04, user `hackinblue`, in `dialout`) · Board on `/dev/ttyUSB0`

## Constraint (operator, non-negotiable)
**LAN only. No VPS, no tunnels, no port forwarding.** Topology: ESP32 → Wi-Fi → Perlinpinpin (xiaozhi-server) → LAN → WS-002 (LM Studio). Experiment scope — do not propose remote/VPS paths.

## Context (read once)
- Board: LCDWiki 2.8" **ESP32-32E** (E32R28T): ESP32-D0WD-V3, **4 MB flash, no PSRAM**, ILI9341V 240×320 TN, XPT2046 resistive touch, CH340C USB-serial.
- Board has **no microphone**. Its speaker amp (FM8002E) is fed by the 8-bit DAC on IO26 — poor quality, not used.
- Upstream `78/xiaozhi-esp32` has no port for this board. This folder carries one: `lcdwiki-e32r28t-board.patch` (against upstream `ed5cd7b`, firmware v2.5.1, ESP-IDF v6.1).
- Prebuilt image: `xiaozhi-v2.5.1-lcdwiki-e32r28t-en-jarvis-merged.bin` — UI en-US, wake word **"Jarvis"**, OTA URL = official cloud `https://api.tenclass.net/xiaozhi/ota/` (change at runtime, see step 4). Built clean; **not yet run on hardware**.
- Audio is one duplex I2S bus on the 4-pin "SPI peripheral" header (shared with microSD → **no SD card inserted**).

## Wiring (needs INMP441 mic + MAX98357A amp + 4–8 Ω speaker)
| Header pin | GPIO | INMP441 | MAX98357A |
|---|---|---|---|
| SPI hdr | IO18 | SCK | BCLK |
| SPI hdr | IO23 | WS | LRC |
| SPI hdr | IO19 | SD | — |
| SPI hdr | IO27 | — | DIN |
| expand hdr | 3V3 | VDD | VIN (3V3 works; 5V louder) |
| expand hdr | GND | GND + **L/R→GND** | GND |
MAX98357A GAIN pin floating = 9 dB. ⚠️ The header pin order is not documented: buzz each pin to the module before connecting power.

## Tasks for Claude Code — in order

### 1. Flash (no wiring needed)
```bash
chmod +x flash.sh && ./flash.sh /dev/ttyUSB0
pipx run --spec pyserial pyserial-miniterm --raw /dev/ttyUSB0 115200
```
- If `/dev/ttyUSB0` vanishes on plug-in: `brltty` claimed the CH340 → `sudo apt remove brltty`.
- If esptool cannot sync: hold BOOT, tap RST (EN), release BOOT, rerun.

### 2. Verify display
Expect the xiaozhi status UI, upright, correct colours. If wrong, edit `main/boards/lcdwiki-e32r28t/config.h` and rebuild (step 6):
- mirrored → toggle `DISPLAY_MIRROR_X`
- negative colours → `DISPLAY_INVERT_COLOR true`
- red/blue swapped → `DISPLAY_RGB_ORDER LCD_RGB_ELEMENT_ORDER_RGB`

### 3. Wi-Fi
Network: **"Yokohama AI 5G"** — 5G-cellular WAN router, dual-band 2.4 + 5 GHz (operator-confirmed). The ESP32 joins it on 2.4 GHz.
Device boots into AP mode `Xiaozhi-XXXX` → join from phone → `http://192.168.4.1` → pick SSID.

### 4. Backend — pick one
- **Cloud smoke test (5 min):** keep default OTA URL; screen shows a 6-digit code → bind at xiaozhi.me console. Proves mic/speaker/Wi-Fi end-to-end.
- **Self-hosted (target):** run `server/setup-server.sh`, edit `data/.config.yaml`, then `WS002_IP=<ip> server/start.sh`. Then in the device portal → *Advanced* → OTA URL `http://<PERLINPINPIN_IP>:8003/xiaozhi/ota/`. Open that URL in a browser first — it must return JSON.
  - LLM, two options, picked at launch by `server/start.sh` (probes `http://<WS002_IP>:1234/v1/models`):
    1. **Local** — `LMStudioLLM` on WS-002 when it answers.
    2. **Fallback** — `ZaiGLMLLM` (`glm-4.5-flash`, Z.AI free tier, dedicated ESP32 key already in `.config.yaml`) by default, or `DeepSeekLLM` (`deepseek-v4-flash`): `./start.sh DeepSeekLLM`.
    No runtime failover in the server: if WS-002 drops mid-session, restart `start.sh`. `setup-server.sh` patches thinking-off for `api.z.ai` (upstream only does it for `bigmodel.cn`).
  - Voice, all local on Perlinpinpin CPU, weights from Hugging Face:
    - **In (ASR):** `ParakeetASR` — `nvidia/parakeet-tdt-0.6b-v3` (sherpa-onnx int8, `csukuangfj/...-int8`, ~640 MB). FR + EN + 23 EU languages, punctuation + accents. `patch-parakeet.py` adds `nemo_transducer` to xiaozhi's SherpaASR.
    - **Out (TTS):** `PocketTTS` — `kyutai/pocket-tts` (~100M params) behind `pocket_tts_openai.py` (OpenAI `/v1/audio/speech` shim on `127.0.0.1:8090`, started by `start.sh`). FR model + voice `estelle` when the reply is French, EN + `alba` otherwise. Voice cloning = `--voice-fr/--voice-en path.wav` (needs HF login + accepted terms on `kyutai/pocket-tts`).
    - Cloud alternative kept in config: `EdgeTTS`. Previous ASR kept: `FunASR` (SenseVoice — no French; model not downloaded by default).
    - First check on the box: say a French sentence, read `tmp/server.log` for ASR text + timings; `curl -s localhost:8090/health`.
  - ⚠️ ExpressVPN's kill-switch chains may drop inbound LAN on 8000/8003 — test from the phone before blaming the firmware.

### 5. Acceptance
Say "Jarvis" → LED blue (listening) → reply on speaker, LED green (speaking). BOOT button = toggle chat. LED magenta = config/activation, yellow = connecting, red = fatal.

### 6. Rebuild from source (only if config changes)
```bash
git clone https://github.com/78/xiaozhi-esp32 && cd xiaozhi-esp32 && git checkout ed5cd7b
git apply ../lcdwiki-e32r28t-board.patch
# ESP-IDF v6.1 (~2.5 GB):
git clone -b v6.1 --depth 1 --recursive --shallow-submodules https://github.com/espressif/esp-idf ~/esp/esp-idf
~/esp/esp-idf/install.sh esp32 && . ~/esp/esp-idf/export.sh
python scripts/build.py lcdwiki-e32r28t          # -> build/merged-binary.bin
python scripts/build.py --list-wake-words        # options: Jarvis, Alexa, Computer, "Bonjour ESP", Hi ESP...
```
Wake word / language are set in `main/boards/lcdwiki-e32r28t/config.json` → `sdkconfig_append`.

## Known limits
- No PSRAM → no AFE/AEC on ESP32 (LiteAudioEngine, raw PCM). Speaker can retrigger the mic: keep them apart.
- Perlinpinpin's Celeron G3930 has **no AVX/AVX2** (SSE4.2 only). Sandbox benchmark with AVX disabled, 2 threads: Pocket TTS int8 ≈ 2× real-time warm; Parakeet 4.4 s audio → 0.45 s (AVX2; non-AVX not emulable for ONNX). Real numbers come from the box.
- `TOUCH_IRQ_AS_BUTTON` (tap screen = talk) is off; untested.
