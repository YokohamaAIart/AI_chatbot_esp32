# xiaozhi on Freenove ESP32-S3: handoff v1.4 (display swapped to SH1106 OLED; wiring verified on bench)

**Version:** 1.4 · **Date:** 2026-10-18 · **Host:** Perlinpinpin (Xubuntu 26.04.1, user `hackinblue`, LAN 192.168.1.6)
**Supersedes:** `freenove-s3-xiaozhi-handoff-v1.3.md` · **Companions:** `freenove-s3-wiring-diagram-v0.7.pdf` (VERIFIED) · `s3cam-oled-i2c-v0.1.patch` · `tools/wiring-diagram/` (skill) · `~/xiaozhi-s3cam/CLAUDE.md`
**Marks:** ✅ confirmed (source named) · ⚠️ inference · ❌ insufficient data · ⏳ pending

| Version | Date | Change |
|---|---|---|
| 1.3 | 2026-10-10 | Voice chain traced; TTS SIGILL fixed; language template cause found, fix untested. |
| 1.4 | 2026-10-18 | GC9A01 dropped for SH1106 1.3″ I²C OLED. Wiring diagram v0.7 verified pin by pin on hardware. Speaker replaced after an open coil and a solder-bridge short. Firmware tree moved back to `~/xiaozhi-s3cam` (space in path breaks the link step). OLED patch applied; build/flash in progress at close. |

---

## 1. Status at close

| Stage | State | Evidence |
|---|---|---|
| Display choice | ✅ SH1106 128×64 I²C, GC9A01 shelved | operator decision 2026-10-17 ("OLED is fixed and matching better the application") |
| Wiring, all modules | ✅ VERIFIED v0.7 | silkscreens read on hardware (amp, OLED 10-17; INMP441 photo 10-18); unpowered reads 10-18: 3V3↔GND OL, 5V↔GND OL, all amp adjacent pairs OL, OUT+↔OUT− 7.5 Ω |
| Speaker | ✅ replaced | original XHXDZ 8 Ω 2 W: open coil (OL on 200 Ω range, leads 0.2). Replacement: marking not read; soldered through the amp's terminal-block holes after the block was removed (⊕ left, ⊖ right as silkscreened) |
| Firmware OLED support | ✅ patch applied, ⏳ untested | `s3cam-oled-i2c-v0.1.patch` on `4c09662` (branch `freenove-s3`): `M main/Kconfig.projbuild`, `M …/compact_wifi_board_s3cam.cc`, `M …/config.h`; `config.json` sdkconfig_append = `CONFIG_S3CAM_DISPLAY_OLED_I2C=y`, `CONFIG_OLED_SH1106_128X64=y`, OTA URL |
| Build | ⏳ running at close | full rebuild from clean `build/` at `~/xiaozhi-s3cam` |
| Gate 4: OLED lights, `OLED 128x64 on I2C port 1` in log | ⏳ | — |
| Gate 5: spoken French reply | ⏳ unchanged from v1.3 | server-side language fix still untested |

## 2. Bench findings 2026-10-18

### 2.1 Speaker open — replaced ✅
- Thin factory leads; black one broke. Re-soldering thicker wire on the speaker pads: coil measured OL after the repair (tips-together 0.2 Ω) → coil or pad lead gone. Replaced.
- Rule kept: meter the coil (6–8 Ω) **before** soldering any speaker; strain-relieve the cable to the frame, never to the pad.

### 2.2 OUT+↔OUT− short — found and cleared ✅
- Read: 0.2 Ω across the amp output with the speaker wire removed; OUT+↔VIN OL, OUT+↔GND OL, VIN↔GND OL → metallic bridge between the two output pins only.
- Cause ✅ (photo): a strand of the thin speaker wire lying across the two solder blobs on the terminal-block pins, plus solder creep into the corner mounting pad.
- Fix: terminal block removed, both holes wicked clean, wires soldered through the holes from the top. Re-read 7.5 Ω with the speaker attached.

### 2.3 Firmware tree path ✅
- Tree had been moved to `~/Documents/Microcontrolers/Xiao Zhi/xiaozhi-s3cam`. Two failures followed: (a) stale `build/` carrying the old absolute path (`cannot read spec file …/xiaozhi-s3cam/build/specs/picolibc.specs`); (b) after `rm -rf build`, link step failed — `espressif__esp_audio_codec` and `espressif__esp_image_effects` pass `-L <path>` unquoted, so the space in `Xiao Zhi` splits the argument (`ld: cannot find Zhi/xiaozhi-s3cam/…`).
- Fix: `mv` back to `~/xiaozhi-s3cam`, `rm -rf build`, rebuild. **The firmware tree must stay on a path without spaces.** `CLAUDE.md`'s `~/xiaozhi-s3cam` is correct again.

### 2.4 INMP441 silkscreen (for `references/modules.md`) ✅
- Round breakout, pad side, 2×3: row `L/R · WS · SCK` (labels upright) / row `GND · VDD · SD` (labels printed rotated 180°). Columns pair L/R–GND, WS–VDD, SCK–SD. Mic port on the other face.

## 3. Next session, in order
1. If the build/flash did not complete: `~/xiaozhi-s3cam`, IDF env, `idf.py -p /dev/ttyACM0 app-flash monitor 2>&1 | tee /tmp/oled-boot.log`.
2. **Gate 4** read: `grep -aE 'OLED|I2C|SH1106|panel' /tmp/oled-boot.log | head`. Pass = `OLED 128x64 on I2C port 1` and the display shows the boot/idle face.
   - Log line present, screen dark → OLED VCC 3.3 V at the module pin under power; SDA/SCL 47/21 continuity to the header.
   - I²C error / no device at 0x3C → address 0x3D variant: `i2cdetect`-style probe is not available on the board; swap the address in `config.h` and reflash.
   - Patch compile error → fix in `compact_wifi_board_s3cam.cc`, bump patch to v0.2 in the docs repo.
3. **Gate 5** exactly as v1.3 §3: clean server start (`fuser -k 8000/tcp 8003/tcp 8090/tcp`), "Jarvis" + French question, `grep -aE '识别文本|发送第一段|语音生成' …/tmp/server.log | tail -n 4`, audible French reply.
4. Commit on `freenove-s3` after each passed gate; push docs repo only when told.

## 4. Gotchas added
- **No spaces in the firmware tree path** (§2.3). Docs clone can stay under `Xiao Zhi`; the firmware cannot.
- **`rm -rf build` after any move of the tree** — the build dir bakes absolute paths.
- **Bracketed paste**: `bind 'set enable-bracketed-paste off'` at the top of each bench terminal kills the `^[[200~` garbage.
- **`idf.py` only in the terminal that sourced `export.sh`**; a second "gauge" terminal is plain bash: `tail -f /tmp/build.log | grep --line-buffered -oE '^\[[0-9]+/[0-9]+\]'`.
- **Unpowered short test is the gate before every power-up** (200 Ω range: rails to GND, module adjacent pairs, amp OUT+↔OUT−). It caught a bridge that would have shut the MAX98357A down at first sound.

## Sources
- Operator photos 2026-10-18 (INMP441 pad side, speaker back, amp terminal pins front/back); meter reads reported in session.
- Build logs pasted 2026-10-18: cmake spec-file error; ld `-L` split error.
- Repo `YokohamaAIart/AI_chatbot_esp32` @ `41e98fb` (`docs/xiaozhi-freenove-s3/`, `tools/wiring-diagram/`).
