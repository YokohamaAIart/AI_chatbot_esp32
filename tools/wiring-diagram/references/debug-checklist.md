# Bench ↔ diagram debug order

One step, one read, compare to the diagram, stop at the first mismatch. Never two changes between reads.

1. **Unpowered continuity** — each module pin to its board header pin per the diagram (beep). Then adjacent-pair short test on every module (no beep). A pin that beeps to its neighbour is the fault; stop here.
2. **Supply polarity, unpowered** — ohmmeter from each VCC/VIN to the rail it is drawn on, and to GND (must not be ~0 Ω). Reversed sensor = hot module + dragged rail on power-up.
3. **Rails under power, no signals** — 5V, 3V3 at the board pins and at each module's supply pin (voltage drop > 0.1 V = thin wire or bad joint).
4. **Clocks** — DC-meter a running I²S/SPI clock: ~half the rail (1.6 V on 3.3 V) means it toggles; 0 V or 3.3 V steady = dead line or wrong GPIO. Compare the GPIO against the firmware define, not the diagram — the diagram might be wrong.
5. **Data** — mic SD / sensor OUT changes while speaking/clapping at the module pin **and** at the board pin; module changes but board does not = wire; neither = module.
6. **Boot log** — the firmware prints what it initialised (`I2S`, `LCD`, `camera`, `PSRAM`); an init error names the bus. Match it to the diagram's bus.
7. **Reserved-pin collision** — microSD inserted? camera FPC present? native USB used? Table below.
8. **Strapping** — if the board boots differently with a module attached, the module pulls a strapping pin; move the signal.

Record every finding as a correction to the diagram version and the handoff doc, with the read that proved it.

## ESP32-S3 pins to treat as taken
| Pin | Why |
|---|---|
| 0 | BOOT strap / button |
| 3, 45, 46 | strapping |
| 19, 20 | native USB D−/D+ |
| 26–32 | SPI flash (never on the header) |
| 33–37 | octal PSRAM on R8 modules |
| 38, 39, 40 | microSD on Freenove S3 CAM (shared with any module on them) |
| 4–13, 15–18 | camera DVP on Freenove S3 CAM |
| 43, 44 | UART0 TX/RX (console) |
