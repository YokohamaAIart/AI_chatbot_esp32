# Drawing conventions

## Colour palette (hex, used by the script's example)
| Role | Colour | Note |
|---|---|---|
| 5V | `#D62828` | bus |
| 3V3 | `#F77F00` | bus |
| GND | `#111111` | bus; star from the board's GND pin |
| Clock (BCLK / SCK / SCL-SPI) | `#2A9D8F` | same colour on every module sharing the role |
| Word select (WS / LRC) | `#E9C46A` | |
| Data in to board (mic SD, sensor OUT) | `#1D4ED8` | |
| Data out of board (amp DIN, display MOSI) | `#7B2CBF` | |
| I²C SDA | `#0EA5E9` | |
| I²C SCL | `#C026D3` | |
| Display control (DC / CS / RST / BL) | `#0F766E` `#14532D` `#1E3A8A` `#A16207` | one each, keep the set |
| Speaker + / − | `#B91C1C` / `#374151` | |
| Cell + / − | `#B91C1C` / `#374151` | |

Never two different roles in one colour on the same page. Never rely on colour alone for polarity: label every pin.

## Layout rules the script follows
- Board on the left, pins on its right edge, labels in monospace with the GPIO number.
- Supply rails vertical between board and modules; every tap gets a junction dot.
- Signals leave the board horizontally, turn once on their own lane, arrive horizontally at the module pin.
- Rows are solved so wires are ≥ 8 px apart; if the solver fails, the page is overfull — split power and signals into two sheets rather than shrink text.
- Module order top→bottom mirrors the board pin order so lanes rarely cross.
- Right-side module pins = things that leave the diagram (speaker, cell, antenna) or deliberate NC (dashed).

## Title block
`title` (project — WIRING DIAGRAM) · `subtitle` (parts list) · `version` + `date` · `source_note` (where the pins came from, commit hash, what is proposed). Version increments on every change; "DRAFT" until bench-verified.

## Pin naming
Board side: the silkscreen name (`GPIO 42`, `3V3`, `5V`, `GND`). Module side: the module's silkscreen (`SD`, `L/R`, `LRC`, `VIN`). Net names in the spec: `FAMILY_SIGNAL` (`MIC_WS`, `AMP_BCLK`, `SDA`, `SPK_P`).
