# GC9A01 round display · xiaozhi on Freenove S3: firmware parameter reference

**v1.1 · 2026-10-09** · `78/xiaozhi-esp32 @ ed5cd7b` · ESP-IDF v6.1 · `esp_lcd_gc9a01` 2.0.4 · esptool 5.4.0 · board `bread-compact-wifi-s3cam`
**Companion to:** `freenove-s3-xiaozhi-handoff-v1.2.md`
**Marks:** ✅ read this session (source named) · ⚠️ inference · ❌ insufficient data

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-10-09 | First issue. |
| 1.1 | 2026-10-09 | §6: port-lock step, `-a hard-reset`, decision table. espefuse strings confirmed in 5.4.0. §1: port-busy row. |

## 1. Adjust kit (paste once per IDF terminal)

```bash
. ~/esp/esp-idf/export.sh && cd ~/xiaozhi-s3cam
B=main/boards/bread-compact-wifi-s3cam
gc()  { sed -i "/^#ifdef CONFIG_LCD_GC9A01_240X240/,/^#endif/ s/^\(#define $1[[:space:]]\+\).*/\1$2/" $B/config.h; sed -n "/^#ifdef CONFIG_LCD_GC9A01_240X240/,/^#endif/p" $B/config.h | grep -w "$1"; }
rot() { case $1 in 0) set -- true false false;; 90) set -- false false true;; 180) set -- false true false;; 270) set -- true true true;; *) echo "rot 0|90|180|270"; return 1;; esac; gc DISPLAY_MIRROR_X $1; gc DISPLAY_MIRROR_Y $2; gc DISPLAY_SWAP_XY $3; }
pin() { sed -i "s/^\(#define $1[[:space:]]\+\).*/\1$2/" $B/config.h; grep "^#define $1[[:space:]]" $B/config.h; }
spi() { sed -i "s/pclk_hz = [0-9]\+ \* 1000 \* 1000/pclk_hz = $1 * 1000 * 1000/" $B/compact_wifi_board_s3cam.cc; grep -n pclk_hz $B/compact_wifi_board_s3cam.cc; }
pwm() { sed -i "s/DISPLAY_BACKLIGHT_OUTPUT_INVERT[^)]*);/DISPLAY_BACKLIGHT_OUTPUT_INVERT, $1);/" $B/compact_wifi_board_s3cam.cc; grep -n 'PwmBacklight backlight' $B/compact_wifi_board_s3cam.cc; }
bri() { sed -i "s/GetInt(\"brightness\", [0-9]\+)/GetInt(\"brightness\", $1)/" main/boards/common/backlight.cc; grep -n 'GetInt("brightness"' main/boards/common/backlight.cc; }
kc()  { python3 -c 'import json,sys;p,k,v=sys.argv[1:];d=json.load(open(p));a=d["builds"][0]["sdkconfig_append"];a[:]=[x for x in a if x.split("=",1)[0]!=k]+[k+"="+v];open(p,"w").write(json.dumps(d,indent=4)+"\n");print(*a,sep="\n")' $B/config.json "$1" "$2"; }
```

Each helper prints the line it changed. ✅ Tested on copies of the upstream files: `gc` only touches the GC9A01 block, `kc` gives the same result if run twice, `rot 0` restores upstream.

| After | Apply |
|---|---|
| `gc` `rot` `pin` `spi` `pwm` `bri` | `idf.py -p /dev/ttyACM0 app-flash monitor`. Rebuilds the app first ✅ `serial_ext.py` l.1211–1216; NVS kept. |
| `kc` | `python scripts/build.py bread-compact-wifi-s3cam --language en-US --wake-word wn9_jarvis_tts && idf.py -p /dev/ttyACM0 app-flash monitor`. build.py regenerates `sdkconfig` from config.json on every run ✅ `build.py` l.1428–1457, so `menuconfig` edits don't survive. |
| Port busy (`Could not exclusively lock port`) | `fuser -vk /dev/ttyACM0` (cause: §6) |
| Review / undo | `git diff --stat` · `git checkout -- $B/config.h $B/compact_wifi_board_s3cam.cc main/boards/common/backlight.cc` (leaves config.json alone) |

## 2. Pins: `config.h` l.57–62

| Define | Now = Rec | `GPIO_NUM_NC` allowed | Move to |
|---|---|---|---|
| `DISPLAY_CLK_PIN` | `GPIO_NUM_19` | no | 14 |
| `DISPLAY_MOSI_PIN` | `GPIO_NUM_20` | no | 14 |
| `DISPLAY_DC_PIN` | `GPIO_NUM_47` | no: 4-wire module | 14 |
| `DISPLAY_RST_PIN` | `GPIO_NUM_21` | yes: the driver sends a software reset ✅ `esp_lcd_gc9a01.c`; module RST then goes to 3V3 | 14 |
| `DISPLAY_CS_PIN` | `GPIO_NUM_45`, see §6 | only if the module ties CS to GND | 14 |
| `DISPLAY_BACKLIGHT_PIN` | `GPIO_NUM_38` if the module has BL/BLK · `GPIO_NUM_NC` if not | yes: no PWM, and the brightness tool is not registered ✅ board `.cc` l.200–206, `mcp_server.cc` l.62–72 | 14 |

- **Spare GPIOs on this build:**
  - GPIO14 is the only clean one: `LAMP_GPIO` (l.306) is defined but never used ✅ board `.cc`.
  - GPIO3 and GPIO46 are free but are strapping pins ✅ ESP-IDF S3 GPIO table.
  - Everything else is taken in `config.h` or reserved: GPIO26–37 for flash/PSRAM ✅ S3 GPIO table, GPIO43/44 for the console UART ✅ `uart_pins.h`.
- GPIO38 is also the microSD CMD line ✅ Freenove `Sketch_04.1` l.10. The slot stays empty.
- Example: `pin DISPLAY_CS_PIN GPIO_NUM_14`, after rewiring with USB unplugged.

## 3. Panel block: `config.h` l.275–288 (`#ifdef CONFIG_LCD_GC9A01_240X240`)

| Define | Now | Range | Rec | Change when | Command |
|---|---|---|---|---|---|
| `DISPLAY_WIDTH` / `_HEIGHT` | 240 / 240 | fixed | 240 | never | — |
| `DISPLAY_MIRROR_X` | true | true / false | true | text mirrored left↔right | `gc DISPLAY_MIRROR_X false` |
| `DISPLAY_MIRROR_Y` | false | true / false | false | mirrored top↔bottom | `gc DISPLAY_MIRROR_Y true` |
| `DISPLAY_SWAP_XY` | false | true / false | false | image turned 90° | `rot 90` or `rot 270` |
| `DISPLAY_INVERT_COLOR` | true | true / false | true | negative colours | `gc DISPLAY_INVERT_COLOR false` |
| `DISPLAY_RGB_ORDER` | `LCD_RGB_ELEMENT_ORDER_BGR` | `…_RGB` / `…_BGR` | BGR | red↔blue swapped | `gc DISPLAY_RGB_ORDER LCD_RGB_ELEMENT_ORDER_RGB` |
| `DISPLAY_OFFSET_X` / `_Y` | 0 / 0 | 0 only | 0 | never | — |
| `DISPLAY_BACKLIGHT_OUTPUT_INVERT` | false | true / false | false | BL wired, screen dark at 100 % and lit at 0 % | `gc DISPLAY_BACKLIGHT_OUTPUT_INVERT true` |
| `DISPLAY_SPI_MODE` | 0 | 0–3 | 0 | never: mode 3 is for modules without CS (l.167) | `gc DISPLAY_SPI_MODE 3` |

- ✅ In `esp_lcd_gc9a01.c` 2.0.4, MIRROR_X sets the panel's MX bit, MIRROR_Y sets MY, SWAP_XY sets MV, INVERT switches INVON/INVOFF, and RGB_ORDER sets the BGR bit.
- ✅ Offsets are passed to `lv_display_set_offset` (`lcd_display.cc` l.210). The panel's RAM is exactly 240×240 (GC9A01A datasheet §1), so any offset pushes part of the image off the glass.
- ✅ SPI mode 0–3: `esp_lcd_io_spi.h` l.25.

**Rotation:** `rot N` sets all three defines at once.

| `rot` | MIRROR_X | MIRROR_Y | SWAP_XY |
|---|---|---|---|
| 0 (upstream) | true | false | false |
| 90 | false | false | true |
| 180 | false | true | false |
| 270 | true | true | true |

⚠️ 180 is exact: both mirrors flipped. Whether 90 or 270 is clockwise depends on how the panel is mounted. If `rot 90` turns the wrong way, use `rot 270`.

## 4. SPI clock and backlight

| Parameter | Now | Low | High | Rec | Command |
|---|---|---|---|---|---|
| `io_config.pclk_hz` (board `.cc` l.90) | 40 MHz | ⚠️ 10 MHz practical | 80 MHz | 40; 20 if you see noise or torn pixels | `spi 20` |
| Brightness at runtime (NVS `display/brightness`) | 75 | 0 = off (a stored 0 boots at 10) | 100 (clamped) | 75 | by voice: "set screen brightness to 40" |
| Brightness boot default (`backlight.cc` l.35) | 75 | 1 | 100 | 75 | `bri 60` |
| Backlight PWM frequency (`PwmBacklight` 3rd argument) | 25 kHz | ⚠️ 20 kHz | ⚠️ 78 kHz | 25 kHz | `pwm 25000` |

**SPI clock**
- **Valid steps:** 80 MHz APB ÷ n, so 80 · 40 · 26.7 · 20 · 16 · 13.3 · 11.4 · 10 MHz. Any other value snaps to the nearest step ✅ `clk_tree_defs.h` l.362, `soc.h` l.151, `spi_master.rst` l.592.
- **Panel ceiling:** 100 MHz (write cycle ≥ 10 ns) ✅ GC9A01A datasheet Table 48. The panel is not the limit.
- **Chip ceiling on these pins:**
  - The display runs on SPI3 (board `.cc` l.78). On the S3, only SPI2 has dedicated fast-path (IO_MUX) pins, so the display signals go through the GPIO-matrix routing.
  - ESP-IDF v6.1 only guarantees the GPIO-matrix route behaves like the fast path at ≤ 40 MHz ✅ `spi_master.rst` l.520.
  - 80 MHz is the default in Espressif's own GC9A01 driver ✅ `esp_lcd_gc9a01.h` l.98, but it is outside that guarantee.
- **Full-screen redraw** (240 × 240 × 16 bit = 921,600 bit), computed: 80 MHz → 11.5 ms · 40 → 23.0 ms · 20 → 46.1 ms · 10 → 92.2 ms.

**Brightness**
- Duty = 1023 × brightness ÷ 100 (10-bit LEDC). Changes fade at 1 % per 5 ms ✅ `backlight.cc` l.61–65, l.115–118.
- The voice path is the device tool `self.screen.set_brightness`, 0–100, saved to NVS ✅ `mcp_server.cc` l.62–72. ❌ Not tested: whether ZaiGLMLLM on your server calls this tool.
- `bri` sets the value used when NVS holds no brightness. On this board only the voice tool writes that key ✅ `backlight.cc` l.35, l.55–58; `mcp_server.cc` l.69. After `erase-flash`, the compiled value applies again.

**PWM**
- 10-bit LEDC with automatic clock selection (XTAL / APB / RC_FAST) ✅ `backlight.cc` l.85–90, `clk_tree_defs.h` l.462.
- ⚠️ High = 80 MHz ÷ 1024 = 78.1 kHz, from the documented frequency/resolution trade-off (`ledc.rst` l.64).
- ⚠️ Low = 20 kHz, the top of the audible range. The code comment warns that lower frequencies make the inductor whine ✅ `backlight.cc` l.89.
- Only matters if the module has a BL pin.

## 5. Kconfig options: `config.json`, then build.py

| Option | Now | Values | Rec | Command |
|---|---|---|---|---|
| `CONFIG_LCD_GC9A01_240X240` | y | one of 17 `LCD_*` choices ✅ `Kconfig.projbuild` l.743–783 | y | none: panel fixed |
| `CONFIG_OTA_URL` | handoff Gate 1 read | any http(s) URL; default `https://api.tenclass.net/xiaozhi/ota/` ✅ `Kconfig.projbuild` l.3–5 | `http://192.168.1.6:8003/xiaozhi/ota/` | `kc CONFIG_OTA_URL '"http://192.168.1.6:8003/xiaozhi/ota/"'` |

A URL saved in NVS `wifi/ota_url` (portal → Advanced, E32R28T handoff §4) overrides the compiled value ✅ `ota.cc` l.48–55. It survives `app-flash` and is lost on `erase-flash`.

## 6. CS on GPIO45: the read that settles it

```bash
fuser -vk /dev/ttyACM0
python -m espefuse -p /dev/ttyACM0 -a hard-reset summary | grep -A2 'Flash voltage'
```

- **`fuser -vk`** names and kills whatever holds the port's exclusive lock. `Could not exclusively lock port … [Errno 11]` is pyserial failing to take `flock` ✅ `serialposix.py` l.395–398. esptool and idf_monitor both take that lock ✅ esptool `loader.py` l.456, esp-idf-monitor `idf_monitor.py` l.587.
- **`-a hard-reset`** reboots the chip after the read. espefuse 5.4.0 defaults to `no-reset`, which leaves it in the ROM bootloader ✅ `espefuse/__init__.py` l.79–83, l.166–168 @ v5.4.0.

| Output | Decision |
|---|---|
| `Flash voltage (VDD_SPI) set to 3.3V by efuse.` | The strap is ignored: CS stays on 45. |
| `Flash voltage (VDD_SPI) determined by GPIO45 on reset …` | Module unpowered, ohmmeter CS↔VCC. Open → CS stays on 45 (GPIO45 low/NC at reset = 3.3 V flash, per the same espefuse text). ⚠️ kΩ range = pull-up → `pin DISPLAY_CS_PIN GPIO_NUM_14` + rewire. |

✅ Strings: espefuse `esp32s3/fields.py` l.262–272 @ v5.4.0, printed by `summary` (`base_operations.py` l.833).

## Sources
- [xiaozhi-esp32 @ ed5cd7b, board folder](https://github.com/78/xiaozhi-esp32/tree/ed5cd7ba0011dc06fefd0762790857268c41b430/main/boards/bread-compact-wifi-s3cam)
- [esp_lcd_gc9a01 (esp-bsp)](https://github.com/espressif/esp-bsp/tree/master/components/lcd/esp_lcd_gc9a01)
- [ESP-IDF v6.1 SPI master doc](https://github.com/espressif/esp-idf/blob/v6.1/docs/en/api-reference/peripherals/spi_master.rst) · [S3 GPIO table](https://github.com/espressif/esp-idf/blob/v6.1/docs/en/api-reference/peripherals/gpio/esp32s3.inc) · [LEDC doc](https://github.com/espressif/esp-idf/blob/v6.1/docs/en/api-reference/peripherals/ledc.rst)
- [GC9A01A datasheet (Waveshare)](https://files.waveshare.com/wiki/common/GC9A01A.pdf)
- [esptool v5.4.0: espefuse](https://github.com/espressif/esptool/tree/v5.4.0/espefuse)
- [pyserial serialposix.py](https://github.com/pyserial/pyserial/blob/master/serial/serialposix.py) · [esp-idf-monitor](https://github.com/espressif/esp-idf-monitor)
- [Freenove ESP32-S3 WROOM board repo](https://github.com/Freenove/Freenove_ESP32_S3_WROOM_Board)
