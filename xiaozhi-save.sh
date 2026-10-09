#!/usr/bin/env bash
# xiaozhi-save.sh · v1.0 · 2026-10-09 · replaces save-esp32-wonders.sh and save-ai-chatbot-esp32.sh
# Run on Perlin:  bash ~/Downloads/xiaozhi-save.sh
#   1. Saves the project docs into  ~/Documents/Microcontrolers/Xiao Zhi/docs/  (only adds/overwrites these files).
#   2. Installs CLAUDE.md into ~/xiaozhi-s3cam (a different existing one is kept as CLAUDE.md~).
#   3. Safety snapshots, local git only: ~/xiaozhi-s3cam on branch freenove-s3, ~/mic-probe on main.
#      No git in the Xiao Zhi folder: it gets its repo + GitHub backup after cleanup.
#   4. Prints an inventory of the Xiao Zhi folder for the cleanup.
# No push, no remote, nothing deleted, no working-tree file reverted. Re-runnable.
# Other paths: XZ=/path FW=/path PROBE=/path bash xiaozhi-save.sh
set -euo pipefail

XZ="${XZ:-$HOME/Documents/Microcontrolers/Xiao Zhi}"
XZ="${XZ%/}"
DOCS="$XZ/docs"
FW="${FW:-$HOME/xiaozhi-s3cam}"
PROBE="${PROBE:-$HOME/mic-probe}"
FW_BRANCH="freenove-s3"
MAX_MB=20
DEFAULT_DOCS_TXT='~/Documents/Microcontrolers/Xiao Zhi/docs'
TRAILER=$'\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011TC6gZhTsgiNRs7DVC6RDk'
EXCLUDES=('build/' 'managed_components/' 'sdkconfig' 'sdkconfig.old' '*.bin' 'tmp/' '.vscode/' '*~')

say() { printf '\n== %s\n' "$*"; }

is_own_repo() {   # $1 is the top level of a git work tree
  local top
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 1
  [ "$top" = "$(cd "$1" && pwd -P)" ]
}

prep_repo() {     # $1 dir, $2 branch for git init: init if needed, local excludes, identity if missing
  local d="$1" ex
  if ! is_own_repo "$d"; then
    git -C "$d" init -q -b "$2"
    echo "git init: $d (branch $2)"
  fi
  ex=$(git -C "$d" rev-parse --git-path info/exclude)
  case "$ex" in /*) ;; *) ex="$d/$ex" ;; esac
  mkdir -p "$(dirname "$ex")"; touch "$ex"
  for p in "${EXCLUDES[@]}"; do grep -qxF -- "$p" "$ex" || echo "$p" >> "$ex"; done
  if [ -z "$(git -C "$d" config user.email || true)" ]; then
    git -C "$d" config user.name "Martin Yokohama"
    git -C "$d" config user.email "jerome@jeromemartin.art"
    echo "repo-local git identity set (no global one found)"
  fi
}

commit_all() {    # $1 dir, $2 message. Refuses if any staged file is over MAX_MB.
  local d="$1" big
  git -C "$d" add -A
  if git -C "$d" diff --cached --quiet; then echo "nothing new to commit"; return 0; fi
  big=$(cd "$d" && git diff --cached --name-only --diff-filter=d -z | xargs -0 -r du -m -- | awk -v m="$MAX_MB" '$1>m { $1=""; print substr($0,2) }')
  if [ -n "$big" ]; then
    git -C "$d" reset -q 2>/dev/null || git -C "$d" rm -r -q --cached . >/dev/null
    printf 'ABORTED commit in %s: staged files over %s MB (move them or add them to .git/info/exclude, then rerun):\n%s\n' "$d" "$MAX_MB" "$big"
    return 1
  fi
  git -C "$d" commit -q -m "$2$TRAILER"
  git -C "$d" --no-pager log --oneline -1
  git -C "$d" --no-pager show --stat --format= HEAD | tail -n 12
}

snapshot_tree() { # $1 dir, $2 branch, $3 message
  local d="$1" b="$2" cur
  [ -d "$d" ] || { echo "SKIP: $d not found"; return 0; }
  command -v git >/dev/null || { echo "SKIP: git not found"; return 0; }
  echo "-- $d"
  if is_own_repo "$d"; then
    cur=$(git -C "$d" symbolic-ref -q --short HEAD || true)
    if [ "$cur" != "$b" ]; then
      if git -C "$d" show-ref --verify --quiet "refs/heads/$b"; then
        echo "SKIP: branch $b exists but ${cur:-a detached HEAD} is checked out; nothing changed"
        return 0
      fi
      git -C "$d" switch -q -c "$b"
      echo "branch $b created at $(git -C "$d" rev-parse --short HEAD) (was ${cur:-detached HEAD}); working tree untouched"
    fi
  elif git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "SKIP: $d sits inside another repo ($(git -C "$d" rev-parse --show-toplevel))"
    return 0
  fi
  prep_repo "$d" "$b"
  commit_all "$d" "$3"
}

w() { mkdir -p "$(dirname "$DOCS/$1")"; cat > "$DOCS/$1"; }

say "1/4 Docs -> $DOCS"
mkdir -p "$DOCS"
w 'INDEX.md' <<'__EW_EOF__'
# Xiao Zhi project: doc index

Imported 2026-10-09 from the claude.ai project "ESP32 wonders". ★ = current version.

| Folder | Docs |
|---|---|
| `xiaozhi-freenove-s3/` | ★ `freenove-s3-xiaozhi-handoff-v1.2.md` · ★ `gc9a01-xiaozhi-firmware-params-v1.1.md` · ★ `xiaozhi-s3cam-CLAUDE.md` (copy of `~/xiaozhi-s3cam/CLAUDE.md`) · superseded: handoff v1.0, v1_1, params v1.0 |
| `xiaozhi-e32r28t/` | `e32r28t-xiaozhi-handoff-v1.0.md` · `SOP-001_xiaozhi-e32r28t-bringup_v1_0.yaml` (the bundle itself stays in `~/projects/xiaozhi-e32r28t/`) |
| `research/` | `esp32-family-llm-companion-v1.0.md` |
| `links.md` | links saved in the project |

Working trees outside this folder:
- `~/xiaozhi-s3cam`: firmware (78/xiaozhi-esp32 @ ed5cd7b + local edits), local branch `freenove-s3`
- `~/mic-probe`: I2S mic probe, local repo

Update rule: a new doc version is a new `-vX.Y` file, saved here and written to the claude.ai project. Git + GitHub backup (`YokohamaAIart/AI_chatbot_esp32`) after the folder cleanup.
__EW_EOF__
w 'links.md' <<'__EW_EOF__'
# Links saved in the claude.ai project

- https://www.youtube.com/watch?v=Hya6Zc1cTr4
__EW_EOF__
w 'research/esp32-family-llm-companion-v1.0.md' <<'__EW_EOF__'
# ESP32 Family & On-Device LLM Companion — Decision Checklist

**Version:** v1.0 · 2026-09-09
**Subject:** (a) the complete ESP32 silicon family as of Sept 2026, (b) which part can host a small quantized LLM with mic, speaker and two µOLED "eyes"
**Lens:** on-device inference capability — memory ceiling, memory *bandwidth*, SIMD, audio I/O, display buses, and whether a chat-capable model actually exists for the target
**Confidence key:** ✅ confirmed (read this session, source named) · ⚠️ partial / inferred / conditional · ❌ insufficient confirmed data

### Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-09-09 | Initial. Full 14-chip family reference + P4 selection for the LLM companion build. |

---

## 1. Bottom line (read this first)

Fourteen chips carry the ESP32 name; eleven are in mass production. For everything that is *not* AI, the choice is boring and settled: **ESP32-S3** for compute and displays, **ESP32-C6** for Matter/Thread, **ESP32-C3** for cheap nodes, original **ESP32** for Bluetooth Classic.

For your specific build — a device you *talk to*, that runs the model itself — the field collapses to one part. Only two ESP32 chips have enough PSRAM and SIMD to hold a language model at all (S3 and P4), and only one of them has a demonstrated instruction-following model: **the ESP32-P4 with 32 MB PSRAM**, running the `p-for-llm` 180.9M-parameter ternary MoE at ~9 tokens/second.

The caveat that decides your architecture: that model consumes ~44 MiB across flash and PSRAM — roughly 92% of the board's total addressable storage. The wake-word engine, the audio front-end and the TTS engine will not fit alongside it on the same die. Plan a two-chip device from the start, not one board.

> **Verdict:** ESP32-P4 (32 MB PSRAM) as the LLM host, ESP32-S3 (N16R8) as the voice-and-eyes front-end, linked over UART. One board will not do this job.

---

## 2. The ESP32 family — status and full reference

### 2.1 Family status checklist

- ✅ Espressif's SoC page lists **14** ESP32-family parts: ESP32, S2, S3, S31, C2, C3, C5, C6, C61, H2, H4, H21, P4, and the E22 co-processor. *(espboards.dev datasheet aggregate, updated 04 Sep 2026)*
- ✅ **11 are in mass production.** H4 is sampling only (since Mar 2026), H21 is announced only (Mar 2026), E22 is samples only.
- ✅ Two CPU architectures coexist: Xtensa (original ESP32, S2, S3) and RISC-V (everything else, including the new S31 which breaks the "S = Xtensa" pattern).
- ✅ **No ESP32 chip has an NPU.** The "AI acceleration" on S3 and P4 is a set of SIMD vector instructions, nothing more. The S31 doubles down on radios and SIMD, not neural hardware. *(theaivibe.org, Aug 2026)*
- ✅ Radio is not universal: H2/H4/H21 have no Wi-Fi (BLE + 802.15.4 only), and the **P4 has no radio at all** — every P4 board pairs it with an ESP32-C6 over SDIO.
- ✅ The **C5 is the only ESP32 that joins 5 GHz networks.**
- ✅ WROOM / WROVER / MINI / SOLO are *packagings* (chip + flash + antenna), not different chips. ESP8684 = ESP32-C2 retail name. ESP8685 = 4×4 mm ESP32-C3.
- ⚠️ Module suffixes carry real information and are easy to get wrong: `N8R8` = 8 MB flash + 8 MB PSRAM, `N16R8` = 16 + 8, `N32R16V` = 32 + 16 with PSRAM at **1.8 V**. Buying the wrong suffix is the single most common way to end up unable to run the firmware you planned.

### 2.2 Reference Table A — compute, memory, radio, signature I/O

| Chip | 🧠 Core / clock | 🧮 SRAM · PSRAM | 📡 Radio | 📌 GPIO | 🔌 Signature I/O | 😴 Deep sleep |
|---|---|---|---|---|---|---|
| **ESP32** | 2× Xtensa LX6 · 240 MHz | 520 KB · 2 MB in-pkg | Wi-Fi 4 · BT 4.2 **Classic**+LE | 34 | 2× 8-bit DAC, 10 touch, Ethernet MAC 10/100, DVP camera via I2S · ❌ no USB | 10 µA |
| **ESP32-S2** | 1× LX7 · 240 MHz | 320 KB · external | Wi-Fi 4 · ❌ no Bluetooth | 43 | USB-OTG, 2× DAC, 14 touch | 25 µA ⚠️ |
| **ESP32-S3** | 2× LX7 · 240 MHz | 512 KB · **2 / 8 / 16 MB in-pkg** | Wi-Fi 4 · BLE 5 (5.4 cert) | 45 | USB-OTG + USB Serial/JTAG, DVP camera, parallel/RGB LCD, **128-bit SIMD (PIE)** 🤖 | 7 µA |
| **ESP32-S31** 🆕 | 2× RISC-V · 320 MHz | 512 KB · — | Wi-Fi 6 (2.4) · BT **Classic** + LE 5.4 · 802.15.4 | 60 | **Gigabit Ethernet MAC**, SIMD (no NPU) | 12 µA |
| **ESP32-C2** | 1× RISC-V · 120 MHz | 272 KB · ❌ | Wi-Fi 4 · BLE 5 (5.3) | 14 | ❌ no USB · QFN24 4×4 mm | 5 µA 🏆 |
| **ESP32-C3** | 1× RISC-V · 160 MHz | 400 KB · ❌ | Wi-Fi 4 · BLE 5 (5.4) | 22 (16 on C3FH4X) | USB Serial/JTAG, 6-ch ADC | 5 µA 🏆 |
| **ESP32-C6** | 1× RISC-V 160 MHz + LP RISC-V 20 MHz | 512 KB · ❌ | **Wi-Fi 6** (2.4) · BLE 5 (5.3) · **802.15.4** | 30 (22 in FH4/FH8 modules) | 2× TWAI/CAN, LP core runs during sleep | 7 µA |
| **ESP32-C61** | 1× RISC-V · 160 MHz | 320 KB · in-pkg options | Wi-Fi 6 (2.4) · BLE 6.0 · ❌ no 802.15.4 | 30 | cost-reduced C6 | 10 µA |
| **ESP32-C5** | 1× RISC-V · 240 MHz | 384 KB · in-pkg options | **Wi-Fi 6 dual-band 2.4 + 5 GHz** 🏆 · BLE 6.0 · 802.15.4 | 29 | only 5 GHz part in the family | 12 µA |
| **ESP32-H2** | 1× RISC-V · 96 MHz | 320 KB · ❌ | ❌ no Wi-Fi · BLE 5 (5.3) · 802.15.4 | 19 | QFN32 4×4 mm, coin-cell class | 7 µA |
| **ESP32-H4** ⏳ | 2× RISC-V · 96 MHz | 384 KB · ❌ | ❌ no Wi-Fi · BLE 5.4 · 802.15.4 | 40 | sampling since Mar 2026, no public datasheet | ❌ not published |
| **ESP32-H21** ⏳ | 1× RISC-V · 96 MHz | 320 KB · ❌ | ❌ no Wi-Fi · BLE · 802.15.4 | 19 | on-chip DC-DC, up to 20 dBm TX | 5 µA ⚠️ |
| **ESP32-P4** | 2× RISC-V · **400 MHz** (v3.x) / 360 MHz (v1.x) | **768 KB · 16 or 32 MB in-pkg** 🏆 | ❌ **none** — boards add a C6 | 55 | MIPI-CSI + ISP, MIPI-DSI, **hardware H.264 + JPEG**, **USB 2.0 High-Speed OTG**, Ethernet MAC, SIMD + DSP 🤖 | 12 µA (⚠️ light sleep 75–800 µA) |
| **ESP32-E22** ⏳ | radio co-processor, not an MCU | — | Wi-Fi 6E tri-band + BT, PCIe/SDIO to a Linux host | — | companion silicon only | — |

⏳ not buyable on a board · 🏆 best in class · ⚠️ conditional, read the note

### 2.3 Reference Table B — toolchain, third-party ecosystem, confidence

**How the confidence figure is built** ⚠️ *(my composite, not a vendor metric)*: silicon maturity × board availability today × toolchain support (ESP-IDF, Arduino core, ESPHome, MicroPython). A 🔴 score does not mean bad silicon — it means you will be the one writing the drivers.

| Chip | 🧩 Toolchains & third-party ecosystem | 🎯 Primary use | 🎚️ Confidence |
|---|---|---|---|
| **ESP32** | Arduino ✅ · ESP-IDF ✅ · ESPHome ✅ · MicroPython ✅ · Zephyr ✅ · **147 boards catalogued** · LoRa/Meshtastic (Heltec, TTGO), Grove, Feather, every legacy shield | Anything generic. The only hobby board with **BT Classic / A2DP audio** | 🟢 10/10 |
| **ESP32-S2** | Arduino ✅ · IDF ✅ · MicroPython ✅ · CircuitPython ✅ · LOLIN S2 Mini, Adafruit MagTag · 26 boards | USB-HID gadgets, badges, e-paper | 🟡 7/10 |
| **ESP32-S3** | Arduino ✅ · IDF ✅ · ESPHome ✅ · MicroPython ✅ · CircuitPython ✅ · **74 boards** · XIAO, Feather, T-Display-S3, ESP32-S3-BOX, Korvo audio kits, Heltec LoRa V4 | **Displays, cameras, audio, on-device ML** | 🟢 10/10 |
| **ESP32-S31** | IDF v6.1 **preview only** ⚠️ · ❌ no Arduino core · datasheet marked preliminary · Espressif's own boards only | Nothing production-critical yet. Read about it, don't build on it | 🔴 3/10 |
| **ESP32-C2** | IDF ✅ · practically no dev boards | High-volume product PCBs where unit cost dominates | 🟡 5/10 |
| **ESP32-C3** | Arduino ✅ · IDF ✅ · ESPHome ✅ · MicroPython ✅ · CircuitPython ✅ · Zephyr ✅ · C3 Super Mini (~$2), **01Space C3 0.42″ OLED**, XIAO C3 · 25 boards | Cheapest real Wi-Fi + BLE node | 🟢 9/10 |
| **ESP32-C6** | Arduino ✅ · IDF ✅ · ESPHome ✅ · MicroPython ✅ · XIAO C6, C6 Super Mini, DevKitC-1 · also ships as the **radio companion on every P4 board** | **Matter / Thread / Zigbee**, modern Wi-Fi sensor nodes | 🟢 9/10 |
| **ESP32-C61** | IDF ✅ · Arduino ⚠️ · ❌ no hobby boards catalogued | Volume Wi-Fi 6 product designs | 🟡 5/10 |
| **ESP32-C5** | IDF v6.0 ✅ · Arduino stable ✅ · ESPHome still maturing ⚠️ · DevKitC-1 ~$14, few boards | When 2.4 GHz is unusable — dense buildings, industrial sites | 🟡 7/10 |
| **ESP32-H2** | IDF ✅ · Arduino ⚠️ · Zigbee2MQTT / Home Assistant ✅ · H2 Super Mini, DevKitM-1 (2 boards) | Battery Zigbee/Thread end devices | 🟡 7/10 |
| **ESP32-H4** | IDF preview ⚠️ · ❌ no Arduino · ❌ no boards | — (plan with the H2) | 🔴 2/10 |
| **ESP32-H21** | IDF preview ⚠️ · ❌ no datasheet · ❌ no boards | — (plan with the H2) | 🔴 1/10 |
| **ESP32-P4** | IDF since v5.3 ✅ · Arduino stable ✅ · boards from Espressif, **M5Stack Tab5**, Waveshare, Elecrow CrowPanel, Wireless-Tag · ⚠️ **two silicon generations** — see §3.2 | **Max compute, MIPI HMI, edge vision, on-device LLM** | 🟡 7/10 |
| **ESP32-E22** | Linux host driver only | Not applicable to MCU projects | 🔴 1/10 |

### 2.4 What "run an LLM on an ESP32" actually means — the four tiers

This taxonomy matters more than any spec row, because almost every viral demo is Tier 4 wearing Tier 1 clothing. ✅ *(theaivibe.org survey, Aug 2026)*

| Tier | What it is | Example | Honest label |
|---|---|---|---|
| **1** | Weights **and** compute both on the MCU | `slvDev/esp32-ai` — 28.9M params on an S3 | True on-device |
| **2** | Compute on the MCU, weights streamed from a host at boot | `cyfrit/p-for-llm` — 180.9M on a P4 over USB | On-device inference with an umbilical |
| **3** | Model sharded across several MCUs over radio | `esp32s3-distributed-ai` — 56M across 3× S3 over ESP-NOW | Research toy |
| **4** | MCU records audio, cloud does the thinking | Every polished "AI assistant on ESP32" video — **including Espressif's own official ESP LLM Solution** | A microphone with Wi-Fi |

Your requirement ("run a very small LLM and chat with that implementation") is Tier 1 or Tier 2. Tier 2 becomes Tier 1 the moment the weights live on an SD card instead of arriving over USB.

### 2.5 The two proven on-device demonstrations

**ESP32-S3 — `slvDev/esp32-ai`** ✅
- 28.9M parameters, 4-bit, **14.9 MB** model file, **~9.5 tok/s**, on an ~$8 board with 512 KB SRAM + 8 MB PSRAM + 16 MB flash.
- The trick is a memory hierarchy, not a faster CPU: a ~560K-parameter dense reasoning core lives in SRAM/PSRAM, while ~25M parameters sit in flash as a memory-mapped embedding table. Generating one token touches roughly **six rows, ~450 bytes of flash reads**. The idea is Google's Per-Layer Embeddings, borrowed from Gemma 3n.
- ❌ **It cannot converse.** Trained on TinyStories; it writes short children's stories and nothing else. Its own author says it will not answer questions, follow instructions, or write code.
- Lineage: DaveBben's 2024 `esp32-llm` (260K params, 19.13 tok/s, ESP-DSP dot products + both cores) → this. Both descend from Karpathy's `llama2.c`.

**ESP32-P4 — `cyfrit/p-for-llm`** ✅
- **180,920,432 parameters.** 12 layers, hidden 192, vocab 32,768 (pruned from Qwen3.5), 6 Q heads / 2 KV heads, **29 experts per layer with Top-1 routing**, expert FFN 512, PLE dimension 176, context 1,024, **W1.58A8 ternary quantization** (BitNet style).
- **~9 tokens/s** on ESP32-P4 v1.3 at 360 MHz. Has ChatML instruct formatting **and** a working (unstable) tool-calling agent loop.
- Memory layout: MoE weights in PSRAM, PLE weights in flash accessed via XIP, cache and working memory in DIRAM. Runtime uses Espressif **XespV** acceleration — the author measured up to **30× speedups** in XespV tests during development.
- Target board: **WT9932P4-Tiny**, 32 MB PSRAM + 16 MB flash, CNY 39.9 (~USD 6) on Taobao, ~USD 10 on AliExpress.
- ⚠️ ~44 MiB total across flash and PSRAM. The board's flash cannot hold it, so weights transfer over USB at startup. **An SD card removes the host entirely** — listed as future work by the author, not done.
- ⚠️ Trained on ~12B tokens using a single RTX 5060 Ti. Author's own words: output often goes off the rails; the agent capability is not general-purpose (fixed tool prompt).

---

## 3. Candidates for this build — pros / cons checklists

Only chips that could plausibly host the device are evaluated. C2, C61, H2, H4, H21, E22 are excluded on memory grounds and are not revisited.

### 3.1 ESP32-S3 — Espressif · SAFE INCUMBENT
✅ Up to **16 MB octal PSRAM in-package** — the only non-P4 part that can hold a model
✅ **128-bit SIMD (PIE)** used by ESP-NN / ESP-DL / ESP-DSP; the S3 dot-product routines are why the early ports were fast
✅ Full ESP-SR support: AFE, WakeNet9/9l/10, MultiNet mn5q8/mn6/mn7 in Chinese **and English**
✅ Only target with a working English/French offline TTS path (`DiUS/esp-picotts`)
✅ Native USB-OTG + USB Serial/JTAG; 45 GPIO; 74 boards; every framework
✅ ~$3.50 modules, ~$8 boards, ~$15 official DevKitC
⚠️ Dual 240 MHz Xtensa — roughly **half** the P4's CoreMark
⚠️ Buy the right suffix: you need **N16R8** minimum (16 MB flash / 8 MB PSRAM) for the 14.9 MB model
❌ **No chat-capable model exists for it.** The 28.9M ceiling is a storyteller
❌ No DAC (the original ESP32 and S2 have two); audio out needs an I2S codec or class-D amp
❌ Wi-Fi 4 only, BLE only — no Bluetooth Classic

### 3.2 ESP32-P4 — Espressif · THE PICK
✅ **Fastest ESP32:** dual 400 MHz RISC-V, ~1.9–2.1× the S3 on CoreMark, with SIMD **and** DSP extensions
✅ **16 or 32 MB in-package PSRAM** — 4× the S3's practical ceiling, and the reason a 180.9M model fits
✅ 768 KB SRAM (L2MEM) — the largest on-chip working set in the family
✅ **The only ESP32 with a demonstrated instruction-following model** (`p-for-llm`, ~9 tok/s, ChatML + agent)
✅ Full ESP-SR support: AFE, WakeNet9, **MultiNet mn7_en / mn7_cn**
✅ USB 2.0 **High-Speed** OTG, MIPI-DSI + MIPI-CSI with ISP, hardware H.264/JPEG, 10/100 Ethernet MAC, 55 GPIO
✅ ESP-IDF since v5.3, Arduino core stable; boards from ~$6 (WT9932P4-Tiny) to ~$60 (M5Stack Tab5)
⚠️ **Two silicon generations.** v1.x = 360 MHz, part numbers P4NRW16/32, **EOL**. v3.x = 400 MHz, NRW16X/32X, **requires a new PCB and ESP-IDF v6**. The released `p-for-llm` firmware targets pre-v3 at 360 MHz — newer revisions need a rebuild from source with matching config. Check which generation a board carries *before* ordering.
⚠️ The v3.x datasheet is still pre-release
⚠️ Light sleep is 75–800 µA. This is not a battery chip
❌ **No radio at all.** Every board pairs it with an ESP32-C6 over SDIO — board space and cost you pay whether or not you use it
❌ Only 2 boards catalogued on espboards; the ecosystem is thin compared to the S3
❌ ES8311 codec examples fail under `arduino-esp32` on Waveshare P4 boards but work under ESP-IDF — build the audio path in IDF from day one

### 3.3 ESP32-S31 — Espressif · TOO NEW
✅ Dual-core RISC-V 320 MHz, Wi-Fi 6, BT Classic **and** LE 5.4, Thread/Zigbee, gigabit Ethernet, 60 GPIO — genuinely the best-rounded radio silicon in the family
✅ ESP-SR added preliminary S31 target support in May 2026
⚠️ Mass production only since **July 2026**
❌ ESP-IDF v6.1 support is **preview-level**; datasheet marked preliminary
❌ **No Arduino core.** No third-party boards. No PSRAM story published
❌ Zero LLM ports exist for it

### 3.4 ESP32-C3 (01Space 0.42″ OLED board) — the board you mentioned · DISQUALIFIED, USEFUL ANYWAY
✅ Exactly the form factor you're picturing: USB-C stick, ceramic antenna, integrated **0.42″ 72×40 SSD1306 OLED on I²C (SDA GPIO5, SCL GPIO6)**, ~$9
✅ Broad support — Arduino, IDF, **Zephyr** (`esp32c3_042_oled`), CircuitPython (`01Space 0.42 OLED ESP32C3`)
⚠️ 13 usable GPIO; max sketch ~1.25 MB with 320 KB for data
❌ **No PSRAM.** 400 KB SRAM total. This is the disqualifier — no memory tier to hold weights
❌ Single 160 MHz RISC-V core, **no SIMD**
❌ No native USB (on-chip USB-serial converter only), no I2S-grade audio ambitions
→ Keep it as the **status/telemetry display** on the finished device, or as the throwaway test rig for the I²C eye-driver code. It is not the compute.

---

## 4. Decision matrix

Lens: can this part host a chat-capable on-device LLM **and** the voice + eyes I/O?

| Chip | PSRAM ceiling | SIMD | Full-duplex I2S | 2 display buses + SD | Chat-capable model exists | Boards today | **Fit** |
|---|---|---|---|---|---|---|---|
| **ESP32-P4** | ✅ 32 MB | ✅ SIMD+DSP | ✅ | ✅ | ✅ `p-for-llm` 180.9M | ⚠️ few, ~$6–60 | ✅ **Yes** |
| **ESP32-S3** | ⚠️ 16 MB | ✅ 128-bit PIE | ✅ | ✅ | ❌ storyteller only | ✅ 74 | ⚠️ I/O only |
| **ESP32-S31** | ❌ unpublished | ✅ SIMD | ✅ | ⚠️ | ❌ none | ❌ Espressif only | ❌ No |
| **ESP32-C6** | ❌ none | ❌ | ⚠️ | ❌ | ❌ | ✅ many | ❌ radio companion only |
| **ESP32-C5** | ⚠️ in-pkg opt. | ❌ | ⚠️ | ❌ | ❌ | ⚠️ few | ❌ No |
| **ESP32-C3** | ❌ none | ❌ | ❌ | ❌ | ❌ | ✅ many | ❌ No |
| **ESP32** (classic) | ⚠️ 2 MB | ❌ | ✅ | ⚠️ | ❌ | ✅ 147 | ❌ No |

A matrix with one ✅ row is itself the finding: this is not a close call, it is a single-option decision constrained by one repository's existence.

---

## 5. Recommendation by intent

| If your objective is… | Take | Why |
|---|---|---|
| **A true on-device LLM you can talk to** (your stated goal) | **ESP32-P4 32 MB + ESP32-S3 N16R8 front-end** | Only combination where every requirement has a working implementation today |
| A single-board, single-chip demo you can finish this month | **ESP32-S3 N16R8** running `slvDev/esp32-ai` + PicoTTS + 2 OLEDs | Everything is proven on one die — accept that it tells stories rather than converses |
| A device that genuinely *converses* well | **ESP32-S3 as I/O + Qwen3-1.7B on WS-002 or an N150 mini-PC** over Wi-Fi | Tier 4 by the taxonomy, but the only path to output quality you won't throw away |
| The cheapest way to prototype the eyes and audio while you wait for parts | **ESP32-S3 Super Mini** + the C3 0.42″ OLED board you already know | Driver code ports straight to the P4 build |
| Lowest-risk long-term platform | **ESP32-S3** | 🟢 10/10 confidence; the P4 is 🟡 7/10 with a silicon-generation trap |

---

## 6. The build — architecture, BOM, software

### 6.1 Why the workload must split across two chips

Budget arithmetic on the WT9932P4-Tiny ⚠️ *(inference from confirmed figures)*:

| Item | Size |
|---|---|
| Board total addressable | 32 MB PSRAM + 16 MB flash = **48 MB** |
| `p-for-llm` weights | **~44 MiB** |
| Remaining | **~4 MB, minus firmware** |
| ESP-SR AFE + WakeNet9 working set | needs PSRAM |
| PicoTTS | ~1.1 MB RAM + 750–1400 KB flash for language resources |

The audio stack does not fit in what's left. Either shrink the model (defeating the purpose) or move the I/O to its own chip. Move the I/O.

### 6.2 Topology

```
┌─────────────────────────────┐         ┌──────────────────────────────┐
│  ESP32-P4  ·  32 MB PSRAM   │  UART   │  ESP32-S3 N16R8              │
│  ─────────────────────────  │ 921600  │  ──────────────────────────  │
│  p-for-llm runtime          │◄───────►│  ESP-SR AFE + WakeNet9       │
│  MoE weights → PSRAM        │ or SPI  │  MultiNet mn7_en (commands)  │
│  PLE weights → flash (XIP)  │         │  PicoTTS  (EN / FR)          │
│  microSD (SDMMC) = weights  │         │  I2S mic in · I2S amp out    │
│  no radio needed            │         │  2× µOLED "eyes"             │
└─────────────────────────────┘         └──────────────────────────────┘
                                                    │
                                    (optional) ESP32-C6 for Wi-Fi
                                    fallback ASR against WS-002
```

Protocol between them: line-delimited text, or ChatML frames if you want the P4 side unchanged. The S3 is the master — it owns the wake word, the turn-taking, and the eye animation; the P4 is a text-in/text-out coprocessor.

### 6.3 Bill of materials ⚠️ *(standard parts, not verified on your bench)*

| # | Function | Part | Notes |
|---|---|---|---|
| 1 | LLM compute | **WT9932P4-Tiny** (ESP32-P4, 32 MB PSRAM, 16 MB flash) | ~$6 Taobao / ~$10 AliExpress. ✅ Confirm silicon rev v1.3 vs v3 before ordering |
| 2 | I/O compute | **ESP32-S3 N16R8** dev board | 16 MB flash / 8 MB PSRAM. ⚠️ Verify **Tools ▸ PSRAM ▸ OPI PSRAM** before every compile — it resets silently after reflash |
| 3 | 🎤 Mic | **INMP441** (budget) or **ICS-43434** (better SNR), I2S MEMS | ESP-SR AFE requires 16 kHz / 16-bit / mono |
| 4 | 🔊 Amp | **MAX98357A** I2S class-D → 4 Ω or 8 Ω speaker | Simplest path. No DAC on the S3, so I2S is mandatory |
| 4b | 🔊 Alternative | **ES8311** codec (ADC + DAC in one) + small PA | Required if you want hardware AEC — the reference part on Espressif/Waveshare audio boards. ❌ Arduino support broken on P4; use ESP-IDF |
| 5 | 👀 Eyes ×2 (mono) | **SSD1306 / SH1107 µOLED**, I²C at **0x3C and 0x3D** | Two on one bus, **no multiplexer needed**. The only genuinely-OLED option at this size |
| 5b | 👀 Eyes ×2 (colour) | **GC9A01 240×240 round**, shared SPI + separate CS lines | ⚠️ LCD, not OLED — but this is what every "robot eyes" build uses, and it's LVGL-ready |
| 6 | 💾 Weight storage | microSD over **SDMMC** on the P4 | Turns the build from Tier 2 into Tier 1. ❌ Not implemented upstream — this is your work |
| 7 | 📡 Optional radio | ESP32-C6 (already on most P4 boards) | Only needed for cloud-ASR fallback or OTA |

### 6.4 Software stack — what exists, what's missing

| Layer | Available today | Status |
|---|---|---|
| Wake word | ESP-SR **WakeNet9 / 9l / 10** on S3 and P4. Ready-made English wake words: Alexa, Jarvis, Computer, Hey Willow, Sophia, Mycroft, Hi ESP, Hi M Five | ✅ production-grade — it ships in Home Assistant |
| Audio front-end | ESP-SR **AFE**: AEC, VAD/VADNet, BSS, noise suppression, NSNET; new full-duplex AEC (Apr 2026), GSC beamforming + DOA (Aug 2026) | ✅ |
| Command ASR | **MultiNet** `mn7_en` / `mn7_cn` — up to 300 commands, custom commands without retraining. Must run downstream of WakeNet | ⚠️ **fixed command set, not dictation** |
| Free-form ASR | — | ❌ **nothing production-grade on any ESP32** |
| TTS (Chinese) | Espressif `esp-tts` — parser + synthesizer, mono 16-bit @ 16 kHz, streaming output | ✅ but Chinese only |
| TTS (EN / FR) | **`DiUS/esp-picotts`** — ESP-IDF port of PicoTTS. 175 KB code, 750–1400 KB flash per language, ~1.1 MB RAM while initialised. Real-time on an S3 that isn't doing much else | ⚠️ LPC-era voice quality; author notes CPU contention when sampling and synthesising simultaneously |
| LLM runtime | `cyfrit/p-for-llm` on P4 · `slvDev/esp32-ai` on S3 · both descend from `karpathy/llama2.c` | ⚠️ hobbyist projects, MIT-licensed, 5 commits |

**The one constraint that shapes the whole UX:** there is no offline free-form speech recognition for this silicon. Pick one of three:
- **(a)** Voice input = MultiNet's ≤300 fixed commands; the LLM handles everything downstream of a recognised command. Fully offline, limited vocabulary.
- **(b)** Stream audio over Wi-Fi (via the C6) to WS-002 running Whisper; LLM stays local on the P4. Hybrid, needs the network.
- **(c)** Voice for wake + confirmation only; the actual chat happens as text over UART/USB. Simplest, least magical.

### 6.5 Build order

1. **Prove the model first, bare.** Flash `p-for-llm` on the P4 exactly as released (USB weight loading, terminal chat). If the output quality is unacceptable to you, stop here — everything downstream is wasted effort.
2. Benchmark tokens/s yourself with `esp_timer` before buying v3 silicon. See §7.
3. Bring up the S3 front-end standalone: WakeNet → MultiNet → PicoTTS loop with mic and speaker, no LLM. Verify AEC actually cancels your own speaker.
4. Drive the two eyes from the S3. I²C dual-address first — it's four wires and no arbitration.
5. Join the two chips over UART. Text frames only.
6. Move the weights to SD card on the P4. This is the piece nobody has written.

---

## 7. Self-critique & counter-arguments

**The strongest case that this recommendation is wrong.** The P4 model's own author describes its output as often little more than nonsense that frequently goes off the rails, trained on ~12B tokens by one person on a single RTX 5060 Ti. Judged as a conversational device, it will underperform a rule-based chatbot from 2005. For roughly the same €80 in parts, an N150 mini-PC or an Orange Pi running Qwen3-1.7B gives a genuinely useful assistant with an €8 ESP32-S3 as the voice-and-eyes front-end. **The P4 path buys "true on-device" and pays for it with "useful."** If the objective is the engineering artifact — and your phrasing suggests it is — take the P4. If the objective is a thing you enjoy talking to, split the LLM off the MCU and stop pretending Tier 4 is a compromise.

**Where the matrix compares confirmed and unconfirmed as if equal.** The "chat-capable model exists" column carries a 3-star, 5-commit GitHub repository as if it were a product. It is one person's project, one month old, with no forks and no independent replication. If that repo is abandoned or turns out not to reproduce, the P4's advantage over the S3 evaporates and the honest answer becomes "no ESP32 chats."

**Where a spec sheet is being trusted over the bench.** The v1.x → v3.x jump is 360 → 400 MHz, about 11% clock. Ternary MoE inference at this scale is almost certainly **PSRAM-bandwidth-bound, not compute-bound** — meaning the v3 silicon may buy nearly zero additional tokens/second while costing a new PCB and an ESP-IDF v6 migration. Measure before you spend. This is also the reason "just use a bigger model on the 32 MB part" will not work the way the parameter count suggests.

**Coverage deliberately excluded.** Non-ESP32 alternatives at the same price point — RP2350, nRF54, K230, RK3576 — were not evaluated, because the question was scoped to ESP32. At least two of them are better LLM hosts than anything Espressif ships. That exclusion is yours to lift.

**A second-order risk.** Espressif's own roadmap treats microcontrollers as LLM *clients* — its official "ESP LLM Solution" is explicitly cloud inference, and the newest silicon (S31) added radios and SIMD, not neural hardware. You are building against the grain of the vendor's direction. That is not fatal, but it means no first-party support is coming.

---

## 8. Open items — resolve before ordering

- ❌ **Which silicon revision** the WT9932P4-Tiny units currently shipping actually carry (v1.3 vs v3.x). The released firmware targets pre-v3 at 360 MHz; v3 needs a source rebuild. Ask the seller, and verify with `esp_chip_info()` on arrival.
- ❌ **Does `p-for-llm` reproduce?** No independent replication found. Nobody has published a second run.
- ❌ **Is `sherpa-onnx` int8 streaming Zipformer viable on the P4?** This is the only credible route to free-form offline ASR and I have no datapoint on it. Would change option (a)/(b)/(c) in §6.4 entirely.
- ❌ **SD-card weight loading on the P4** — listed as future work upstream, not implemented. Estimate the effort before committing to a fully offline device.
- ⚠️ **Whether ESP-SR AFE + PicoTTS + two displays actually fit in an S3 N16R8** alongside your own application code. PicoTTS alone claims ~1.1 MB RAM; measure, don't assume.
- ⚠️ **Round µOLED part selection.** GC9A01 is an LCD. True round AMOLED modules exist at 1.19–1.43″ but I have not verified controller, interface or price this session.
- ⚠️ **Power budget.** P4 light sleep is 75–800 µA and the S3 is awake for wake-word detection. If this device is ever meant to run on a battery, that number needs a real measurement, not a datasheet row.

---

## Appendix A — glossary

| Term | Meaning |
|---|---|
| **PSRAM** | Pseudo-static RAM, external or in-package, reached over SPI/octal SPI. Large but slow relative to SRAM. The binding constraint for on-device LLMs |
| **SRAM / DIRAM** | On-die fast memory. The S3 has 512 KB, the P4 768 KB. Holds activations and hot weights |
| **XIP** | eXecute In Place — reading data directly from flash without copying to RAM. How `p-for-llm` reaches its PLE weights |
| **PLE** | Per-Layer Embeddings. Google's Gemma 3n idea: park most parameters in an embedding table read a few rows at a time, keep only the dense core in RAM |
| **MoE / Top-1 routing** | Mixture of Experts. Many expert FFNs per layer; only one fires per token. Big parameter count, small per-token compute |
| **W1.58A8 / ternary** | Weights quantized to {-1, 0, +1} (log₂3 ≈ 1.58 bits), activations at 8 bits. BitNet-style |
| **SIMD / PIE / XespV** | Vector instruction sets. PIE on the S3, XespV on the P4. **Not** an NPU |
| **AFE** | Espressif's Audio Front-End: echo cancellation, voice activity detection, noise suppression, source separation |
| **WakeNet / MultiNet** | ESP-SR's wake-word engine and fixed-command recogniser |
| **AEC** | Acoustic Echo Cancellation — stops the device hearing its own speaker. Mandatory if mic and speaker share an enclosure |
| **I2S** | Serial audio bus. Both the MEMS mic and the class-D amp use it |
| **SDMMC** | The fast 4-bit SD-card interface, as opposed to SD-over-SPI |
| **Tier 1–4** | The honesty ladder in §2.4 |

---

## Appendix B — sources consulted (2026-09-09)

| Source | Used for |
|---|---|
| espboards.dev — *ESP32 Comparison Chart, All Models 2026* (updated 04 Sep 2026) | Full 14-chip datasheet table, release dates, production status, board counts |
| theaivibe.org — *Running an LLM on an $8 Microcontroller: What's Real in 2026* (15 Aug 2026) | Four-tier taxonomy, PLE explanation, no-NPU claim, S31 positioning |
| github.com/cyfrit/p-for-llm | 180.9M MoE architecture, ~9 tok/s, WT9932P4-Tiny target, 44 MiB budget, USB weight loading |
| github.com/slvDev/esp32-ai (via CNX Software, Hackster, The Register) | 28.9M on S3, 14.9 MB, ~9.5 tok/s, memory tiering |
| github.com/DaveBben/esp32-llm | 260K params, 19.13 tok/s, ESP-DSP + dual-core baseline |
| github.com/espressif/esp-sr + ESP Component Registry v2.1.4 | WakeNet/MultiNet/AFE target support, wake-word list, 2026 changelog |
| docs.espressif.com — ESP-SR speech synthesis (S3) | esp-tts is Chinese only |
| github.com/DiUS/esp-picotts + esp32.com forum thread | English/French offline TTS, resource footprint |
| espboards.dev — ESP32-C3 OLED 0.42″ · Zephyr `esp32c3_042_oled` docs | The USB-stick OLED board's real specs |
| github.com/espressif/arduino-esp32 discussion #12434 | ES8311 broken under Arduino on Waveshare P4, works in IDF |

---

*End of document. Facts marked ✅ were read on 2026-09-09; marks ⚠️ and ❌ are exactly what they say.*
__EW_EOF__
w 'xiaozhi-e32r28t/SOP-001_xiaozhi-e32r28t-bringup_v1_0.yaml' <<'__EW_EOF__'
sop: SOP-001
slug: xiaozhi-e32r28t-bringup
title: xiaozhi voice assistant on E32R28T — bounded bring-up
version: '1.0'
date: 2026-10-02
status: RELEASED
scope: 'Flash, network and voice bring-up of the LCDWiki E32R28T with the Perlinpinpin LAN server. Executed by Claude
  Code (VS Code) under operator gates. Refs: CLAUDE.md v1.1, handoff bundle.'
hazards:
- tag: ELEC
  text: Header wiring on a powered board can short 3V3/5V. Unplug USB before touching wires; buzz pins first.
tools:
- Perlinpinpin (Xubuntu 26.04) + VS Code + Claude Code extension
- USB-C cable, phone (Wi-Fi portal + LAN test), multimeter
materials:
- LCDWiki E32R28T board
- INMP441 mic, MAX98357A amp, 4-8 ohm speaker, 1.25 mm pigtails
phases:
- name: GUARD
  steps:
  - do: Paste the bounded prompt into Claude Code
    detail: Listed commands only. Stop at every gate. One retry max.
  - gate: Claude Code restated the stop rule?
    fail: Do not proceed. Re-paste prompt in a fresh Claude Code chat.
- name: FLASH
  steps:
  - do: Run flash.sh on /dev/ttyUSB0
    detail: Timebox 15 min. Prebuilt image, checksum-verified.
  - gate: esptool ends with hash verified?
    fail: Hold BOOT, tap EN, release, rerun once. Still failing - STOP, paste output.
- name: DISPLAY
  steps:
  - do: Watch first boot on the LCD
    detail: Timebox 5 min.
  - gate: UI upright, colours correct?
    fail: Note symptom and continue. Fix deferred to one later rebuild.
- name: WIFI
  steps:
  - do: Join Xiaozhi-XXXX portal from phone
    detail: 192.168.4.1, pick Yokohama AI 5G. Timebox 10 min.
  - gate: Device leaves portal mode, online?
    fail: Re-enter credentials once. Still failing - STOP.
- name: SERVER
  steps:
  - do: Run server/setup-server.sh once
    detail: Timebox 60 min (downloads). No git pull, no manual installs.
  - gate: Exit 0, both patches reported?
    fail: STOP. Paste last 30 lines. No improvised fixes.
  - do: Run start.sh with WS002_IP set
    detail: Picks LM Studio if up, else Z.AI GLM fallback.
  - gate: OTA URL returns JSON from the phone?
    fail: STOP. Report whether 8090 health or 8003 OTA failed.
- name: LINK
  steps:
  - do: Set OTA URL in device portal Advanced
    detail: http://<Perlinpinpin IP>:8003/xiaozhi/ota/ . Timebox 10 min.
  - gate: Server log shows the device connected?
    fail: Re-check URL text once. Still failing - STOP.
- name: PARTS
  steps:
  - gate: INMP441, MAX98357A, speaker in hand?
    fail: END at milestone A (flashed, online, linked). Order parts; resume here.
  - do: Unplug USB, wire SPI header
    detail: IO18 BCLK, IO23 WS, IO19 mic SD, IO27 amp DIN. Mic L/R to GND.
    hazard: ELEC
  - gate: Continuity matches CLAUDE.md wiring table?
    fail: Rewire before any power. No power on doubt.
    hazard: ELEC
- name: VOICE
  steps:
  - do: Say Jarvis, then a French question
    detail: Timebox 15 min.
  - gate: Spoken French reply within ~5 s?
    fail: STOP. Paste ASR, LLM, TTS timing lines. No tuning in this SOP.
end_state: Saying "Jarvis" plus a French or English question on the E32R28T yields a spoken reply, served only by
  Perlinpinpin on the LAN (Parakeet ASR, LM Studio or GLM fallback, Pocket TTS). No change outside the project folder,
  ~/xiaozhi-esp32-server and ~/pocket-tts.
changelog:
- v: '1.0'
  date: 2026-10-02
  note: Initial. Gated bring-up; timeboxes; single-retry stop rule.
brand:
  brand: ESP32 WONDERS
  tagline: Perlinpinpin lab — bounded procedures
__EW_EOF__
w 'xiaozhi-e32r28t/e32r28t-xiaozhi-handoff-v1.0.md' <<'__EW_EOF__'
# xiaozhi on LCDWiki E32R28T — Claude Code handoff (Perlinpinpin)

**v1.1 · 2026-10-01** (voice stack: local Parakeet ASR + Pocket TTS from Hugging Face) · Host: Perlinpinpin (Xubuntu 26.04, user `hackinblue`, in `dialout`) · Board on `/dev/ttyUSB0`

## Authority
**`SOP-001_xiaozhi-e32r28t-bringup_v1_0.yaml` governs order, gates, retries and stops.** This file is reference data. Operator prompt: `PROMPT-claude-code.txt`.

## Constraint (operator, non-negotiable)
**LAN only. No VPS, no tunnels, no port forwarding.** Topology: ESP32 → Wi-Fi → Perlinpinpin (xiaozhi-server) → LAN → WS-002 (LM Studio). Experiment scope — do not propose remote/VPS paths.

## Context (read once)
- Board: LCDWiki 2.8" **ESP32-32E** (E32R28T): ESP32-D0WD-V3, **4 MB flash, no PSRAM**, ILI9341V 240×320 TN, XPT2046 resistive touch, CH340C USB-serial.
- Board has **no microphone**. Its speaker amp (FM8002E) is fed by the 8-bit DAC on IO26 — poor quality, not used.
- Upstream `78/xiaozhi-esp32` has no port for this board. This folder carries one: `lcdwiki-e32r28t-board.patch` (against upstream `ed5cd7b`, firmware v2.5.1, ESP-IDF v6.1).
- Prebuilt image: `xiaozhi-v2.5.1-lcdwiki-e32r28t-en-jarvis-merged.bin` — UI en-US, wake word **"Jarvis"**, OTA URL = official cloud `https://api.tenclass.net/xiaozhi/ota/` (change at runtime, see step 4). Built clean; **not yet run on hardware**.
- Audio is one duplex I2S bus on the 4-pin "SPI peripheral" header (shared with microSD → **no SD card inserted**).

## Wiring (needs INMP441 mic + MAX98357A amp + 4–8 Ω speaker)
| Header pin | GPIO | INMP441 | MAX98357A |
|---|---|---|---|
| SPI hdr | IO18 | SCK | BCLK |
| SPI hdr | IO23 | WS | LRC |
| SPI hdr | IO19 | SD | — |
| SPI hdr | IO27 | — | DIN |
| expand hdr | 3V3 | VDD | VIN (3V3 works; 5V louder) |
| expand hdr | GND | GND + **L/R→GND** | GND |
MAX98357A GAIN pin floating = 9 dB. ⚠️ The header pin order is not documented: buzz each pin to the module before connecting power.

## Tasks for Claude Code — in order

### 1. Flash (no wiring needed)
```bash
chmod +x flash.sh && ./flash.sh /dev/ttyUSB0
pipx run --spec pyserial pyserial-miniterm --raw /dev/ttyUSB0 115200
```
- If `/dev/ttyUSB0` vanishes on plug-in: `brltty` claimed the CH340 → `sudo apt remove brltty`.
- If esptool cannot sync: hold BOOT, tap RST (EN), release BOOT, rerun.

### 2. Verify display
Expect the xiaozhi status UI, upright, correct colours. If wrong, edit `main/boards/lcdwiki-e32r28t/config.h` and rebuild (step 6):
- mirrored → toggle `DISPLAY_MIRROR_X`
- negative colours → `DISPLAY_INVERT_COLOR true`
- red/blue swapped → `DISPLAY_RGB_ORDER LCD_RGB_ELEMENT_ORDER_RGB`

### 3. Wi-Fi
Network: **"Yokohama AI 5G"** — 5G-cellular WAN router, dual-band 2.4 + 5 GHz (operator-confirmed). The ESP32 joins it on 2.4 GHz.
Device boots into AP mode `Xiaozhi-XXXX` → join from phone → `http://192.168.4.1` → pick SSID.

### 4. Backend — pick one
- **Cloud smoke test (5 min):** keep default OTA URL; screen shows a 6-digit code → bind at xiaozhi.me console. Proves mic/speaker/Wi-Fi end-to-end.
- **Self-hosted (target):** run `server/setup-server.sh`, edit `data/.config.yaml`, then `WS002_IP=<ip> server/start.sh`. Then in the device portal → *Advanced* → OTA URL `http://<PERLINPINPIN_IP>:8003/xiaozhi/ota/`. Open that URL in a browser first — it must return JSON.
  - LLM, two options, picked at launch by `server/start.sh` (probes `http://<WS002_IP>:1234/v1/models`):
    1. **Local** — `LMStudioLLM` on WS-002 when it answers.
    2. **Fallback** — `ZaiGLMLLM` (`glm-4.5-flash`, Z.AI free tier, dedicated ESP32 key already in `.config.yaml`) by default, or `DeepSeekLLM` (`deepseek-v4-flash`): `./start.sh DeepSeekLLM`.
    No runtime failover in the server: if WS-002 drops mid-session, restart `start.sh`. `setup-server.sh` patches thinking-off for `api.z.ai` (upstream only does it for `bigmodel.cn`).
  - Voice, all local on Perlinpinpin CPU, weights from Hugging Face:
    - **In (ASR):** `ParakeetASR` — `nvidia/parakeet-tdt-0.6b-v3` (sherpa-onnx int8, `csukuangfj/...-int8`, ~640 MB). FR + EN + 23 EU languages, punctuation + accents. `patch-parakeet.py` adds `nemo_transducer` to xiaozhi's SherpaASR.
    - **Out (TTS):** `PocketTTS` — `kyutai/pocket-tts` (~100M params) behind `pocket_tts_openai.py` (OpenAI `/v1/audio/speech` shim on `127.0.0.1:8090`, started by `start.sh`). FR model + voice `estelle` when the reply is French, EN + `alba` otherwise. Voice cloning = `--voice-fr/--voice-en path.wav` (needs HF login + accepted terms on `kyutai/pocket-tts`).
    - Cloud alternative kept in config: `EdgeTTS`. Previous ASR kept: `FunASR` (SenseVoice — no French; model not downloaded by default).
    - First check on the box: say a French sentence, read `tmp/server.log` for ASR text + timings; `curl -s localhost:8090/health`.
  - ⚠️ ExpressVPN's kill-switch chains may drop inbound LAN on 8000/8003 — test from the phone before blaming the firmware.

### 5. Acceptance
Say "Jarvis" → LED blue (listening) → reply on speaker, LED green (speaking). BOOT button = toggle chat. LED magenta = config/activation, yellow = connecting, red = fatal.

### 6. Rebuild from source (only if config changes)
```bash
git clone https://github.com/78/xiaozhi-esp32 && cd xiaozhi-esp32 && git checkout ed5cd7b
git apply ../lcdwiki-e32r28t-board.patch
# ESP-IDF v6.1 (~2.5 GB):
git clone -b v6.1 --depth 1 --recursive --shallow-submodules https://github.com/espressif/esp-idf ~/esp/esp-idf
~/esp/esp-idf/install.sh esp32 && . ~/esp/esp-idf/export.sh
python scripts/build.py lcdwiki-e32r28t          # -> build/merged-binary.bin
python scripts/build.py --list-wake-words        # options: Jarvis, Alexa, Computer, "Bonjour ESP", Hi ESP...
```
Wake word / language are set in `main/boards/lcdwiki-e32r28t/config.json` → `sdkconfig_append`.

## Known limits
- No PSRAM → no AFE/AEC on ESP32 (LiteAudioEngine, raw PCM). Speaker can retrigger the mic: keep them apart.
- Perlinpinpin's Celeron G3930 has **no AVX/AVX2** (SSE4.2 only). Sandbox benchmark with AVX disabled, 2 threads: Pocket TTS int8 ≈ 2× real-time warm; Parakeet 4.4 s audio → 0.45 s (AVX2; non-AVX not emulable for ONNX). Real numbers come from the box.
- `TOUCH_IRQ_AS_BUTTON` (tap screen = talk) is off; untested.
__EW_EOF__
w 'xiaozhi-freenove-s3/freenove-s3-xiaozhi-handoff-v1.0.md' <<'__EW_EOF__'
# xiaozhi on Freenove ESP32-S3 + INMP441 + MAX98357A — handoff

**Version:** 1.0 · **Date:** 2026-10-07 · **Host:** Perlinpinpin (Xubuntu 26.04.1, user `hackinblue`, LAN 192.168.1.6)
**Status:** ⚠️ Blocked on one defect: **the mic delivers no usable audio.** Everything else is proven end to end.
**Companions:** `e32r28t-xiaozhi-handoff-v1.0.md` (server bundle, LAN-only constraint) · `SOP-001_xiaozhi-e32r28t-bringup_v1_0.yaml` (gate style)
**Marks:** ✅ confirmed this session (source named) · ⚠️ inference / partial · ❌ insufficient data

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-10-07 | First issue. Build, flash, server install, network path proven; mic defect open. |

---

## 1. Status at close

| Stage | State | Evidence |
|---|---|---|
| ESP-IDF v6.1 toolchain | ✅ | `idf.py --version` → `ESP-IDF v6.1`; commit `fff9895c` |
| Firmware build (GC9A01, en-US, Jarvis) | ✅ | `sdkconfig`: `CONFIG_LCD_GC9A01_240X240=y`, `CONFIG_LANGUAGE_EN_US=y`; `wn9_jarvis_tts` packaged |
| Flash | ✅ | board boots, speaks prompts |
| PSRAM | ✅ | boot log `WakeWordCache: Allocated 64000 bytes in PSRAM` |
| Speaker / amp path | ✅ | Wi-Fi-config voice prompt audible |
| Wi-Fi join | ✅ | board at `192.168.1.160` (server conn log) |
| OTA check → server | ✅ | server log 2026-10-06 23:55:25 and 2026-10-07 01:15:58: device `20:6e:f1:aa:b5:6c`, WebSocket config sent, fw 2.5.1 current |
| WebSocket session | ✅ | BOOT press → handshake 220 ms → `connecting -> listening` (session `ea8b13e6…`) |
| ExpressVPN vs LAN | ✅ | OTA + WebSocket traffic reached 8003/8000 with VPN connected |
| **Mic audio** | ❌ | no wake-word detection, no server ASR line in any BOOT session, record/playback test silent |
| Display | ⏳ | GC9A01 1.28″ (ARCELI) arriving 2026-10-07; firmware already built for it |

---

## 2. Hardware as built

**Board:** Freenove ESP32-S3 WROOM, 16 MB flash (operator), octal PSRAM. Camera stays on its FPC connector (GPIO4–13, 15–18 reserved).
**Ports:** UART USB-C = CH343 `1a86:55d3` → `/dev/ttyACM0`. Use only this port; the firmware drives GPIO19/20 (LCD SPI), so the native-USB port is dead after boot.
**LEDs (operator):** green `ON` = power · blue `IO2` = wired to GPIO2 = **mic SCK**, so it is lit whenever the mic clock runs · GPIO48 = firmware status LED (map §6) · RX/TX = serial activity.
**Ground:** only one free GND header pin on the board (operator).

### 2.1 Wiring

| Module pin | Goes to | Note |
|---|---|---|
| INMP441 VDD | 3V3 | measured 3.33 V ✅ |
| INMP441 GND | board GND (the single pin) | |
| INMP441 L/R | GND | short wire soldered L/R↔GND **on the module**; measured 0 V ✅ |
| INMP441 WS | GPIO1 | measured 1.66 V (clocking) ✅ |
| INMP441 SCK | GPIO2 | measured 1.67 V at mic fillet = GPIO2 header ✅ (first reading 0 V — see §3) |
| INMP441 SD | GPIO42 | ❌ **no value recorded this session** |
| MAX98357A VIN | 5V | |
| MAX98357A GND | female Dupont onto the INMP441 **L/R** pin (bonded to GND) | shares the mic's ground return to the board |
| MAX98357A DIN / BCLK / LRC | GPIO39 / 40 / 41 | |
| MAX98357A GAIN, SD | floating | 9 dB, (L+R)/2 |
| Speaker | green terminal block OUT+/OUT− | black lead broke and was re-terminated |
| GC9A01 (pending) | SCL→19, SDA→20, DC→47, CS→45, RST→21, VCC→3V3, GND→tap | BL pin expected absent ⚠️ — check silkscreen |

**Constraints:** microSD slot must stay empty (GPIO39/40 shared) ✅ Freenove GPIO notes. All module joints passed unpowered pair-wise short tests and module→header continuity. Wires reinforced with heat-shrink; mic acoustic port is on the open front face (operator).

---

## 3. Open defect — mic

**Symptom:** wake word never fires; BOOT opens a session (listening 608→728 s in one run) but the server logs no ASR line; firmware record/playback test (config mode → BOOT) played back silence once. Operator reports many BOOT + speech attempts, none recognized.

**Measured (board powered, idle, black on mic GND):**

| Point | Reading | Reading means |
|---|---|---|
| VDD | 3.33 V | powered, never saw 5 V |
| L/R | 0 V | left slot selected ✅ matches firmware (`I2S_STD_SLOT_LEFT`, `no_audio_codec.cc`) |
| WS | 1.66 V | word clock present |
| SCK | 0.00 V first, then 1.67 V | first reading unexplained ⚠️ (probe placement or a contact that reseated); GPIO2↔SCK continuity beeps |
| SD | — | ❌ not recorded |

**Ruled out:** 5 V damage via the shared ground (VDD 3.33 V); acoustic port blocked (operator: front port open); network/server path (§1).
⚠️ [INFERENCE] IO2's onboard blue LED loads the SCK line; at ~1 MHz with a blue LED's forward voltage the effect should be negligible — revisit only if everything else checks out.

### 3.1 Next reads, in order
1. **Photo** — both sides of the INMP441 (pins + wires readable) and the header end showing which pins the five mic wires sit on. Settles pad assignment, bridges, joints in one pass.
2. **SD line** — DC volts while speaking/clapping: mic SD fillet, then GPIO42 header pin. Changing ~0.1–1.6 V at both = mic outputs data; steady 0 / 3.3 V at the mic = mic or SD joint dead; mic changing but GPIO42 not = SD wire/Dupont.
3. **If the mic is dead** — swap the INMP441 module (spare on hand: ❌ unknown).
4. **If SD is alive at GPIO42 but still no ASR** — capture the board log during a BOOT session (§7) and look for I2S read errors.

---

## 4. Firmware

| Item | Value |
|---|---|
| Source | `~/xiaozhi-s3cam` = `78/xiaozhi-esp32` @ `ed5cd7b` (fw 2.5.1, same as E32R28T) |
| Board type | `bread-compact-wifi-s3cam` (Kconfig `BOARD_TYPE_BREAD_COMPACT_WIFI_CAM`) |
| Local edit | `main/boards/bread-compact-wifi-s3cam/config.json` → `sdkconfig_append`: `CONFIG_LCD_GC9A01_240X240=y` (was ST7789 240×320) |
| Flash layout | 16 MB, `partitions/v2/16m.csv`; app `0x2aa390`, 32 % free |
| Image | `build/merged-binary.bin` (0x9344bf bytes) |
| Toolchain | ESP-IDF v6.1 at `~/esp/esp-idf`; Python env `~/.espressif/python_env/idf6.1_py3.14_env`; esptool 5.4.0 |
| VS Code ESP-IDF extension | installed, never configured (only walkthrough flag in settings) |

`build.py` regenerates `sdkconfig` from `config.json` on every run (`_configure_build`), so editing `config.json` + rerunning is sufficient.

---

## 5. Server

| Item | Value |
|---|---|
| Install | `~/xiaozhi-esp32-server` (xiaozhi-server 0.9.7), via `~/projects/xiaozhi-e32r28t/server/setup-server.sh`, 2026-10-06, exit 0 |
| Patches | ✅ `core/providers/asr/sherpa_onnx_local.py` (Parakeet `nemo_transducer`) · ✅ `core/providers/llm/openai/openai.py` (Z.AI thinking-off) |
| Config | `data/.config.yaml`: lines 10–11 set to `192.168.1.6`; **line 45 `<WS002_IP>` still a placeholder** (only used when LM Studio answers) |
| Pipeline | ASR ParakeetASR · VAD SileroVAD · LLM ZaiGLMLLM (fallback) · TTS PocketTTS `127.0.0.1:8090` (EN + FR) |
| Ports | 8000 WebSocket and 8003 OTA on `0.0.0.0`; 8090 on loopback ✅ `ss -ltnp` |
| Device sees | `ws://192.168.1.6:8000/xiaozhi/v1/` ✅ OTA GET response |
| Persona prompt | "You are Jarvis, Jérôme's terse personal assistant…" |

---

## 6. Hints & gotchas

- **Status LED (GPIO48)** ✅ `main/led/single_led.cc`: fast blue blink = starting · slow blue blink = Wi-Fi config portal · solid blue = connecting (after BOOT/wake word only) · **off = idle** · red = listening / audio test · solid green = speaking or prompt · green blink = activating (OTA check). The blue IO2 LED is **not** a status LED.
- **Boot sequence** ✅ `application.cc`: starting → activating (OTA) → idle. Solid blue never appears at boot without a BOOT press.
- **Enter Wi-Fi config mode:** tap RST, press BOOT within ~1 s (the starting window is short once Wi-Fi is saved). ✅ board `.cc` 157–160.
- **BOOT during a voice prompt** cancels the prompt and acts as a normal chat press ✅ `application.cc` 783–786. Wait for the prompt to finish.
- **Audio record/playback test:** in config mode, BOOT = start recording, BOOT again = stop ✅ `application.cc` 791–797; ⚠️ playback on stop inferred.
- **Wi-Fi portal saves without rebooting** ✅ boot log: credentials saved, board stayed in portal mode. Tap RST after saving.
- **Closing the server terminal stops the server.** The board's boot-time OTA check then fails. Restart `start.sh` before rebooting the board.
- **Don't run the server from a shell with ESP-IDF exported** ⚠️ — IDF's Python env sits first on `PATH`.
- **Server banner shows `100.64.100.6`** (ExpressVPN `tun0`) — cosmetic; the device is sent `192.168.1.6` ✅.
- **Warning `Server sample rate 16000 does not match device output 24000`** — distortion risk only, not acted on.
- **Reserve 192.168.1.6 in router DHCP** — it is baked into `.config.yaml` and the board's stored OTA URL. ❌ not done.
- **Unrelated, same box:** an old terminal showed `meshtasticd 2.8.1…~unstable` installed from the OBS **daily** Debian 13 repo. Current state unverified: `apt policy meshtasticd`. Meshtastic plan calls for the Beta PPA (2.7.26).

---

## 7. Cheat sheet

```bash
# Server (own terminal, no IDF env)
WS002_IP=127.0.0.1 bash ~/projects/xiaozhi-e32r28t/server/start.sh

# Server health (second terminal)
ss -ltnp | grep -E ':(8000|8003|8090)\b'
curl -s http://127.0.0.1:8003/xiaozhi/ota/ | head -c 300; echo
curl -s http://127.0.0.1:8090/health; echo
tail -f ~/xiaozhi-esp32-server/main/xiaozhi-server/tmp/server.log

# IDF env (every new board terminal)
. ~/esp/esp-idf/export.sh
cd ~/xiaozhi-s3cam

# Build / verify
python scripts/build.py bread-compact-wifi-s3cam --language en-US --wake-word wn9_jarvis_tts
grep -E "^CONFIG_LCD_.*=y|^CONFIG_LANGUAGE_EN_US=y" sdkconfig

# Flash (UART port)
PORT=/dev/ttyACM0
python -m esptool --chip esp32s3 -p $PORT erase-flash
python -m esptool --chip esp32s3 -p $PORT -b 921600 write-flash 0x0 build/merged-binary.bin

# Board log capture without a monitor (resets board via esptool, 45 s)
python -m esptool --chip esp32s3 -p $PORT chip-id > /dev/null
stty -F $PORT 115200 raw -echo
timeout 45 cat $PORT > /tmp/boot.log
grep -aE "StateMachine|Ota|WifiStation|got ip|WS:|E \(" /tmp/boot.log

# Interactive monitor (Ctrl+] to exit)
idf.py -p $PORT monitor
```

| Symptom | First read |
|---|---|
| No OTA line in server log after board boot | is `start.sh` running? `ss -ltnp` |
| Session opens, no ASR line | mic chain — §3.1 |
| LED slow blue blink | still in Wi-Fi portal — tap RST |
| Native USB port vanished | expected — use the UART port |
__EW_EOF__
w 'xiaozhi-freenove-s3/freenove-s3-xiaozhi-handoff-v1.2.md' <<'__EW_EOF__'
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
__EW_EOF__
w 'xiaozhi-freenove-s3/freenove-s3-xiaozhi-handoff-v1_1.md' <<'__EW_EOF__'
# xiaozhi on Freenove ESP32-S3: handoff v1.1 (session close, next: GC9A01 round display)

**Version:** 1.1 · **Date:** 2026-10-07 · **Host:** Perlinpinpin (Xubuntu 26.04.1, user `hackinblue`, LAN 192.168.1.6)
**Supersedes:** `freenove-s3-xiaozhi-handoff-v1.0.md`
**Status:** ✅ Mic defect closed (dead INMP441, replaced). ⏳ Board still points at the cloud OTA URL; fix staged, not yet flashed. ⏳ Display not wired.
**Marks:** ✅ confirmed this session (source named) · ⚠️ inference / partial · ❌ insufficient data

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-10-07 | First issue. Mic defect open. |
| 1.1 | 2026-10-07 | Mic root cause: dead module, replaced and verified with the I2S probe. Grounding reworked as a star. The NVS wipe sent the board back to the cloud OTA; OTA URL fix staged in `config.json`. Next session: GC9A01 wiring and round-display work. |

---

## 1. Status at close

| Stage | State | Evidence |
|---|---|---|
| Firmware pins = wiring | ✅ | `config.h` l.14–19: mic WS 1 / SCK 2 / DIN 42 · spk DOUT 39 / BCLK 40 / LRCK 41 |
| Old INMP441 | ❌ dead | probe: −200 dBFS on both slots in every phase. Scrapped. |
| New INMP441 (bench) | ✅ | probe: LEFT DATA (A −23.9 / B −29.5 dBFS), RIGHT ALL-0 with pull-down / ALL-1 with pull-up → healthy pattern; meter follows sound |
| New INMP441 (final wiring) | ✅ | probe rerun after assembly: pass (operator) |
| Amp | ✅ | unchanged; voice prompts audible earlier |
| Full reflash of xiaozhi | ✅ | `Hash of data verified` |
| Wi-Fi | ✅ | re-entered via portal after the NVS wipe |
| Board → server | ❌ | boot log: `api.tenclass.net:443`, `Activation: xiaozhi.me 971922`, `Activating... n/10` |
| Server | ✅ | PID 508430 listening on 8000/8003, Pocket TTS on 8090 (`ss -ltnp`); no requests since 16:34:58 |
| OTA URL fix | ⏳ staged | `config.json` edit given; rebuild + `app-flash` ❌ not confirmed run |
| Wake word → ASR → reply | ⏳ | blocked on the OTA URL |

---

## 2. Hardware as built (final)

**Board:** Freenove ESP32-S3 WROOM, 16 MB flash, **8 MB PSRAM** (esptool: `Embedded PSRAM 8MB (AP_3v3)`), MAC `20:6e:f1:aa:b5:6c`. Camera on its FPC (GPIO4–13, 15–18 reserved). microSD slot stays **empty** (shares GPIO39/40).
**Port:** UART USB-C, CH343 → `/dev/ttyACM0` only.

### 2.1 Ground: 4-way star at the board's single GND pin (soldered, heat-shrunk, buzzed)
```
board GND ──┬── INMP441 GND
            ├── INMP441 L/R        (→ LEFT slot, matches I2S_STD_SLOT_LEFT)
            ├── MAX98357A GND
            └── (spare: GC9A01 GND, to be added — see §5.1)
```
Rule: no module's ground return passes through another module. Plug and unplug only with USB disconnected.
⚠️ [INFERENCE] Probable cause of the first mic's death: the amp's ground used to run through the mic's GND/L/R pad. An open joint while powered lifts the mic's ground toward 5 V → reverse supply on the mic.

### 2.2 Signals
| Module pin | GPIO / rail |
|---|---|
| INMP441 VDD / WS / SCK / SD | 3V3 / 1 / 2 / 42 |
| MAX98357A VIN / DIN / BCLK / LRC | 5V / 39 / 40 / 41 |
| MAX98357A GAIN | floating = 9 dB (12 dB = bridge GAIN→GND on the amp, later) |
| MAX98357A SD | floating = (L+R)/2. Never tie it to GND: that shuts the amp down. |
| Speaker | OUT+ / OUT− terminal block |

---

## 3. Close-out task (do first in the next session, ~10 min)

The full flash erased NVS (`erased from 0x00000000 to 0x00934fff`), so the board fell back to the compiled-in OTA default, which is the cloud. The fix is to compile the LAN URL in. This is the documented xiaozhi-esp32-server method: put the server address in the firmware, rebuild, flash.

```bash
. ~/esp/esp-idf/export.sh && cd ~/xiaozhi-s3cam
grep -E '^CONFIG_OTA_URL|^CONFIG_LCD_GC9A01' sdkconfig
# must print:
# CONFIG_OTA_URL="http://192.168.1.6:8003/xiaozhi/ota/"
# CONFIG_LCD_GC9A01_240X240=y
# if OTA_URL is missing: config.json sdkconfig_append must contain
#   "CONFIG_OTA_URL=\"http://192.168.1.6:8003/xiaozhi/ota/\""
# then: python scripts/build.py bread-compact-wifi-s3cam --language en-US --wake-word wn9_jarvis_tts
idf.py -p /dev/ttyACM0 app-flash monitor     # app only: keeps Wi-Fi in NVS
```
**Pass:**
- boot log connects to `192.168.1.6:8003`
- server log shows `OTA请求设备ID: 20:6e:f1:aa:b5:6c`
- "Jarvis" + a question → ASR line → spoken reply

---

## 4. Tooling & gotchas learned this session

- **Mic probe:** `~/mic-probe` (ESP-IDF, same pins and clocking as xiaozhi). Phase A pull-down, phase B pull-up, then a live dBFS meter. Healthy = `LEFT DRIVEN` + `RIGHT FLOATING`. A constant −200 dBFS on the right slot is normal. Reflash it with `idf.py -p /dev/ttyACM0 flash monitor`.
- **Exit idf_monitor on AZERTY:** `Ctrl+T` then `Ctrl+X`. `Ctrl+]` and `Ctrl+C` don't exit.
- **`Could not exclusively lock port`:** another monitor holds the port → `fuser -k /dev/ttyACM0`.
- **Full `write-flash 0x0 merged-binary.bin` wipes NVS** (Wi-Fi + runtime OTA URL). Use `idf.py app-flash` for app-only updates.
- **Terminals:** IDF env only in board terminals. The server runs in its own clean terminal; closing it kills the server.
- **Status LED (GPIO48, RGB):** blinking green = activating (OTA check), confirmed by the boot log. Colours are not swapped.
- Unresolved, unrelated: `meshtasticd` daily build possibly on this box → `apt policy meshtasticd`.

---

## 5. Next session: GC9A01 1.28″ round display (240×240)

### 5.1 Wiring (USB unplugged)

| GC9A01 pin | Goes to | Note |
|---|---|---|
| VCC | 3V3 | |
| GND | **5th branch on the GND star** | re-open the splice, add a leg, heat-shrink, buzz |
| SCL | IO19 | |
| SDA | IO20 | |
| DC | IO47 | |
| CS | IO45 | |
| RST | IO21 | |
| BL (if present) | 3V3 | ⚠️ module expected without BL; check the silkscreen |

Source: v1.0 handoff §2.1. ⚠️ Verify against the firmware before soldering:
```bash
grep -nE "DISPLAY_(MOSI|CLK|DC|CS|RST|RESET|BACKLIGHT)|DISPLAY_.*PIN" ~/xiaozhi-s3cam/main/boards/bread-compact-wifi-s3cam/config.h
```
❌ IO19/20 are also the native-USB D−/D+. Expected and accepted: native USB is dead after boot, use the UART port.

### 5.2 Track A: xiaozhi finalization (display first, it's already built in)
1. Wire, power, boot → UI upright, colours correct? The firmware already contains `CONFIG_LCD_GC9A01_240X240=y` ✅.
2. If the image is mirrored, colours inverted, or R/B swapped → edit `DISPLAY_MIRROR_X` / `DISPLAY_INVERT_COLOR` / RGB order in the board's `config.h`, rebuild, `app-flash`.
3. Boot log warns `Emoji not found: robot_2` / `link` (cosmetic asset gaps). ⚠️ Fixable in the assets theme; low priority.

### 5.3 Track B: round-display play (standalone sketch, same pins, separate project)

| Idea | Why it suits a round panel | Reuses |
|---|---|---|
| **Animated eye** (iris, pupil, blinks, saccades) | the panel *is* an eyeball | — |
| **Mic-reactive eye**: pupil dilates with sound level | ties the eye to the mic you just fixed | probe's dBFS meter code |
| **Attention eye**: looks toward the speaker | ⚠️ needs 2 mics for direction; 1 mic = loudness only | — |
| Radar / sonar sweep | circular by nature | — |
| Analog gauge / compass / clock | circular by nature | — |
| xiaozhi state face (idle / listening / speaking) | replaces the stock emoji UI | xiaozhi display hooks |

Library candidates for Track B: ⚠️ none verified on this board this session.
- **LovyanGFX** or **esp_lcd + LVGL**, both with GC9A01 support. LVGL is what xiaozhi already uses.
- An existing "eyes" project for GC9A01. Check its licence and S3 support before porting.

Use original artwork only, no known characters.

### 5.4 Open items
- ❌ GC9A01 module pinout: confirm on the silkscreen (BL present?).
- ❌ OTA URL fix run? (§3)
- ⚠️ Flash budget: the xiaozhi image is 9.6 MB of 16 MB. Track B as a separate project means swapping firmware: flash the probe or eyes app with `idf.py flash`, then return to xiaozhi with `app-flash`. NVS stays.
- Longer-term goal (separate thread): portable **offline** voice LLM. Verdict from the brief: the S3 alone can't do offline free speech recognition, so this needs a Pi-class box. The S3 build is the satellite.

---

## 6. Opening prompt for the next session

> Attach this file. "Session: GC9A01 round display on the Freenove S3 xiaozhi build. First run §3 close-out (OTA URL, app-flash, Jarvis acceptance). Then §5.1 wiring with firmware pin verification, §5.2 xiaozhi display check, then §5.3 Track B: a standalone animated-eye sketch on the same pins, mic-reactive pupil as the stretch goal. Same gate style: one step, one read, no improvised fixes."

---

## 7. Cheat sheet
```bash
# server (clean terminal)
WS002_IP=127.0.0.1 bash ~/projects/xiaozhi-e32r28t/server/start.sh
ss -ltnp | grep -E ':(8000|8003|8090)\b'
tail -f ~/xiaozhi-esp32-server/main/xiaozhi-server/tmp/server.log

# board (IDF terminal)
. ~/esp/esp-idf/export.sh && cd ~/xiaozhi-s3cam
idf.py -p /dev/ttyACM0 app-flash monitor        # Ctrl+T Ctrl+X to exit
fuser -k /dev/ttyACM0                            # free a locked port
cd ~/mic-probe && idf.py -p /dev/ttyACM0 flash monitor   # mic health check
```
__EW_EOF__
w 'xiaozhi-freenove-s3/gc9a01-xiaozhi-firmware-params-v1.0.md' <<'__EW_EOF__'
# GC9A01 round display · xiaozhi on Freenove S3 — firmware parameter reference

**v1.0 · 2026-10-09** · `78/xiaozhi-esp32 @ ed5cd7b` · ESP-IDF v6.1 · `esp_lcd_gc9a01` 2.0.4 · board `bread-compact-wifi-s3cam`
**Companion to:** `freenove-s3-xiaozhi-handoff-v1_1.md` §5
**Marks:** ✅ read this session (source named) · ⚠️ inference · ❌ insufficient data

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

Each helper prints the line it changed. ✅ Tested on copies of the upstream files: `gc` touches only the GC9A01 block, `kc` is idempotent, `rot 0` restores upstream.

| After | Apply |
|---|---|
| `gc` `rot` `pin` `spi` `pwm` `bri` | `idf.py -p /dev/ttyACM0 app-flash monitor`. Rebuilds the app first ✅ `serial_ext.py` l.1211–1216; NVS kept. |
| `kc` | `python scripts/build.py bread-compact-wifi-s3cam --language en-US --wake-word wn9_jarvis_tts && idf.py -p /dev/ttyACM0 app-flash monitor`. build.py regenerates `sdkconfig` from config.json on every run ✅ `build.py` l.1428–1457, so `menuconfig` edits don't survive. |
| Review / undo | `git diff --stat` · `git checkout -- $B/config.h $B/compact_wifi_board_s3cam.cc main/boards/common/backlight.cc` (config.json untouched) |

## 2. Pins — `config.h` l.57–62

| Define | Now = Rec | `GPIO_NUM_NC` allowed | Move to |
|---|---|---|---|
| `DISPLAY_CLK_PIN` | `GPIO_NUM_19` | no | 14 |
| `DISPLAY_MOSI_PIN` | `GPIO_NUM_20` | no | 14 |
| `DISPLAY_DC_PIN` | `GPIO_NUM_47` | no: 4-wire module | 14 |
| `DISPLAY_RST_PIN` | `GPIO_NUM_21` | yes: driver sends SWRESET ✅ `esp_lcd_gc9a01.c`; module RST then to 3V3 | 14 |
| `DISPLAY_CS_PIN` | `GPIO_NUM_45`, see §6 | only with module CS tied to GND | 14 |
| `DISPLAY_BACKLIGHT_PIN` | `GPIO_NUM_38` if the module has BL/BLK · `GPIO_NUM_NC` if not | yes: no PWM, brightness tool not registered ✅ board `.cc` l.200–206, `mcp_server.cc` l.62–72 | 14 |

- Spares on this build: **GPIO14** (clean: `LAMP_GPIO` l.306 is never used ✅ board `.cc`) · **GPIO3**, **GPIO46** (strapping ✅ ESP-IDF S3 GPIO table). Every other GPIO is assigned in `config.h` or reserved: 26–37 flash/PSRAM ✅ S3 GPIO table, 43/44 console UART ✅ `uart_pins.h`.
- GPIO38 is also the microSD CMD line ✅ Freenove `Sketch_04.1` l.10. Slot stays empty.
- Example: `pin DISPLAY_CS_PIN GPIO_NUM_14`, after rewiring with USB unplugged.

## 3. Panel block — `config.h` l.275–288 (`#ifdef CONFIG_LCD_GC9A01_240X240`)

| Define | Now | Range | Rec | Change when | Command |
|---|---|---|---|---|---|
| `DISPLAY_WIDTH` / `_HEIGHT` | 240 / 240 | fixed | 240 | never | — |
| `DISPLAY_MIRROR_X` | true | true / false | true | text mirrored left↔right | `gc DISPLAY_MIRROR_X false` |
| `DISPLAY_MIRROR_Y` | false | true / false | false | mirrored top↔bottom | `gc DISPLAY_MIRROR_Y true` |
| `DISPLAY_SWAP_XY` | false | true / false | false | image turned 90° | `rot 90` or `rot 270` |
| `DISPLAY_INVERT_COLOR` | true | true / false | true | negative colours | `gc DISPLAY_INVERT_COLOR false` |
| `DISPLAY_RGB_ORDER` | `LCD_RGB_ELEMENT_ORDER_BGR` | `…_RGB` / `…_BGR` | BGR | red↔blue swapped | `gc DISPLAY_RGB_ORDER LCD_RGB_ELEMENT_ORDER_RGB` |
| `DISPLAY_OFFSET_X` / `_Y` | 0 / 0 | 0 only | 0 | never | — |
| `DISPLAY_BACKLIGHT_OUTPUT_INVERT` | false | true / false | false | BL wired: dark at 100 %, lit at 0 % | `gc DISPLAY_BACKLIGHT_OUTPUT_INVERT true` |
| `DISPLAY_SPI_MODE` | 0 | 0–3 | 0 | never: 3 is for CS-less modules (l.167) | `gc DISPLAY_SPI_MODE 3` |

- ✅ `esp_lcd_gc9a01.c` 2.0.4: MIRROR_X → MADCTL MX, MIRROR_Y → MY, SWAP_XY → MV, INVERT → INVON/INVOFF, RGB_ORDER → BGR bit.
- ✅ Offsets go to `lv_display_set_offset` (`lcd_display.cc` l.210). GRAM is exactly 240RGB×240 (GC9A01A datasheet §1), so any offset pushes the image off the glass.
- ✅ SPI mode 0–3: `esp_lcd_io_spi.h` l.25.

Rotation — `rot N` sets all three:

| `rot` | MIRROR_X | MIRROR_Y | SWAP_XY |
|---|---|---|---|
| 0 (upstream) | true | false | false |
| 90 | false | false | true |
| 180 | false | true | false |
| 270 | true | true | true |

⚠️ 180 = both mirrors flipped, exact. Which of 90/270 is clockwise depends on how the panel sits: if `rot 90` turns the wrong way, use `rot 270`.

## 4. SPI clock & backlight

| Parameter | Now | Low | High | Rec | Command |
|---|---|---|---|---|---|
| `io_config.pclk_hz` (board `.cc` l.90) | 40 MHz | ⚠️ 10 MHz practical | 80 MHz | 40; 20 on noise or torn pixels | `spi 20` |
| Brightness, runtime (NVS `display/brightness`) | 75 | 0 = off (a stored 0 boots at 10) | 100 (clamped) | 75 | voice: "set screen brightness to 40" |
| Brightness, boot default (`backlight.cc` l.35) | 75 | 1 | 100 | 75 | `bri 60` |
| Backlight PWM (`PwmBacklight` 3rd arg) | 25 kHz | ⚠️ 20 kHz | ⚠️ 78 kHz | 25 kHz | `pwm 25000` |

**SPI clock**
- Steps: 80 MHz APB ÷ n → 80 · 40 · 26.7 · 20 · 16 · 13.3 · 11.4 · 10. Other values snap to the nearest step ✅ `clk_tree_defs.h` l.362, `soc.h` l.151, `spi_master.rst` l.592.
- Panel ceiling: 100 MHz (write cycle ≥ 10 ns) ✅ GC9A01A datasheet Table 48. Not the limit.
- Chip ceiling on these pins: the display uses SPI3 (board `.cc` l.78); S3 IO_MUX pins exist only for SPI2, so the signals go through the GPIO matrix. ESP-IDF v6.1 guarantees GPIO matrix = IO_MUX behaviour only at ≤ 40 MHz ✅ `spi_master.rst` l.520. 80 MHz is the default in Espressif's own GC9A01 driver ✅ `esp_lcd_gc9a01.h` l.98, but outside that guarantee.
- Full-frame push (240 × 240 × 16 bit = 921,600 bit): 80 MHz → 11.5 ms · 40 → 23.0 ms · 20 → 46.1 ms · 10 → 92.2 ms (computed).

**Brightness**
- Duty = 1023 × brightness ÷ 100 (10-bit LEDC); fades 1 % per 5 ms ✅ `backlight.cc` l.61–65, l.115–118.
- Voice path: device tool `self.screen.set_brightness`, 0–100, saved to NVS ✅ `mcp_server.cc` l.62–72. ❌ Not exercised with ZaiGLMLLM tool calls on your server.
- `bri` sets the value used while NVS holds no brightness. On this board only the voice tool writes that key ✅ `backlight.cc` l.35, l.55–58; `mcp_server.cc` l.69. `erase-flash` returns to the compiled value.

**PWM**
- 10-bit LEDC, automatic clock (XTAL / APB / RC_FAST) ✅ `backlight.cc` l.85–90, `clk_tree_defs.h` l.462.
- ⚠️ High = 80 MHz ÷ 1024 = 78.1 kHz, from the documented frequency/resolution trade-off (`ledc.rst` l.64).
- ⚠️ Low = 20 kHz, the top of the audible range; the code comment warns low frequencies make the inductor whine ✅ `backlight.cc` l.89.
- Only matters with a BL pin.

## 5. Kconfig — `config.json` → build.py

| Option | Now | Values | Rec | Command |
|---|---|---|---|---|
| `CONFIG_LCD_GC9A01_240X240` | y | one of 17 `LCD_*` choices ✅ `Kconfig.projbuild` l.743–783 | y | none: panel fixed |
| `CONFIG_OTA_URL` | your Gate 1 read | any http(s) URL; default `https://api.tenclass.net/xiaozhi/ota/` ✅ `Kconfig.projbuild` l.3–5 | `http://192.168.1.6:8003/xiaozhi/ota/` | `kc CONFIG_OTA_URL '"http://192.168.1.6:8003/xiaozhi/ota/"'` |

NVS `wifi/ota_url` (portal → Advanced, E32R28T handoff §4) beats the compiled value ✅ `ota.cc` l.48–55. It survives `app-flash` and is gone after `erase-flash`.

## 6. CS on GPIO45 — settling read

```bash
python -m espefuse -p /dev/ttyACM0 summary | grep -A2 'Flash voltage'
```

- `Flash voltage (VDD_SPI) set to 3.3V by efuse.` → strap ignored: CS stays on 45.
- `Flash voltage (VDD_SPI) determined by GPIO45 on reset …` → `pin DISPLAY_CS_PIN GPIO_NUM_14` + rewire, unless module CS has no pull-up.

✅ espefuse `esp32s3/fields.py` l.256–269, printed by `summary` (`base_operations.py` l.833) in esptool 5.5.0. ⚠️ Same strings assumed in your 5.4.0.

## Sources
- [xiaozhi-esp32 @ ed5cd7b, board folder](https://github.com/78/xiaozhi-esp32/tree/ed5cd7ba0011dc06fefd0762790857268c41b430/main/boards/bread-compact-wifi-s3cam)
- [esp_lcd_gc9a01 (esp-bsp)](https://github.com/espressif/esp-bsp/tree/master/components/lcd/esp_lcd_gc9a01)
- [ESP-IDF v6.1 SPI master doc](https://github.com/espressif/esp-idf/blob/v6.1/docs/en/api-reference/peripherals/spi_master.rst) · [S3 GPIO table](https://github.com/espressif/esp-idf/blob/v6.1/docs/en/api-reference/peripherals/gpio/esp32s3.inc) · [LEDC doc](https://github.com/espressif/esp-idf/blob/v6.1/docs/en/api-reference/peripherals/ledc.rst)
- [GC9A01A datasheet (Waveshare)](https://files.waveshare.com/wiki/common/GC9A01A.pdf)
- [espefuse ESP32-S3 fields](https://github.com/espressif/esptool/blob/master/espefuse/efuse/esp32s3/fields.py)
- [Freenove ESP32-S3 WROOM board repo](https://github.com/Freenove/Freenove_ESP32_S3_WROOM_Board)
__EW_EOF__
w 'xiaozhi-freenove-s3/gc9a01-xiaozhi-firmware-params-v1.1.md' <<'__EW_EOF__'
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
__EW_EOF__
w 'xiaozhi-freenove-s3/xiaozhi-s3cam-CLAUDE.md' <<'__EW_EOF__'
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
__EW_EOF__

case "$DOCS" in "$HOME"/*) docs_txt="~${DOCS#"$HOME"}" ;; *) docs_txt="$DOCS" ;; esac
if [ "$docs_txt" != "$DEFAULT_DOCS_TXT" ]; then   # custom XZ: keep CLAUDE.md pointing at the real folder
  esc=$(printf '%s' "$docs_txt" | sed 's/[\\&|]/\\&/g')
  sed -i "s|$DEFAULT_DOCS_TXT|$esc|g" "$DOCS/xiaozhi-freenove-s3/xiaozhi-s3cam-CLAUDE.md"
fi
echo "$(find "$DOCS" -type f | wc -l) files in $DOCS"

say "2/4 CLAUDE.md -> $FW"
if [ -d "$FW" ]; then
  src="$DOCS/xiaozhi-freenove-s3/xiaozhi-s3cam-CLAUDE.md"
  if [ -f "$FW/CLAUDE.md" ] && cmp -s "$src" "$FW/CLAUDE.md"; then
    echo "already current"
  else
    had=0; [ -f "$FW/CLAUDE.md" ] && had=1
    install -b -m 644 "$src" "$FW/CLAUDE.md"
    if [ "$had" = 1 ]; then echo "installed; previous one kept as CLAUDE.md~"; else echo "installed"; fi
  fi
else
  echo "SKIP: $FW not found"
fi

rc=0
say "3/4 Safety snapshots (local git; nothing in $XZ)"
snapshot_tree "$FW" "$FW_BRANCH" "freenove-s3: snapshot working tree + CLAUDE.md before GC9A01 bring-up (2026-10-09)" || rc=1
snapshot_tree "$PROBE" main "mic-probe: snapshot (2026-10-09)" || rc=1

say "4/4 Inventory of $XZ (for the cleanup)"
{
  echo "total: $(du -sh "$XZ" 2>/dev/null | cut -f1) · files: $(find "$XZ" -type f | wc -l) · dirs: $(find "$XZ" -mindepth 1 -type d | wc -l)"
  [ -d "$XZ/.git" ] && echo "NOTE: $XZ already has a .git folder"
  echo "-- top level (size, name):"
  ( cd "$XZ" && shopt -s nullglob dotglob && for e in *; do du -sh -- "$e"; done | sort -rh | head -n 40 )
  echo "-- folders, 2 levels:"
  ( cd "$XZ" && find . -mindepth 1 -maxdepth 2 -type d | sort | head -n 60 )
  echo "-- 15 largest files:"
  ( cd "$XZ" && find . -type f -printf '%s\t%p\n' | sort -rn | head -n 15 | awk -F'\t' '{ printf "%8.1f MB  %s\n", $1/1048576, $2 }' )
} || true
for old in "$HOME/projects/esp32-wonders" "$HOME/projects/AI_chatbot_esp32"; do
  [ -e "$old" ] && echo "NOTE: $old exists (from an earlier script); superseded by $DOCS"
done
exit $rc
