# Quick Reference — xiaozhi · Freenove ESP32-S3

**v1.0 · 2026-10-19** · host Perlinpinpin (`hackinblue`, 192.168.1.6) · board on `/dev/ttyACM0` (UART USB-C)

### Server (plain terminal, no IDF env — leave it open)
```bash
ss -ltnp | grep -E ':(8000|8003|8090)\b' || echo "server down"
fuser -k 8000/tcp 8003/tcp 8090/tcp 2>/dev/null; sleep 2
WS002_IP=127.0.0.1 bash ~/projects/xiaozhi-e32r28t/server/start.sh     # wait: TTS -> PocketTTS, then banner
```

### Firmware (IDF terminal)
```bash
. ~/esp/esp-idf/export.sh && cd ~/xiaozhi-s3cam && bind 'set enable-bracketed-paste off'
python scripts/build.py bread-compact-wifi-s3cam --language en-US --wake-word wn9_jarvis_tts
idf.py -p /dev/ttyACM0 app-flash monitor 2>&1 | tee /tmp/boot.log     # build + flash app + reset + log
idf.py -p /dev/ttyACM0 monitor                                        # log only
```
Exit monitor `Ctrl+T` `Ctrl+X` · port stuck `fuser -vk /dev/ttyACM0` · second terminal gauge `tail -f /tmp/build.log | grep --line-buffered -oE '^\[[0-9]+/[0-9]+\]'`

### Talk / verify
```
"Jarvis" + question      or short-press BOOT
grep -aE '识别文本|发送第一段|语音生成' ~/xiaozhi-esp32-server/main/xiaozhi-server/tmp/server.log | tail -n 4
grep -aE 'OLED|OV5640|Got IP|Ota|State:|flush lost|E \(' /tmp/boot.log | head -30
"What is your speaker volume?"   "Set the volume to 80."
```

### Key files
```
~/xiaozhi-s3cam/main/boards/bread-compact-wifi-s3cam/config.json   build knobs (sdkconfig_append)
~/xiaozhi-s3cam/main/boards/bread-compact-wifi-s3cam/config.h      pins, OLED port/mirror
~/xiaozhi-s3cam/main/display/oled_display.cc                       LVGL flush guard (patch v0.3)
~/xiaozhi-esp32-server/main/xiaozhi-server/data/.config.yaml       LLM/ASR/TTS, language:, timezone
~/xiaozhi-esp32-server/main/xiaozhi-server/tmp/server.log          server log
~/pocket-tts/shim.log                                              TTS shim log
docs/xiaozhi-freenove-s3/freenove-s3-wiring-diagram-v0.7.pdf       VERIFIED wiring
docs/xiaozhi-freenove-s3/s3cam-oled-i2c-v0.3.patch                 cumulative firmware patch vs ed5cd7b
```

### Wiring (GPIO)
```
INMP441  WS 1 · SCK 2 · SD 42 · L/R→GND · VDD 3V3        pads: L/R·WS·SCK / GND·VDD·SD
MAX98357A LRC 41 · BCLK 40 · DIN 39 · VIN 5V · GAIN,SD NC  silk: LRC·BCLK·DIN·GAIN·SD·GND·VIN
SH1106   SDA 47 · SCL 21 · VCC 3V3                         silk: VCC·GND·SCK·SDA · addr 0x3C · I2C0
camera   SCCB I2C1 on 4/5 (never put the OLED on port 1)
```

### Before power-up (meter, 200 Ω range, board unplugged)
```
3V3↔GND OL · 5V↔GND OL · every module adjacent pair OL · OUT+↔OUT− = speaker Ω (6–8)
each signal wire end-to-end: beep
```

### Troubleshoot
```
Chinese replies            → .config.yaml: language: key under the selected TTS
no sound, server OK        → DC at amp pads while speaking: BCLK/LRC ~1.5 V, DIN moving, SD >1.4 V, VIN 5 V;
                             AC across speaker >0.1 V~ = amp alive; all inputs OK + 0 V~ = amp dead
"Jarvis" ignored, LED blue → server down (ss) or board stuck connecting → restart server, RST
taskLVGL watchdog / Failed to lock display → OLED I²C NACK; guard in v0.3; add 4.7 kΩ pull-ups + 100 µF
I2C bus id(1) already acquired → OLED on port 1 (camera's); use I2C_NUM_0
ld: cannot find Zhi/…      → tree path has a space; mv to ~/xiaozhi-s3cam, rm -rf build
cannot read spec file …    → stale build dir after move; rm -rf build
Errno 98 on start.sh       → server already running; fuser -k … first
Illegal instruction (TTS)  → --quantize present in start.sh; remove it
/dev/ttyACM0 missing       → wrong USB-C (use UART); brltty; replug
OLED upside down           → DISPLAY_MIRROR_X/Y in config.h, rebuild
clock +6 h                 → timezone_offset in .config.yaml (+2 summer / +1 winter), restart server
```
