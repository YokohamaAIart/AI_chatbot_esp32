# Xiao Zhi: file-save status at session close

**v1.0 · 2026-10-09** · read together with `freenove-s3-xiaozhi-handoff-v1.2.md`

## Goal
On Perlin, in this order:
1. Save the docs to `~/Documents/Microcontrolers/Xiao Zhi/docs/`.
2. Install CLAUDE.md v1.3 into `~/xiaozhi-s3cam`.
3. Make local git snapshots of `~/xiaozhi-s3cam` (branch `freenove-s3`) and `~/mic-probe`.
4. Print an inventory of the Xiao Zhi folder for the cleanup.

Only after the folder is cleaned and checked: git for the folder plus the GitHub backup (`YokohamaAIart/AI_chatbot_esp32`).

## Tool
- `claude/xiaozhi-save.sh` (in this project): 106,249 bytes, sha256 `10c5124cf3a810862f959654301c9e6ad0e54ca0d15b5d44cfd89c149056d328`.
- It replaces `save-esp32-wonders.sh` and `save-ai-chatbot-esp32.sh`. Don't run those.
- ❌ Not run on Perlin yet. The chat download never reached `~/Downloads`.

## Dropbox transfer (incomplete)

| File in Dropbox `/Xiao Zhi/` | Bytes | Dropbox content_hash | State |
|---|---|---|---|
| `xiaozhi-save-part1of3.txt` | 36,781 | `681fdc1dfc509c328d6e5155ba8aa2a108d2d4b635134f9a64148acf371abf68` | ✅ uploaded |
| `xiaozhi-save-part2of3.txt` | 32,513 | `5ee9999426a228a0caae1e3ed5dd06b2d70a040f985549e821a0e38e67828211` | ✅ uploaded |
| `xiaozhi-save-part3of3.txt` | 36,955 | `1042696ba050e73bc930e2fe294181a88d8c39ee29d2146c4dd5b323e4f616e9` | ❌ not uploaded |

The three parts, joined in order, make the script byte-for-byte. The split is at heredoc boundaries: part 3 starts with `w 'xiaozhi-freenove-s3/freenove-s3-xiaozhi-handoff-v1_1.md'`.

## Next session, first step
1. Upload part 3, cut from `claude/xiaozhi-save.sh`. Check all three Dropbox content_hash values against the table above.
2. Make fresh Dropbox download links for the three parts. They are single-use and last 15 min.
3. On Perlin, run:
   ```bash
   curl -fsSL 'URL1' 'URL2' 'URL3' > ~/Downloads/xiaozhi-save.sh && echo "10c5124cf3a810862f959654301c9e6ad0e54ca0d15b5d44cfd89c149056d328  $HOME/Downloads/xiaozhi-save.sh" | sha256sum -c - && bash ~/Downloads/xiaozhi-save.sh
   ```
4. Alternative: open the session in the Claude desktop app on Perlin and link it to the computer. The session can then write the files directly.
5. The operator pastes the inventory block. That gives the cleanup plan, then git and the GitHub backup.

The hardware work resumes at handoff v1.2 Gate 0.
