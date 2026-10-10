# xiaozhi on Freenove ESP32-S3: handoff v1.3 (voice chain diagnosed; language fix pending test)

**Version:** 1.3 · **Date:** 2026-10-10 · **Host:** Perlinpinpin (Xubuntu 26.04.1, user `hackinblue`, LAN 192.168.1.6)
**Supersedes:** `freenove-s3-xiaozhi-handoff-v1.2.md` · **Companions:** `gc9a01-xiaozhi-firmware-params-v1.1.md` · `~/xiaozhi-s3cam/CLAUDE.md`
**Marks:** ✅ confirmed (source named) · ⚠️ inference · ❌ insufficient data

| Version | Date | Change |
|---|---|---|
| 1.2 | 2026-10-09 | GC9A01 pin map, Gate 0/1 defined. |
| 1.3 | 2026-10-10 | Gate 1 + Gate 3 passed. Voice chain traced end to end: two server-side faults found, one fixed and verified, one fixed and untested. Session closed before the final test. |

---

## 1. Status at close

| Stage | State | Evidence |
|---|---|---|
| Gate 1: OTA URL in build | ✅ | `sdkconfig:964 CONFIG_OTA_URL="http://192.168.1.6:8003/xiaozhi/ota/"`, `:1143 CONFIG_LCD_GC9A01_240X240=y`; committed in `4c09662` |
| Gate 3: board → server | ✅ | boot log `HttpClient: Established new connection to 192.168.1.6:8003`, `Ota: Current is the latest version`; server log `OTA请求设备ID: 20:6e:f1:aa:b5:6c` |
| Wake word | ✅ | `AFE: WakeNet(wn9_jarvis_tts)`; server `listen … "text":"Jarvis"` |
| Mic → ASR | ✅ | server `识别文本: Tu voudrais bien te mettre en route ?` (Parakeet, French, exact) |
| LLM reply | ✅ but Chinese | `发送第一段语音: 当然可以` / `请注意文明用语` — see §2.2 |
| TTS (Pocket TTS) | ✅ fixed | was `Illegal instruction`; now `语音生成成功`, curl → `200 42284` bytes |
| Audio on speaker | ❌ not yet heard | all replies so far were Chinese text → no usable audio from an EN/FR-only TTS |
| Latency ASR → first audio | ✅ 5 s | 01:31:31 → 01:31:36 (GLM fallback, fp32 TTS) |
| Display (GC9A01) | ⏳ unchanged from v1.2 | Gate 0 / 2 / 4 not run |

## 2. Faults found tonight

### 2.1 Pocket TTS shim died on first request — FIXED ✅
- Symptom: `语音生成失败 … Remote end closed connection`, then `Connection refused` on 127.0.0.1:8090; `shim.log` ends with a torch quantize warning, no traceback.
- Cause ✅ (foreground run): `Illegal instruction (core dumped)` — `--quantize` uses int8 fbgemm kernels needing AVX2; G3930 has SSE4.2 only.
- Fix ✅: removed ` --quantize` from `~/projects/xiaozhi-e32r28t/server/start.sh` line 25. Verified: `curl …/v1/audio/speech` → `200`, 42 KB WAV.
- Cost ⚠️: fp32 synthesis on 2 cores; measured chain latency still 5 s to first audio.

### 2.2 Replies in Chinese — FIXED, UNTESTED ⏳
- Cause ✅ (server source, `core/utils/prompt_manager.py` l.278–283 + `agent-base-prompt.txt`): the server wraps the persona in a template with a "CRITICAL OUTPUT-LANGUAGE RULE: write EVERY response in `{{language}}` regardless of the user's language". `{{language}}` = `TTS.<selected>.language` from `.config.yaml`, **default `中文`**. The PocketTTS block had no `language:` key → Chinese forced; persona wording cannot override it (tested: explicit "NEVER write Chinese" line ignored).
- Fix applied: `data/.config.yaml`, PocketTTS block, added `language: "the language the user spoke, French or English"` (after `output_dir: tmp/`).
- ❌ Not tested: server was restarted but no spoken exchange completed before close. **First action next session.**
- The persona also gained a redundant "Reply ONLY in French or English…" line (l.17); harmless, can stay.

## 3. Next session, in order
1. Clean start — stale servers were the main time sink tonight:
   ```bash
   fuser -k 8000/tcp 8003/tcp 8090/tcp; sleep 2; ss -ltnp | grep -E ':(8000|8003|8090)\b' || echo "ports free"
   WS002_IP=127.0.0.1 bash ~/projects/xiaozhi-e32r28t/server/start.sh
   ```
   Wait for `TTS -> PocketTTS` and `asr成功 ParakeetASR`, with no `Errno 98`.
2. Power-cycle the board. "Jarvis" + a French question.
3. Read: `grep -aE '识别文本|发送第一段|语音生成' ~/xiaozhi-esp32-server/main/xiaozhi-server/tmp/server.log | tail -n 4`
   - French reply text + `语音生成成功` + audible voice → **Gate 5 passed**; commit and move to display (Gate 0).
   - French text but no sound → board playback path: `AudioCodec: Set output enable` lines in the monitor; amp VIN 5 V; speaker terminal.
   - Still Chinese → `language:` key not picked up: check YAML indent (4 spaces, inside `PocketTTS:`), and that the server was actually restarted (`ps -o lstart= -p $(fuser 8000/tcp 2>/dev/null)`).
4. Optional model swap if GLM quality is poor once language is right: `start.sh DeepSeekLLM`.

## 4. Gotchas added tonight
- **Closing a terminal does not kill the server.** Always `fuser -k 8000/tcp 8003/tcp 8090/tcp` before `start.sh`; `Errno 98 address already in use` means a stale server is still answering the board with the old config.
- **`start.sh` must be called by full path**: `bash ~/projects/xiaozhi-e32r28t/server/start.sh`.
- **Terminal pastes arrive wrapped in bracketed-paste markers** (`^[[200~`) in this Xfce terminal: type `reset`, paste one line at a time, never paste back output.
- **Monitor dies on board replug/power-cycle**; restart with `idf.py -p /dev/ttyACM0 monitor` (no flash). Blue `IO2` LED solid = firmware running (mic clock), even when the monitor is black.
- **Pocket TTS has EN + FR only**: any Chinese reply text is inaudible by design — a silent board with `语音生成成功` in the log means wrong language, not broken audio.
- GitHub email privacy: commits must use `65628989+YokohamaAIart@users.noreply.github.com`; `jerome@jeromemartin.art` is rejected on push.

## 5. Housekeeping done 2026-10-10
- `~/Documents/Microcontrolers/Xiao Zhi` cleaned (4 superseded docs + old HANDOFF script in `_quarantine/`), is now the local clone of `YokohamaAIart/AI_chatbot_esp32`, pushed `e460ef1`. Secrets (`.config.yaml`, archives, Meshtastic keys) kept out of the public repo; keys file moved to `~/Documents/Microcontrolers/Meshtastic/`.
- `tools/xiaozhi-folder-push.sh` v1.1 in the repo: `plan | clean | push | apply | restore`.
- ⚠️ `~/xiaozhi-s3cam/CLAUDE.md` still points docs at `~/projects/AI_chatbot_esp32/docs/`; the real clone is `~/Documents/Microcontrolers/Xiao Zhi/`. Update the path or symlink.

## Sources
- xiaozhi-esp32-server @ a6cd755 (2026-10-09): `core/utils/prompt_manager.py`, `agent-base-prompt.txt`, `config.yaml`
- Server log `tmp/server.log` 2026-10-10 01:10–02:05; board monitor log; `~/pocket-tts/shim.log`; foreground shim run.
