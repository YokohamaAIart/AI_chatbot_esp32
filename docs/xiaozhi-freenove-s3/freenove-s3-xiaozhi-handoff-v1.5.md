# xiaozhi on Freenove ESP32-S3: handoff v1.5 (everything proven except the amp — amp dead, swap pending)

**Version:** 1.5 · **Date:** 2026-10-19 · **Host:** Perlinpinpin (Xubuntu 26.04.1, user `hackinblue`, LAN 192.168.1.6)
**Supersedes:** `freenove-s3-xiaozhi-handoff-v1.4.md` · **Companions:** `XIAOZHI_S3_PROJECT_DOC_v1.0.md` (full doc) · `XIAOZHI_S3_CHEATSHEET_v1.0.md` · `freenove-s3-wiring-diagram-v0.7.pdf` (VERIFIED) · `s3cam-oled-i2c-v0.3.patch`
**Marks:** ✅ confirmed (source named) · ⚠️ inference · ❌ insufficient data · ⏳ pending

| Version | Date | Change |
|---|---|---|
| 1.3 | 2026-10-10 | Voice chain traced; TTS SIGILL fixed; language cause found. |
| 1.4 | 2026-10-18 | SH1106 swap, wiring v0.7 verified, speaker/short findings, tree-path rule; flash pending. |
| 1.5 | 2026-10-19 | OLED on I²C port 0 (patch v0.2), LVGL flush guard (v0.3). Full chain works: wake → ASR → English/French reply → TTS → audio sent. DIN jumper found open and replaced. Amp diagnosed dead at the output stage. Server tree moved under Documents, symlinked. |

---

## 1. Status at close

| Stage | State | Evidence |
|---|---|---|
| Gate 1 OTA URL in build · Gate 3 board→server | ✅ | `Ota: Current is the latest version`; server `OTA请求设备ID: 20:6e:f1:aa:b5:6c` 2026-10-19 14:30 |
| Gate 4 display | ✅ | `OLED 128x64 on I2C port 0`; orientation `MIRROR false/false`; guard active |
| Camera | ✅ | `Detected OV5640 camera`, `cam config ok` (after moving the OLED off port 1) |
| Wake + ASR | ✅ | `识别文本: What is the volume setting now?` 14:26:32 |
| LLM language | ✅ | replies in English to English input (`The current volume is set to 100%`) |
| TTS + audio sent | ✅ | `语音生成成功` + `发送音频消息` 14:26:50 |
| Gate 5 audible reply | ❌ | 0 V~ across the speaker while speaking; all amp inputs present |
| Volume | ✅ 100 | `get_device_status` → `"audio_speaker":{"volume":100}` |

## 2. Findings 2026-10-18 → 19

### 2.1 Camera vs OLED I²C port ✅
Camera SCCB uses port 1 (`sccb-ng: sccb_i2c_port=1`). Patch v0.1 put the OLED there → `I2C bus id(1) has already been acquired`, camera probe failed. v0.2: `DISPLAY_I2C_PORT I2C_NUM_0`.

### 2.2 LVGL freeze on I²C NACK ✅ (software cure in; hardware cure pending)
Symptom: `task_wdt … CPU 1: taskLVGL`, backtrace in `wait_for_flushing`, then `Display: Failed to lock display` every 30 s; state machine stops, wake word ignored, audio never plays. Cause: esp_lcd's I²C panel IO (`esp_lcd_panel_io_i2c_v2.c`) calls `on_color_trans_done` only after a successful transmit; a NACKed page flush returns early, LVGL never gets `flush_ready` and spins (same trace reported in espressif/esp-idf#14348 by another xiaozhi user; their fixes were power/solder). No I²C error is printed in this build (silent checks ⚠️ not verified). Cure: v0.3 `lv_display_set_flush_wait_cb` in `oled_display.cc` — yields and forces `flush_ready` after ~100 ms (`OledDisplay: I2C flush lost, forcing flush_ready`). 100 kHz did not remove the NACKs on its own. Still to do on hardware: 4.7 kΩ SDA/SCL pull-ups to 3V3 and 47–220 µF across OLED VCC/GND at the OLED end; unpowered read SDA↔VCC / SCL↔VCC (20 kΩ range) tells whether the module has its own pull-ups.

### 2.3 DIN jumper open ✅
With the display stable, still no sound. Live reads at the amp pads: LRC 1.4–1.7 V, BCLK ~1.15 V, SD 4.15 V, VIN 4.94–5.01 V, OUT+ = OUT− = 3.40 V, DIN ≈ 0.8 V. Unpowered continuity: BCLK↔GPIO40 and LRC↔GPIO41 beep, **DIN↔GPIO39 open** (Dupont). Replaced and re-verified 2026-10-19. Lesson added to the skill checklist: end-to-end continuity of every signal wire, unpowered, before the first power-up — adjacent-pair short tests alone miss an open.

### 2.4 Amp dead ✅ (verdict)
After the DIN fix: all four inputs present, volume 100, AC across the speaker wires at the amp joints = 0 V~ throughout a spoken reply. Output stage not modulating. Replace the MAX98357A module. On the new one: silkscreen order check against the diagram (clones vary), adjacent pairs OL unpowered, OUT+↔OUT− = speaker Ω, then power and speak.

### 2.5 Server tree moved ✅
Everything regrouped under `~/Documents/Microcontrolers/Xiao Zhi/`. `start.sh` (live copy at `~/projects/xiaozhi-e32r28t/server/start.sh`, no `--quantize`) hard-codes `$HOME/xiaozhi-esp32-server` → symlink created: `~/xiaozhi-esp32-server → …/Xiao Zhi/xiaozhi-esp32-server`; the server venv's absolute paths resolve again. `~/pocket-tts` unchanged. Firmware tree stays at `~/xiaozhi-s3cam` (no-space path required for the link step).

### 2.6 Clock ⚠️
OLED shows UTC+8 (China default of the server). Set `timezone_offset: +2` (winter `+1`) in `data/.config.yaml`, restart server. [VERIFY key name on 0.9.7]

## 3. Next session, in order
1. New MAX98357A: silkscreen vs diagram v0.7 → bench reads (unpowered) → wire per diagram → power → "Jarvis" + question → **Gate 5** = audible reply. Bump the diagram to v0.8 if the clone's pin order differs.
2. OLED bus hardening: pull-ups + cap (§2.2), then watch for `I2C flush lost` lines over an hour; none = done.
3. `timezone_offset` fix; restart server; check the OLED clock.
4. Commit `freenove-s3` on Perlinpinpin after Gate 5 (`git add -A main/ && git commit`); push the docs repo only when told.
5. Optional: systemd user unit for `start.sh` (server dies with the terminal only if the terminal is killed, but a unit survives logout); DHCP reservation for 192.168.1.6.

## 4. Gotchas added
- Continuity test on a **live** board is meaningless; unplug first.
- "Beep" means two things: same wire both ends = good; two different pins = short. Say which one you are testing.
- Blue solid RGB LED = board waiting for the server (connecting); blue `IO2` LED = mic clock, always on. [VERIFY colour map against `single_led.cc`]
- The RGB LED goes off in idle; the OLED face is the better state indicator.
- A second `start.sh` while one runs → `Errno 98`, harmless; the first instance keeps serving.
- `idf.py` exists only in the shell that sourced `export.sh`; the gauge terminal is plain bash.

## Sources
- Board monitor logs 2026-10-18 (`/tmp/oled-boot*.log`), server log `tmp/server.log` 2026-10-18 16:16 and 2026-10-19 14:26–14:30, operator meter reads and photos (INMP441 pad side, speaker back, amp front/back).
- Upstream: `78/xiaozhi-esp32` @ `ed5cd7b` (`main/boards/bread-compact-wifi/compact_wifi_board.cc`, `main/display/oled_display.cc`); `tny-robotics/sh1106-esp-idf` (`esp_lcd_panel_sh1106.c`); ESP-IDF `components/esp_lcd/i2c/esp_lcd_panel_io_i2c_v2.c`; espressif/esp-idf issue #14348.
- Repo `YokohamaAIart/AI_chatbot_esp32` @ `7650c0c` and later.
