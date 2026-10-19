# Xiao Zhi project: doc index

Imported 2026-10-09 from the claude.ai project "ESP32 wonders". ★ = current version.

| Folder | Docs |
|---|---|
| `xiaozhi-freenove-s3/` | ★ `XIAOZHI_S3_PROJECT_DOC_v1.0.md` (full doc) · ★ `XIAOZHI_S3_CHEATSHEET_v1.0.md` · ★ `freenove-s3-xiaozhi-handoff-v1.5.md` · ★ `freenove-s3-wiring-diagram-v0.7.{pdf,json,svg}` (VERIFIED) · ★ `s3cam-oled-i2c-v0.3.patch` (cumulative vs ed5cd7b) · `gc9a01-xiaozhi-firmware-params-v1.1.md` (shelved display) · `xiaozhi-s3cam-CLAUDE.md` · superseded: handoff v1.2–v1.4, patch v0.1–v0.2, diagram v0.1–v0.6 |
| `xiaozhi-e32r28t/` | `e32r28t-xiaozhi-handoff-v1.0.md` · `SOP-001_xiaozhi-e32r28t-bringup_v1_0.yaml` (the bundle itself stays in `~/projects/xiaozhi-e32r28t/`) |
| `research/` | `esp32-family-llm-companion-v1.0.md` |
| `links.md` | links saved in the project |

Working trees outside this folder:
- `~/xiaozhi-s3cam`: firmware (78/xiaozhi-esp32 @ ed5cd7b + patch v0.3), local branch `freenove-s3` — path must have no spaces
- `~/xiaozhi-esp32-server` → symlink to `~/Documents/Microcontrolers/Xiao Zhi/xiaozhi-esp32-server` (server tree); `~/pocket-tts` (TTS shim)
- `~/mic-probe`: I2S mic probe, local repo

Update rule: a new doc version is a new `-vX.Y` file, saved here and written to the claude.ai project. Git + GitHub backup (`YokohamaAIart/AI_chatbot_esp32`) after the folder cleanup.
