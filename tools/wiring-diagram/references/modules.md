# Module pin facts and gotchas

Pin lists below are in silkscreen order where known (left→right, labels upright). Where a vendor differs, the physical board wins — ask for it.

Listings lie; datasheets and the firmware's expectations win. Verify supply range and any select pin before drawing.

| Module | Pins | Supply | Gotchas |
|---|---|---|---|
| **INMP441** I²S mic | VDD, GND, SD (data out), WS, SCK, L/R | 3.3 V only | L/R→GND = left slot (what most firmware expects), L/R→VDD = right. Shared ground with a 5 V amp is fine; its VDD on 5 V kills it. Acoustic port must face open air. |
| **MAX98357A** I²S amp | silkscreen L→R: **LRC · BCLK · DIN · GAIN · SD · GND · VIN**; OUT+/OUT− terminal block | 2.7–5.5 V, 5 V for volume | DIN and VIN sit at opposite ends and read alike — confirm on the board. GAIN floating = 9 dB; SD floating = (L+R)/2 mono; SD→GND shuts the amp down. Speaker 4–8 Ω on the terminal block; no ground reference on OUT−. |
| **SH1106 / SSD1306 128×64 I²C** | silkscreen L→R varies by vendor: **VCC · GND · SCK · SDA** on the 1.3″ Binhe module, GND · VCC · SCL · SDA on others — read the board | 3.3–5 V | Address 0x3C (sometimes 0x3D). Pull-ups usually on the module. SH1106 has a 132-px RAM offset: SSD1306 drivers show a shifted image. |
| **GC9A01 1.28″ round SPI** | VCC, GND, SCL(CLK), SDA(MOSI), DC, CS, RST, BL | 3.3 V | BL is a PWM input on most firmware — do not tie to 3V3. CS on a strapping pin needs an eFuse/strap check. Keep SPI leads ≤ 15 cm at 40 MHz. |
| **TP4056 USB-C (03962A-style and small variants)** | IN±, B± (cell), sometimes OUT± / PH2.0 socket | 4.5–8 V in | Small boards often have **no OUT± pads** — the socket sits on B±; protection IC then not in the discharge path. Never feed a panel with Voc > 8 V. |
| **MT3608 boost** | VIN+, VIN−, VOUT+, VOUT− | 2–24 V in | Trim pot: turn, measure, lock (nail varnish). Over-turning collapses the boost. |
| **AM312 PIR** | VCC, OUT, GND | 2.7–12 V | Reverse VCC/GND runs it hot and drags the 3V3 rail — meter polarity before power. Floating OUT on an ext0 wake pin gives spurious wakes: pull-down. |
| **Heltec WiFi LoRa 32 V3/V4** | VBAT SH1.25-2, 3V3, 5V, GND, GPIO header | 3.7 V cell or USB | Antenna on IPEX before power. Cell adapter: PH2.0 → SH1.25, polarity metered — "red wire lies". |
| **Freenove ESP32-S3 WROOM CAM (FNK0085)** | 5V, 3V3, single GND header pin, GPIO header, camera FPC, microSD | USB-C ×2 | Camera owns GPIO 4–13, 15–18. microSD shares 38/39/40. GPIO 19/20 = native USB D±: once used for a display, native USB is dead after boot; use the UART USB-C. Blue LED on IO2. |

ESP32-S3 strapping pins: GPIO 0 (boot), 3 (JTAG), 45 (VDD_SPI voltage), 46 (ROM log). A module pull-up on 45 can change the flash voltage strap: read `espefuse summary` before deciding CS placement.
