# xiaozhi on Freenove ESP32-S3: handoff v1.2 (session close, next: CS decision + GC9A01 bring-up)

**Version:** 1.2 · **Date:** 2026-10-09 · **Host:** Perlinpinpin (Xubuntu 26.04.1, user `hackinblue`, LAN 192.168.1.6)
**Supersedes:** `freenove-s3-xiaozhi-handoff-v1_1.md`
**Companions:** `gc9a01-xiaozhi-firmware-params-v1.1.md` (every display/firmware knob + adjust kit) · `CLAUDE.md` for `~/xiaozhi-s3cam` (new) · project "ESP32 wonders"
**Status:** ⏳ Display wiring in progress, pin map verified against the firmware. ❌ CS-on-GPIO45 decision blocked: the eFuse read hit a locked port. ❌ Gate 1 (OTA URL in build) not run. ✅ Mic and amp unchanged since v1.1.
**Marks:** ✅ confirmed (source named) · ⚠️ inference / partial · ❌ insufficient data

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-10-07 | First issue. Mic defect open. |
| 1.1 | 2026-10-07 | Mic: dead module, replaced and verified. Ground reworked as a star. OTA URL fix staged in `config.json`. |
| 1.2 | 2026-10-09 | GC9A01 pin map verified against firmware @ `ed5cd7b`. **BL corrected: IO38 (PWM), not 3V3.** 3V3 Y-split for the display. GPIO45 strapping risk + eFuse decision gate. Port-lock cause and fix. espefuse needs `-a hard-reset`. **Gate 1 corrected:** the `CONFIG_OTA_URL` line is never missing. Params reference v1.1 and a repo `CLAUDE.md` added. |

---

## 1. Status at close

| Stage | State | Evidence |
|---|---|---|
| Mic (new INMP441) | ✅ | v1.1: I2S probe pass after final wiring |
| Amp | ✅ | v1.1 |
| Display pin map = firmware | ✅ | `config.h` l.57–62 · board `.cc` l.71–99, 200–202 @ `ed5cd7b` |
| GC9A01 wiring | ⏳ in progress | operator: 3V3 needs a second leg |
| GC9A01 BL/BLK pin present? | ❌ | silkscreen not read |
| CS on GPIO45 | ❌ undecided | `espefuse summary` → `Could not exclusively lock port /dev/ttyACM0` (operator paste) |
| OTA URL in build (Gate 1) | ❌ not run | no grep output received |
| Board → server | ❌ | v1.1 boot log: `api.tenclass.net:443`, `Activation: xiaozhi.me` |
| Server | ⚠️ last seen up | v1.1: PID 508430 on 8000/8003, Pocket TTS on 8090. Recheck with `ss -ltnp`. |
| Firmware parameter reference | ✅ | project `claude/gc9a01-xiaozhi-firmware-params-v1.1.md` |

---

## 2. Hardware as built

**Board:** Freenove ESP32-S3 WROOM, 16 MB flash, 8 MB PSRAM (`Embedded PSRAM 8MB (AP_3v3)`), MAC `20:6e:f1:aa:b5:6c`. Camera on its FPC (GPIO4–13, 15–18 reserved). microSD slot stays **empty**: it shares GPIO38/39/40 ✅ Freenove `Sketch_04.1` l.10–12.
**Port:** UART USB-C, CH343 → `/dev/ttyACM0` only.

### 2.1 Power and ground (USB unplugged for any change)
```
board GND ──┬── INMP441 GND
            ├── INMP441 L/R          (LEFT slot)
            ├── MAX98357A GND
            └── GC9A01 GND           ⏳ 5th leg: re-open the splice, add, heat-shrink, buzz

board 3V3 ──┬── INMP441 VDD
            └── GC9A01 VCC           ⏳ second leg: splice at the board pin

board 5V ────── MAX98357A VIN
```
Rule: no module's supply or ground return runs through another module. The display never taps the INMP441 VDD pad.

### 2.2 Signals

| Module pin | GPIO | Firmware define / note |
|---|---|---|
| INMP441 WS / SCK / SD | 1 / 2 / 42 | `AUDIO_I2S_MIC_GPIO_*` |
| MAX98357A DIN / BCLK / LRC | 39 / 40 / 41 | `AUDIO_I2S_SPK_GPIO_*` |
| MAX98357A GAIN / SD | floating | 9 dB · (L+R)/2. Never SD→GND (shuts the amp down). |
| GC9A01 SCL / SDA | 19 / 20 | `DISPLAY_CLK_PIN` / `DISPLAY_MOSI_PIN` |
| GC9A01 DC / RST | 47 / 21 | `DISPLAY_DC_PIN` / `DISPLAY_RST_PIN` |
| GC9A01 CS | 45 ⚠️ strapping pin, decided at Gate 0 | `DISPLAY_CS_PIN` |
| GC9A01 BL/BLK (if present) | 38 | `DISPLAY_BACKLIGHT_PIN`: PWM, active-high. Not 3V3 (v1.1 error). |

- Display bus: SPI3 at 40 MHz ✅ board `.cc` l.78, l.90. ⚠️ Keep SCL/SDA leads ≤ 10–15 cm.
- Spare if CS must move: **GPIO14** ✅ (`LAMP_GPIO` l.306 defined, unused).
- IO19/20 are the native-USB D−/D+: native USB is dead after boot. Expected.

---

## 3. Next session: gates, in order

### Gate 0: free the port, read the eFuse (before soldering CS)
```bash
. ~/esp/esp-idf/export.sh && cd ~/xiaozhi-s3cam
fuser -vk /dev/ttyACM0
python -m espefuse -p /dev/ttyACM0 -a hard-reset summary | grep -A2 'Flash voltage'
```
- **Lock:** errno 11 is pyserial failing to take an exclusive `flock` ✅ pyserial `serialposix.py` l.395–398. esptool and idf_monitor both open the port exclusive ✅ esptool `loader.py` l.456, esp-idf-monitor `idf_monitor.py` l.587. ⚠️ So the holder is a monitor or esptool still running elsewhere (another terminal, VS Code). `fuser -v` names it, `-k` frees the port.
- **`-a hard-reset`:** espefuse 5.4.0 defaults to `--after no-reset`, which leaves the chip in the ROM bootloader ✅ `espefuse/__init__.py` l.79–83, 166–168 @ v5.4.0.

| Output | Decision |
|---|---|
| `Flash voltage (VDD_SPI) set to 3.3V by efuse.` | Strap ignored → CS stays on GPIO45. |
| `Flash voltage (VDD_SPI) determined by GPIO45 on reset …` | Module unpowered, ohmmeter CS↔VCC. Open → CS stays on 45 (GPIO45 low/NC at reset = 3.3 V flash ✅ espefuse string). ⚠️ kΩ range = pull-up → move CS to GPIO14: `pin DISPLAY_CS_PIN GPIO_NUM_14` (params §1) + wire CS to 14. |

✅ Strings: espefuse `esp32s3/fields.py` l.262–272 @ v5.4.0, printed by `summary` (`base_operations.py` l.833).

### Gate 1: build state (corrected from v1.1 §3)
```bash
grep -nE 'OTA_URL|GC9A01' main/boards/bread-compact-wifi-s3cam/config.json sdkconfig
```
- **Pass:** `sdkconfig` shows `CONFIG_OTA_URL="http://192.168.1.6:8003/xiaozhi/ota/"` and `CONFIG_LCD_GC9A01_240X240=y`.
- **Fail:** `sdkconfig` shows `CONFIG_OTA_URL="https://api.tenclass.net/xiaozhi/ota/"`. That is the Kconfig default ✅ `Kconfig.projbuild` l.3–5, so the line is never missing (the v1.1 comment was wrong). Fix: set the array in `config.json` to exactly this:
  ```json
  "sdkconfig_append": [
      "CONFIG_LCD_GC9A01_240X240=y",
      "CONFIG_OTA_URL=\"http://192.168.1.6:8003/xiaozhi/ota/\""
  ]
  ```
  Then run the build below and rerun the grep:
  ```bash
  python scripts/build.py bread-compact-wifi-s3cam --language en-US --wake-word wn9_jarvis_tts
  ```
- No NVS override in play: the v1.1 full flash erased NVS, so the compiled URL applies ✅ `ota.cc` l.48–55.

### Gate 2: wire the display (USB unplugged)
§2.1 legs + §2.2 table. Buzz each joint module→header, then check adjacent pairs for shorts.

### Gate 3: flash, boot, server
```bash
# server first, clean terminal (no IDF env)
WS002_IP=127.0.0.1 bash ~/projects/xiaozhi-e32r28t/server/start.sh
# board terminal
idf.py -p /dev/ttyACM0 app-flash monitor      # Ctrl+T then Ctrl+X to exit
```
**Pass:**
- boot log connects to `192.168.1.6:8003`, not `api.tenclass.net`
- server log shows `OTA请求设备ID: 20:6e:f1:aa:b5:6c`
- display lights up with the UI

### Gate 4: display check
UI upright, colours right? If not, use params v1.1 §3, then `app-flash monitor`:
- turned or mirrored → `rot 90|180|270`
- negative colours → `gc DISPLAY_INVERT_COLOR false`
- red/blue swapped → `gc DISPLAY_RGB_ORDER LCD_RGB_ELEMENT_ORDER_RGB`
- noise or torn pixels → `spi 20`

Brightness by voice: tool `self.screen.set_brightness` 0–100 ✅ `mcp_server.cc` l.62–72. ❌ Untested with ZaiGLMLLM.

### Gate 5: acceptance
"Jarvis" + a question → server ASR line → spoken reply.

---

## 4. Tooling & gotchas
- **Port lock:** `fuser -vk /dev/ttyACM0` (cause: Gate 0). ⚠️ A killed monitor can leave its terminal without echo: type `reset` there.
- **espefuse** leaves the chip in the bootloader unless `-a hard-reset` is given ✅ (Gate 0).
- **Exit idf_monitor on AZERTY:** `Ctrl+T` then `Ctrl+X`.
- **`idf.py app-flash`** rebuilds the app first and keeps NVS ✅ ESP-IDF `serial_ext.py` l.1211–1216. `erase-flash` or a full `write-flash 0x0 merged-binary.bin` wipes NVS (Wi-Fi, runtime OTA URL, brightness).
- **build.py** regenerates `sdkconfig` from `config.json` on every run ✅ `build.py` l.1428–1457. Edit `config.json`, never `sdkconfig` or menuconfig.
- **Adjust kit** (`gc rot pin spi pwm bri kc`): params v1.1 §1. Undo: `git checkout --` on the touched files.
- **Terminals:** IDF env only in board terminals. The server runs in its own clean terminal; closing it stops the server.
- **Mic probe:** `cd ~/mic-probe && idf.py -p /dev/ttyACM0 flash monitor`, then return to xiaozhi with `app-flash`.
- **Status LED GPIO48 map:** v1.0 §6.
- Unrelated, open: `meshtasticd` daily build possibly on this box → `apt policy meshtasticd`.

---

## 5. Track B: round-display play (carried from v1.1 §5.3)

| Idea | Why it suits a round panel |
|---|---|
| **Animated eye** (iris, pupil, blinks, saccades) | the panel *is* an eyeball |
| **Mic-reactive eye**: pupil dilates with sound level | reuses the probe's dBFS meter |
| Attention eye | ⚠️ needs 2 mics for direction; 1 mic = loudness only |
| Radar sweep · analog gauge · clock | circular by nature |
| xiaozhi state face (idle / listening / speaking) | replaces the stock emoji UI |

- Libraries: ⚠️ none verified on this board. LovyanGFX, or esp_lcd + LVGL (what xiaozhi already uses).
- Separate project, same pins. Swap firmware with `idf.py flash`, return to xiaozhi with `app-flash`; NVS stays.
- ⚠️ Flash budget: the xiaozhi image is 9.6 MB of 16 MB (v1.1).
- Original artwork only, no known characters.

---

## 6. Open items
- ❌ GC9A01 silkscreen: BL/BLK present? Present → IO38; absent → `pin DISPLAY_BACKLIGHT_PIN GPIO_NUM_NC`.
- ❌ CS pin (Gate 0) · ❌ OTA URL build (Gate 1).
- ❌ DHCP reservation for 192.168.1.6: open since v1.0 and now compiled into the firmware OTA URL.
- Long-term (separate thread): portable **offline** voice LLM needs a Pi-class box; the S3 build is the satellite (v1.1).

---

## 7. Opening prompt for the next session

> Attach `freenove-s3-xiaozhi-handoff-v1.2.md`. "Session: Freenove S3 xiaozhi, GC9A01 bring-up. Run §3 in order: Gate 0 eFuse read (CS stays on 45 or moves to 14), Gate 1 OTA URL build state, Gate 2 wiring, Gate 3 app-flash + server, Gate 4 display check with the params v1.1 adjust kit, Gate 5 Jarvis acceptance. Then Track B. Same gate style: one step, one read, no improvised fixes."

---

## 8. Cheat sheet
```bash
# server (clean terminal)
WS002_IP=127.0.0.1 bash ~/projects/xiaozhi-e32r28t/server/start.sh
ss -ltnp | grep -E ':(8000|8003|8090)\b'
tail -f ~/xiaozhi-esp32-server/main/xiaozhi-server/tmp/server.log

# board (IDF terminal)
. ~/esp/esp-idf/export.sh && cd ~/xiaozhi-s3cam
fuser -vk /dev/ttyACM0                                    # free a locked port
python -m espefuse -p /dev/ttyACM0 -a hard-reset summary | grep -A2 'Flash voltage'
grep -nE 'OTA_URL|GC9A01' main/boards/bread-compact-wifi-s3cam/config.json sdkconfig
python scripts/build.py bread-compact-wifi-s3cam --language en-US --wake-word wn9_jarvis_tts
idf.py -p /dev/ttyACM0 app-flash monitor                  # Ctrl+T Ctrl+X to exit
cd ~/mic-probe && idf.py -p /dev/ttyACM0 flash monitor    # mic health check
```

## Sources
- [xiaozhi-esp32 @ ed5cd7b, board folder](https://github.com/78/xiaozhi-esp32/tree/ed5cd7ba0011dc06fefd0762790857268c41b430/main/boards/bread-compact-wifi-s3cam)
- [esptool v5.4.0: espefuse](https://github.com/espressif/esptool/tree/v5.4.0/espefuse)
- [pyserial serialposix.py](https://github.com/pyserial/pyserial/blob/master/serial/serialposix.py)
- [esp-idf-monitor](https://github.com/espressif/esp-idf-monitor)
- [ESP32-S3 hardware design guidelines: schematic checklist](https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32s3/schematic-checklist.html)
- [Freenove ESP32-S3 WROOM board repo](https://github.com/Freenove/Freenove_ESP32_S3_WROOM_Board)
- Every other value: `gc9a01-xiaozhi-firmware-params-v1.1.md` sources.
