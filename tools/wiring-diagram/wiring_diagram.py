#!/usr/bin/env python3
"""
wiring_diagram.py · v1.1 · board-to-module wiring diagram from a JSON spec → SVG (+ PDF/PNG via Chromium).

    python3 wiring_diagram.py spec.json                # writes spec.svg, spec.pdf, spec.png next to the spec
    python3 wiring_diagram.py spec.json --svg-only     # no Chromium needed
    python3 wiring_diagram.py --example > spec.json    # starter spec

Spec (JSON). Module pins are listed in SILKSCREEN ORDER (left→right as read on the board), NC pins included in place:
{
  "title": "PROJECT — WIRING DIAGRAM", "subtitle": "parts list", "version": "v0.1 DRAFT", "date": "2026-10-17",
  "source_note": "Pins: config.h @ ed5cd7b",            # top-right small print: where the pins came from
  "board":  {"name": "FREENOVE", "sub": "ESP32-S3 WROOM CAM", "note": "16 MB flash",
             "pins": [{"label": "5V", "net": "5V"}, {"label": "GPIO 1", "net": "MIC_WS"}, ...]},
  "modules": [{"name": "INMP441", "sub": "I2S MEMS microphone",
               "pins": [{"label": "VDD", "net": "3V3"}, {"label": "L/R", "net": "GND"}, ...],
               "right_pins": [{"label": "GAIN", "nc": true}, {"label": "OUT+", "net": "SPK_P"}]}],
  "nets":   {"5V": {"color": "#D62828", "bus": true, "legend": "5V"},
             "MIC_WS": {"color": "#E9C46A", "legend": "WS / LRC"}, ...},
  "speaker": {"module": "MAX98357A", "plus": "SPK_P", "minus": "SPK_N", "label": "4–8 Ω"}   # optional
}
Rules the renderer enforces: one board pin per net except buses (bus = one board pin, many module taps);
every horizontal wire row is at least MIN_GAP px from every other row (solver), so wires never overprint.
"""
import json, sys, pathlib, itertools, subprocess

W, H = 1123, 794                      # A4 landscape @ 96 dpi
INK, GREY, BOARD, MOD = "#1F2937", "#9CA3AF", "#0F766E", "#374151"
MIN_GAP = 8
MONO = "'JetBrains Mono','DejaVu Sans Mono',Consolas,monospace"
SANS = "Inter, Arial, Helvetica, sans-serif"

EXAMPLE = {
  "title": "XIAOZHI VOICE SATELLITE — WIRING DIAGRAM",
  "subtitle": "Freenove ESP32-S3 WROOM CAM · INMP441 · MAX98357A · 4–8 Ω speaker · SH1106 1.3″ OLED (I²C)",
  "version": "v0.1 DRAFT", "date": "2026-10-17", "source_note": "Pins: config.h @ ed5cd7b · OLED I²C pins proposed",
  "board": {"name": "FREENOVE", "sub": "ESP32-S3 WROOM CAM", "note": "FNK0085 · 16 MB flash · 8 MB PSRAM",
            "pins": [{"label": "5V", "net": "5V"}, {"label": "3V3", "net": "3V3"}, {"label": "GND", "net": "GND"},
                     {"label": "GPIO 1", "net": "MIC_WS"}, {"label": "GPIO 2", "net": "MIC_SCK"}, {"label": "GPIO 42", "net": "MIC_SD"},
                     {"label": "GPIO 40", "net": "AMP_BCLK"}, {"label": "GPIO 41", "net": "AMP_LRC"}, {"label": "GPIO 39", "net": "AMP_DIN"},
                     {"label": "GPIO 47", "net": "SDA"}, {"label": "GPIO 21", "net": "SCL"}]},
  "modules": [
    {"name": "INMP441", "sub": "I²S MEMS microphone",
     "pins": [{"label": "VDD", "net": "3V3"}, {"label": "GND", "net": "GND"}, {"label": "L/R", "net": "GND"},
              {"label": "WS", "net": "MIC_WS"}, {"label": "SCK", "net": "MIC_SCK"}, {"label": "SD", "net": "MIC_SD"}]},
    {"name": "MAX98357A", "sub": "I²S class-D amplifier",
     "pins": [{"label": "LRC", "net": "AMP_LRC"}, {"label": "BCLK", "net": "AMP_BCLK"}, {"label": "DIN", "net": "AMP_DIN"},
              {"label": "GAIN", "nc": True}, {"label": "SD", "nc": True}, {"label": "GND", "net": "GND"}, {"label": "VIN", "net": "5V"}],
     "right_pins": [{"label": "OUT+", "net": "SPK_P"}, {"label": "OUT−", "net": "SPK_N"}]},
    {"name": "SH1106 OLED 1.3″", "sub": "128×64 · I²C 0x3C",
     "pins": [{"label": "GND", "net": "GND"}, {"label": "VCC", "net": "3V3"}, {"label": "SCL", "net": "SCL"}, {"label": "SDA", "net": "SDA"}]}],
  "nets": {"5V": {"color": "#D62828", "bus": True, "legend": "5V"}, "3V3": {"color": "#F77F00", "bus": True, "legend": "3V3"},
           "GND": {"color": "#111111", "bus": True, "legend": "GND"},
           "MIC_SCK": {"color": "#2A9D8F", "legend": "BCLK / SCK"}, "AMP_BCLK": {"color": "#2A9D8F"},
           "MIC_WS": {"color": "#E9C46A", "legend": "WS / LRC"}, "AMP_LRC": {"color": "#E9C46A"},
           "MIC_SD": {"color": "#1D4ED8", "legend": "Mic data SD"}, "AMP_DIN": {"color": "#7B2CBF", "legend": "Amp data DIN"},
           "SDA": {"color": "#0EA5E9", "legend": "I²C SDA"}, "SCL": {"color": "#C026D3", "legend": "I²C SCL"},
           "SPK_P": {"color": "#B91C1C", "legend": "Speaker +"}, "SPK_N": {"color": "#374151", "legend": "Speaker −"}},
  "speaker": {"module": "MAX98357A", "plus": "SPK_P", "minus": "SPK_N", "label": "4–8 Ω"}
}


class SVG:
    def __init__(self): self.b = []
    def add(self, s): self.b.append(s)
    def text(self, x, y, s, size=11, anchor="start", weight="normal", fill=INK, mono=False):
        fam = MONO if mono else SANS
        s = s.replace("&", "&amp;").replace("<", "&lt;")
        self.add(f'<text x="{x}" y="{y}" font-family="{fam}" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}" fill="{fill}">{s}</text>')
    def rect(self, x, y, w, h, fill, stroke=INK, rx=6, sw=1.5):
        self.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    def wire(self, pts, color, sw=3):
        d = " ".join(f"{'M' if i == 0 else 'L'}{x},{y}" for i, (x, y) in enumerate(pts))
        self.add(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"/>')
    def dot(self, x, y, color, r=4): self.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{color}"/>')
    def pin(self, x, y, label, side, color=INK, nc=False):
        if nc and side == "l":
            self.add(f'<line x1="{x-14}" y1="{y}" x2="{x}" y2="{y}" stroke="{GREY}" stroke-width="2" stroke-dasharray="3,3"/>')
            self.text(x+8, y+4, f"{label}  NC", 10, "start", fill=GREY, mono=True); return x
        if nc:
            self.add(f'<line x1="{x}" y1="{y}" x2="{x+14}" y2="{y}" stroke="{GREY}" stroke-width="2" stroke-dasharray="3,3"/>')
            self.text(x-8, y+4, f"{label}  NC", 10, "end", fill=GREY, mono=True); return x
        if side == "r":
            self.add(f'<line x1="{x}" y1="{y}" x2="{x+18}" y2="{y}" stroke="{INK}" stroke-width="2"/>')
            self.add(f'<rect x="{x+16}" y="{y-4}" width="8" height="8" fill="#FFFFFF" stroke="{INK}" stroke-width="1.5"/>')
            self.text(x-8, y+4, label, 11, "end", "bold", color, mono=True); return x + 24
        self.add(f'<line x1="{x-18}" y1="{y}" x2="{x}" y2="{y}" stroke="{INK}" stroke-width="2"/>')
        self.add(f'<rect x="{x-24}" y="{y-4}" width="8" height="8" fill="#FFFFFF" stroke="{INK}" stroke-width="1.5"/>')
        self.text(x+8, y+4, label, 11, "start", "bold", color, mono=True); return x - 24


def solve_rows(n_board, mod_counts, top=200, bottom=700, mod_top=78, mod_bottom=712):
    """Pick board pitch/origin and module y offsets so that no two horizontal wire rows are closer than MIN_GAP."""
    best = None
    for dy in (44, 42, 40, 38, 36):
        for py0 in range(190, 240, 2):
            board = [py0 + i*dy for i in range(n_board)]
            if board[-1] > bottom: continue
            for mp in (26, 24, 22):
                heights = [62 + (c-1)*mp + 24 for c in mod_counts]
                total = sum(heights); free = mod_bottom - mod_top - total
                if free < 0: continue
                gap_opts = range(10, max(11, int(free/ max(1, len(mod_counts)-1)) + 1), 4) if len(mod_counts) > 1 else [0]
                for g in gap_opts:
                    for off in range(0, 24, 2):
                        ys, y = [], mod_top + off
                        for h in heights: ys.append(y); y += h + g
                        if ys[-1] + heights[-1] > mod_bottom: break
                        rows = [ys[k] + 62 + i*mp for k, c in enumerate(mod_counts) for i in range(c)]
                        gap = min(abs(r-b) for r in rows for b in board)
                        score = (min(gap, 14), -abs(mp-26))
                        if best is None or score > best[0]: best = (score, dy, py0, mp, ys, heights)
    if best is None: raise SystemExit("layout does not fit on one A4 page: fewer pins or split the diagram")
    return best[1:]


def render(spec):
    s = SVG(); nets = spec["nets"]
    col = lambda net: nets.get(net, {}).get("color", INK)
    s.add(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
    s.add(f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>')
    # title block
    s.text(40, 38, spec["title"], 20, weight="bold"); s.text(40, 56, spec.get("subtitle", ""), 12, fill="#4B5563")
    s.text(W-40, 38, f'{spec.get("version","")} · {spec.get("date","")}', 12, "end", fill="#4B5563")
    s.text(W-40, 56, spec.get("source_note", "")[:70], 10, "end", fill=GREY)
    s.add(f'<line x1="40" y1="68" x2="{W-40}" y2="68" stroke="{GREY}" stroke-width="1"/>')

    board, mods = spec["board"], spec["modules"]
    dy, py0, mp, mod_ys, mod_hs = solve_rows(len(board["pins"]), [len(m["pins"]) for m in mods])

    # board
    BX, BY, BW = 70, 80, 250; BH = max(300, py0 + (len(board["pins"])-1)*dy + 60 - BY)
    s.rect(BX, BY, BW, BH, "#ECFDF5", BOARD, 10, 2)
    s.text(BX+BW/2, BY+30, board["name"], 15, "middle", "bold", BOARD)
    s.text(BX+BW/2, BY+50, board.get("sub", ""), 13, "middle", "bold", BOARD)
    s.text(BX+BW/2, BY+68, board.get("note", ""), 10, "middle", fill="#4B5563")
    BP = {}
    for i, p in enumerate(board["pins"]):
        y = py0 + i*dy; BP[p["net"]] = (s.pin(BX+BW, y, p["label"], "r", col(p["net"])), y)

    # buses: one vertical rail per bus net, between board and modules
    bus_nets = [n for n, v in nets.items() if v.get("bus")]
    BUSX = {n: 400 + 25*i for i, n in enumerate(bus_nets)}
    for n, x in BUSX.items():
        s.wire([(x, 100), (x, 700)], col(n), 4)
        s.text(x, 94, nets[n].get("legend", n), 10, "middle", "bold", col(n))
        if n in BP:
            px, py = BP[n]; s.wire([(px, py), (x, py)], col(n)); s.dot(x, py, col(n))

    # modules
    MX, MW = 760, 262; MP = {}
    for k, m in enumerate(mods):
        y, h = mod_ys[k], mod_hs[k]
        s.rect(MX, y, MW, h, "#F9FAFB", MOD, 8, 1.8)
        s.text(MX+MW/2, y+24, m["name"], 14, "middle", "bold", MOD); s.text(MX+MW/2, y+41, m.get("sub", ""), 10, "middle", fill="#6B7280")
        for i, p in enumerate(m["pins"]):
            yy = y + 62 + i*mp
            if p.get("nc"): s.pin(MX, yy, p["label"], "l", nc=True); continue
            MP[(m["name"], p["label"])] = (s.pin(MX, yy, p["label"], "l", col(p.get("net", ""))), yy, p.get("net"))
        for i, p in enumerate(m.get("right_pins", [])):
            yy = y + 62 + i*22
            if p.get("nc"):
                s.add(f'<line x1="{MX+MW}" y1="{yy}" x2="{MX+MW+14}" y2="{yy}" stroke="{GREY}" stroke-width="2" stroke-dasharray="3,3"/>')
                s.text(MX+MW-8, yy+4, f'{p["label"]}  NC', 10, "end", fill=GREY, mono=True)
            else:
                s.add(f'<line x1="{MX+MW}" y1="{yy}" x2="{MX+MW+18}" y2="{yy}" stroke="{INK}" stroke-width="2"/>')
                s.add(f'<rect x="{MX+MW+16}" y="{yy-4}" width="8" height="8" fill="#FFFFFF" stroke="{INK}" stroke-width="1.5"/>')
                s.text(MX+MW-8, yy+4, p["label"], 11, "end", "bold", col(p["net"]), mono=True)
                MP[(m["name"], p["label"])] = (MX+MW+24, yy, p["net"])

    # speaker (optional)
    sp = spec.get("speaker")
    if sp:
        plus = next(v for (mn, _), v in MP.items() if mn == sp["module"] and v[2] == sp["plus"])
        minus = next(v for (mn, _), v in MP.items() if mn == sp["module"] and v[2] == sp["minus"])
        SPX, SPY = 1052, plus[1] - 22
        s.add(f'<path d="M{SPX},{SPY+14} h14 l18,-18 v52 l-18,-18 h-14 z" fill="#E5E7EB" stroke="{INK}" stroke-width="1.8"/>')
        for r in (10, 18): s.add(f'<path d="M{SPX+40},{SPY+30-r} a{r},{r} 0 0 1 0,{2*r}" fill="none" stroke="{INK}" stroke-width="1.5"/>')
        s.text(SPX+16, SPY+68, sp.get("label", ""), 10, "middle", fill="#4B5563")
        s.wire([(plus[0], plus[1]), (SPX-4, plus[1]), (SPX-4, SPY+14), (SPX, SPY+14)], col(sp["plus"]))
        s.wire([(minus[0], minus[1]), (SPX-10, minus[1]), (SPX-10, SPY+44), (SPX, SPY+44)], col(sp["minus"]))

    # taps (bus → module) and signals (board pin → lane → module pin)
    sig_nets = [n for n in nets if not nets[n].get("bus")]
    lanes = {n: 480 + 22*i for i, n in enumerate(n for n in sig_nets if n in BP)}
    for (mn, pl), (x, y, net) in MP.items():
        if not net or x > MX: continue
        if net in BUSX:
            s.wire([(BUSX[net], y), (x, y)], col(net)); s.dot(BUSX[net], y, col(net))
        elif net in BP:
            bx, by = BP[net]; lx = lanes[net]
            s.wire([(bx, by), (lx, by), (lx, y), (x, y)], col(net))
    # module ↔ module nets (no board pin, not a bus): both ends must be left-side pins; routed on lanes just left of the modules
    mm = {}
    for (mn, pl), (x, y, net) in MP.items():
        if net and net not in BUSX and net not in BP: mm.setdefault(net, []).append((x, y))
    ext = {spec['speaker']['plus'], spec['speaker']['minus']} if spec.get('speaker') else set()
    for i, (net, ends) in enumerate(n for n in mm.items() if n[0] not in ext):
        ends = [e for e in ends if e[0] <= MX]
        if len(ends) < 2:
            print(f"WARNING: net {net} has fewer than two left-side module pins; right-side pins are external only", file=sys.stderr); continue
        lx = 700 - 12*i
        ys = sorted(y for _, y in ends)
        s.wire([(lx, ys[0]), (lx, ys[-1])], col(net))
        for x, y in ends: s.wire([(lx, y), (x, y)], col(net)); s.dot(lx, y, col(net))
    unused = [n for n in BP if n not in BUSX and not any(v[2] == n for v in MP.values())]
    if unused: print("WARNING: board pins with no module pin:", unused, file=sys.stderr)

    # legend
    items = [(v["legend"], v["color"]) for v in nets.values() if v.get("legend")]
    LX, LY = 40, 722; s.rect(LX, LY, W-80, 56, "#F9FAFB", GREY, 6, 1)
    per_row = 6
    for i, (label, c) in enumerate(items):
        x = LX + 16 + (i % per_row)*165; row = LY + 20 + (i // per_row)*22
        s.wire([(x, row), (x+26, row)], c, 4); s.text(x+32, row+4, label, 10)
    s.add("</svg>")
    return "\n".join(s.b)


def to_pdf_png(svg_path):
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("playwright not installed: SVG only (pip install playwright && playwright install chromium)", file=sys.stderr); return
    html = svg_path.with_suffix(".html")
    html.write_text('<!doctype html><html><head><meta charset="utf-8"><style>@page{size:A4 landscape;margin:0}html,body{margin:0;background:#fff}'
                    'svg{display:block;width:297mm;height:210mm}</style></head><body>' + svg_path.read_text() + '</body></html>')
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page(viewport={"width": W, "height": H}); pg.goto(html.as_uri()); pg.wait_for_timeout(200)
        pg.pdf(path=str(svg_path.with_suffix(".pdf")), format="A4", landscape=True, print_background=True, margin={k: "0" for k in ("top", "bottom", "left", "right")})
        pg.screenshot(path=str(svg_path.with_suffix(".png")), full_page=True); b.close()
    html.unlink()


if __name__ == "__main__":
    if "--example" in sys.argv: print(json.dumps(EXAMPLE, indent=2, ensure_ascii=False)); sys.exit()
    spec_path = pathlib.Path(sys.argv[1]).resolve(); spec = json.loads(spec_path.read_text())
    out = spec_path.with_suffix(".svg"); out.write_text(render(spec)); print(out)
    if "--svg-only" not in sys.argv: to_pdf_png(out); print(out.with_suffix(".pdf")); print(out.with_suffix(".png"))
