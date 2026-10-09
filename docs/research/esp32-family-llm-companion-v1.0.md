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
