# CLAUDE.md: ~/xiaozhi-s3cam (xiaozhi on Freenove ESP32-S3)

v1.3 · 2026-10-09 · Current state and next gates: `freenove-s3-xiaozhi-handoff-v1.2.md` · Every display/firmware knob: `gc9a01-xiaozhi-firmware-params-v1.1.md` · both in `~/Documents/Microcontrolers/Xiao Zhi/docs/xiaozhi-freenove-s3/`

## Versioning
- Docs: `~/Documents/Microcontrolers/Xiao Zhi/docs/` (project folder, local). A new doc version is a new `-vX.Y` file saved there. The folder gets its git repo and a GitHub backup (`YokohamaAIart/AI_chatbot_esp32`) only after it is cleaned and checked: no git commands there until then.
- This tree: local branch `freenove-s3` on top of upstream `ed5cd7b`. Commit after each passed gate. Never push.
- All local changes vs upstream: `git diff ed5cd7b --stat`.

## Repo
- `78/xiaozhi-esp32` @ `ed5cd7b` (fw 2.5.1). Board type `bread-compact-wifi-s3cam`, target esp32s3.
- Local edits belong only in `main/boards/bread-compact-wifi-s3cam/` (`config.json`, `config.h`, `compact_wifi_board_s3cam.cc`) and `main/boards/common/backlight.cc` (boot brightness default). Run `git status` before touching anything else.
- `config.json` → `sdkconfig_append`: `CONFIG_LCD_GC9A01_240X240=y` + `CONFIG_OTA_URL="http://192.168.1.6:8003/xiaozhi/ota/"`. The OTA line is unverified until handoff Gate 1 passes.
- `scripts/build.py` regenerates `sdkconfig` from `config.json` on every run. Never edit `sdkconfig` or use menuconfig for persistent changes.

## Toolchain
- ESP-IDF v6.1 at `~/esp/esp-idf`, esptool 5.4.0. Every board terminal: `. ~/esp/esp-idf/export.sh && cd ~/xiaozhi-s3cam`.
- Never start the xiaozhi server from a shell with the IDF env exported.

## Commands

| Task | Command |
|---|---|
| Build | `python scripts/build.py bread-compact-wifi-s3cam --language en-US --wake-word wn9_jarvis_tts` |
| Flash app (rebuilds first, keeps NVS) | `idf.py -p /dev/ttyACM0 app-flash monitor` |
| Exit monitor (AZERTY) | `Ctrl+T` then `Ctrl+X` (`Ctrl+]` / `Ctrl+C` don't exit) |
| Port locked | `fuser -vk /dev/ttyACM0` |
| eFuse summary | `python -m espefuse -p /dev/ttyACM0 -a hard-reset summary` (default `no-reset` leaves the chip in the bootloader) |

- Never run `erase-flash` or `write-flash 0x0 build/merged-binary.bin` unless asked. They wipe NVS (Wi-Fi, runtime OTA URL, brightness).
- Serial: UART USB-C (CH343) → `/dev/ttyACM0` only. GPIO19/20 carry the LCD SPI bus, so native USB is dead after boot.

## Hardware (pins = `config.h` @ `ed5cd7b`)

| Function | GPIO |
|---|---|
| INMP441 WS / SCK / SD | 1 / 2 / 42 (L/R → GND, left slot) |
| MAX98357A DIN / BCLK / LRC | 39 / 40 / 41 (VIN 5 V, GAIN and SD floating) |
| GC9A01 CLK / MOSI / DC / RST / CS / BL | 19 / 20 / 47 / 21 / 45 / 38 (SPI3, 40 MHz) |
| Camera (FPC) | 4–13, 15–18: reserved |
| Status LED / BOOT button | 48 / 0 |
| Free | 14 (clean) · 3 and 46 (strapping) |

- microSD slot stays empty: it shares GPIO38/39/40.
- Power: GND star at the board's single GND pin. 3V3 Y-split to INMP441 VDD and GC9A01 VCC. All wiring changes with USB unplugged.
- GPIO45 (display CS) is a strapping pin. Whether CS stays there is decided by the eFuse read (handoff Gate 0).

## Server (Perlinpinpin, 192.168.1.6)
- Start in its own clean terminal: `WS002_IP=127.0.0.1 bash ~/projects/xiaozhi-e32r28t/server/start.sh`. Closing that terminal stops the server.
- Ports: 8000 WebSocket · 8003 OTA · 8090 Pocket TTS (loopback). Check with `ss -ltnp | grep -E ':(8000|8003|8090)\b'`.
- Log: `~/xiaozhi-esp32-server/main/xiaozhi-server/tmp/server.log`. Device MAC `20:6e:f1:aa:b5:6c`.

## Working rules
- Gate style: one step, one read, no improvised fixes.
- Mic health check: `cd ~/mic-probe && idf.py -p /dev/ttyACM0 flash monitor`, then return to xiaozhi with `app-flash`.
