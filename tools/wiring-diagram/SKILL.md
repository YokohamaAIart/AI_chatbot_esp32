---
name: wiring-diagram
description: Produce, amend, review and debug precise board-to-module wiring diagrams (dev boards such as ESP32/Freenove/Heltec/Arduino + sensors, mics, amps, displays, chargers, boost converters) as a clean colour-coded PDF/SVG, with every pin's GPIO number harvested from the firmware or board source rather than memory. Use this whenever a hardware build is about to be wired, re-wired, reviewed or debugged — any mention of wiring, pinout, "which pin goes where", GPIO map, schematic-lite, hookup, breadboard plan, a new module added to a board, or a bench fault that smells like a wire — even if the user does not say "diagram".
---

# Wiring diagram — board development

A wiring diagram is the contract between the firmware and the bench. It is drawn **before** wiring and kept current afterwards; every bench fault is first checked against it. Produce it from facts, not recall: a GPIO number remembered wrongly costs an evening on the bench, and a pretty diagram with a wrong pin is worse than none.

## 0. Get the renderer

The script and references live in `github.com/YokohamaAIart/AI_chatbot_esp32/tools/wiring-diagram/`. When this skill is installed as a bare SKILL.md, fetch them first (public repo, no auth):

```bash
B=https://raw.githubusercontent.com/YokohamaAIart/AI_chatbot_esp32/main/tools/wiring-diagram
mkdir -p wiring-diagram/references && cd wiring-diagram
curl -fsSL $B/wiring_diagram.py -o wiring_diagram.py && echo "0c59e147267bbb1625e5c13389c72b1b46d90b546daecc83763125142f8f8db2  wiring_diagram.py" | sha256sum -c -
for f in conventions modules debug-checklist; do curl -fsSL $B/references/$f.md -o references/$f.md; done
python3 -c "import playwright" 2>/dev/null || pip install playwright && playwright install chromium   # only for PDF/PNG; SVG works without
```
Worked examples: `$B/examples/xiaozhi.json` (ESP32-S3 voice satellite) and `$B/examples/carcam.json` (PIR + charger/boost chain).

## 1. Harvest the pins — from source, with provenance

Pin numbers come from, in this order of authority:
1. **The firmware the board actually runs**: `config.h` / `pins.h` / `variant.h` / `board.json` of the exact board type and commit. Read it (raw file, `grep -nE 'GPIO|PIN'`). Quote file + line + commit.
2. **The vendor's board pinout** (schematic, GitHub repo, product page) for power pins, strapping pins, reserved buses (camera FPC, microSD, PSRAM, native USB).
3. **The module's datasheet / listing** for its pin names and supply range (e.g. 3V3 vs 5V, I²C address, GAIN/SD defaults).
4. **The operator's as-built notes** (handoff docs, previous diagram) for what is already soldered — these win over "should be" when they conflict, and the conflict is reported.

**Module and board pin layout: no guessing, ever.** The physical arrangement of pins (which label sits where, left→right, which header carries what) comes only from a source that *shows* the layout:
1. the operator's own read of the silkscreen — a photo, or the labels typed left→right with the text upright;
2. the vendor's pinout image, schematic or board file for the exact product and **revision** (many modules exist in several versions with different pin orders — SH1106 I²C modules alone ship as `VCC·GND·SCK·SDA` and `GND·VCC·SCL·SDA`);
3. the datasheet's package or module drawing.
A pin *table* from memory, a listing's prose, or a sibling board's `config.h` tells you what the pins are, not where they sit — that is not a layout source. If no layout source is in hand, go and get one before drawing: web search for the vendor's pinout/schematic, the vendor's GitHub repo, the product page images; identify the board/terminal/satellite revision first and match the source to it; record the source (URL or "operator photo 2026-10-17") in `source_note`. If no trustworthy layout source can be found, say `[INSUFFICIENT] pin layout for <module>` and name the fastest way to get it (a photo of the module) — do not draw that module with an assumed order. Echo the confirmed order back in one line before rendering — `MAX98357A: LRC · BCLK · DIN · GAIN · SD · GND · VIN` — and call out look-alike labels (DIN/VIN, SCK/SCL/SDA, VCC/VIN, GND/GAIN). Draw pins in exactly that order, NC pins in place (dashed), supplies wherever the board puts them; never regroup by function. Then order the board's pins to follow the module order so wires run straight; the diagram is read against the physical module, not against a datasheet table.

Mark each pin's origin in the title block's `source_note` (e.g. `Pins: config.h @ ed5cd7b · OLED I²C pins proposed`). Anything you had to choose yourself (a free GPIO for a new module) is labelled **proposed** in the reply, never silently presented as fact. Check proposed pins against: strapping pins (ESP32-S3: 0, 3, 45, 46), buses the firmware already owns, input-only pins, pins the display driver assumes.

When the firmware has **no support** for a module the user wants to add (e.g. an I²C OLED on a board type whose Kconfig only offers SPI LCDs), say so in one line with the evidence — the diagram still gets drawn, but the user learns a firmware patch is needed before wiring is worth anything.

## 2. Write the spec, then render with the script

Do not hand-draw. Fill a JSON spec and run `wiring_diagram.py` — it lays out board, supply buses, modules, orthogonal wires on separate lanes, solves row positions so no two wires overprint, adds legend and title block, and writes `.svg`, `.pdf` (A4 landscape) and `.png`.

```bash
python3 wiring_diagram.py --example > spec.json   # starter spec: ESP32-S3 + INMP441 + MAX98357A + speaker + SH1106
# edit spec.json
python3 wiring_diagram.py spec.json               # → spec.svg / spec.pdf / spec.png (PDF/PNG need playwright + chromium)
python3 wiring_diagram.py spec.json --svg-only    # no Chromium available
```

Spec rules (the script enforces most of them and warns on the rest):
- **Board**: one pin per net, listed top→bottom to follow the modules' silkscreen order (supplies first, then each module's signals in the order they appear on that module) so wires run straight and the eye can pair pin to pin.
- **Nets**: `bus: true` for 5V / 3V3 / GND — one board pin, a vertical rail, taps to every module. Draw supplies as a **star from the board's actual pins** (single GND pin on many boards) — a module's ground must never return through another module.
- **Signals**: one colour per function family, consistent across modules: BCLK/SCK and WS/LRC share colours between mic and amp because they are the same bus role; data lines get their own colours. Reuse the palette in `references/conventions.md` so diagrams across a project read alike.
- **Module pins** on the left face the board, in silkscreen order, `nc: true` entries kept in place (GAIN, SD, EN left floating — shown dashed, so the reader knows it is deliberate); `right_pins` are what leaves the diagram (speaker terminals, cell, antenna).
- **Module ↔ module nets** (charger → boost → board): both ends on left-side pins; the script routes them on a lane beside the module column.
- No comments on the drawing. Title block + legend only. Constraints and caveats go in the reply and the handoff doc.

If the script prints `WARNING: board pins with no module pin`, a net name is misspelt or a pin is orphaned — fix the spec, don't ship.

## 3. Review before delivery — look at the PNG

Open the rendered PNG and check, in this order:
1. Module pin order on the drawing = the confirmed silkscreen order, pin for pin, including NC pins.
2. Every wire lands on exactly one pin box at each end; no wire passes through a box or under a label.
3. Colours match the legend; a colour used twice means the same bus role.
4. Supply polarity: VIN/VCC on the correct rail (3V3-only parts never on 5V), GND star complete, L/R or address-select pins tied where the firmware expects (e.g. INMP441 L/R→GND = left slot).
5. Nothing reserved is reused: camera FPC pins, microSD-shared pins, native USB D±, strapping pins.
6. The title block states version, date and pin provenance.

Fix the spec and re-render until all six pass; then deliver the PDF (and the SVG for edits). In the reply: pins that are confirmed vs proposed, and any firmware precondition.

## 4. Amend

A wiring change is a new version of the spec (`v0.2`), not an edit of the PDF. Keep the JSON next to the project docs under version control; the diff of the spec *is* the change log. When a module is swapped, keep the net names and only change the module block — the colours and lanes stay stable so the operator's eye keeps its map.

## 5. Debug against the diagram

When the bench disagrees with the firmware, the diagram is the checklist — `references/debug-checklist.md` has the order. The principle: one read per step (continuity, voltage, boot log line), compare with the diagram, stop at the first mismatch. Typical findings from real sessions: a reversed sensor fed from the wrong rail, a module's GND returned through another module, a strapping pin pulled up by a module's CS pull-up, a display's BL pin wired to 3V3 when the firmware drives it as PWM, a microSD inserted on pins shared with the amp. Log the correction in the handoff doc and bump the diagram.

## References

- `references/conventions.md` — colour palette, lane/bus rules, pin naming, what goes in the title block.
- `references/modules.md` — pin facts for frequently used modules (INMP441, MAX98357A, SH1106/SSD1306 I²C, GC9A01 SPI, TP4056, MT3608, AM312, Heltec V3/V4 headers) with their gotchas. Verify against the datasheet when the listing differs.
- `references/debug-checklist.md` — bench-to-diagram checking order and the ESP32-S3 reserved/strapping pin table.
