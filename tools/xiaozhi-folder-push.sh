#!/usr/bin/env bash
# xiaozhi-folder-push.sh · v1.1 · 2026-10-10 (v1.1: *keys* names and archives never committed)
# Housekeeping of ~/Documents/Microcontrolers/Xiao Zhi, then git + GitHub (YokohamaAIart/AI_chatbot_esp32).
#
#   bash xiaozhi-folder-push.sh plan      # read-only: inventory + what clean/push WOULD do
#   bash xiaozhi-folder-push.sh clean     # Gate A: move dups / old versions / junk into _quarantine/<stamp>/ (nothing deleted)
#   bash xiaozhi-folder-push.sh push      # Gate B: git init/commit on top of origin/main, push
#   bash xiaozhi-folder-push.sh apply     # clean + push
#   bash xiaozhi-folder-push.sh restore   # put the LAST quarantine back where it came from
#
# Rules: nothing is ever deleted (quarantine + MANIFEST.tsv). Secrets, files > MAX_MB, nested git repos and the
# quarantine itself are never committed. Re-runnable. Other folder: XZ=/path bash xiaozhi-folder-push.sh ...
set -euo pipefail

XZ="${XZ:-$HOME/Documents/Microcontrolers/Xiao Zhi}"; XZ="${XZ%/}"
REMOTE="${REMOTE:-https://github.com/YokohamaAIart/AI_chatbot_esp32.git}"
BRANCH=main
MAX_MB=20
Q="$XZ/_quarantine"
TRAILER=$'\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_016PkzimiZucuLEfzUTGNgT4'
JUNK_RE='(~|\.bak|\.orig|\.rej|\.swp|\.swo|\.tmp|\.DS_Store|Thumbs\.db|desktop\.ini)$'
SECRET_RE='(^|/)(\.config\.yaml|\.env(\..*)?|.*\.(pem|key|p12|pfx)|.*(token|secret|password|credential|[_-]keys?[_.-])[^/]*)$'
ARCHIVE_RE='\.(tgz|tar\.gz|tar|zip|7z)$'   # archives can hide secrets (e.g. .config.yaml inside) -> never committed
# never-commit globs, written to .gitignore
IGNORE=('_quarantine/' 'build/' 'managed_components/' 'sdkconfig' 'sdkconfig.old' '.vscode/' '__pycache__/' '*~' '*.bak' '*.orig' '*.swp' '.DS_Store' 'Thumbs.db' '.config.yaml' '.env' '*.pem' '*.key')

MODE="${1:-plan}"
case "$MODE" in plan|clean|push|apply|restore) ;; *) echo "usage: $0 plan|clean|push|apply|restore"; exit 2;; esac
[ -d "$XZ" ] || { echo "ERROR: folder not found: $XZ"; exit 1; }
cd "$XZ"
say() { printf '\n== %s\n' "$*"; }
rel() { printf '%s\n' "${1#./}"; }

# ---------- file list (excludes quarantine, .git, nested git repos) ----------
nested_repos() { find . -mindepth 2 -name .git \( -type d -o -type f \) -printf '%h\n' | sed 's|^\./||' | sort; }
mapfile -t NESTED < <(nested_repos)
list_files() {
  local prune=( -path ./_quarantine -o -path ./.git )
  local r; for r in "${NESTED[@]:-}"; do [ -n "$r" ] && prune+=( -o -path "./$r" ); done
  find . \( "${prune[@]}" \) -prune -o -type f -print | sed 's|^\./||' | LC_ALL=C sort
}

# ---------- Gate A analysis: writes PLAN lines "reason<TAB>path<TAB>kept" ----------
analyse() {
  mapfile -t FILES < <(list_files)
  say "Inventory: ${#FILES[@]} files in $XZ"
  local f
  for f in "${FILES[@]}"; do printf '  %9s  %s\n' "$(stat -c %s -- "$f")" "$f"; done
  [ ${#NESTED[@]} -gt 0 ] && [ -n "${NESTED[0]}" ] && { say "Nested git repos (left alone, not committed):"; printf '  %s\n' "${NESTED[@]}"; }

  PLAN=()
  # 1. junk
  for f in "${FILES[@]}"; do [[ "$f" =~ $JUNK_RE || "$f" == *"/__pycache__/"* ]] && PLAN+=("junk	$f	-"); done
  # 2. exact duplicates by sha256: keep the organized one — name without "copy"/"(n)", then deepest path, then shortest name
  local h p prev='' keep=''
  while IFS=$'\t' read -r h p; do
    if [ "$h" = "$prev" ]; then PLAN+=("duplicate	$p	$keep"); else prev=$h; keep=$p; fi
  done < <(for f in "${FILES[@]}"; do [[ "$f" =~ $JUNK_RE ]] && continue; printf '%s\t%s\n' "$(sha256sum -- "$f" | cut -c1-64)" "$f"; done \
           | awk -F'\t' '{n=split($2,a,"/"); c=(tolower(a[n]) ~ /(copy|\([0-9]+\))/)?1:0; printf "%s\t%d\t%d\t%d\t%s\n",$1,c,1000-n,length(a[n]),$2}' \
           | LC_ALL=C sort -t$'\t' -k1,1 -k2,2n -k3,3n -k4,4n | cut -f1,5)
  # 3. old versions: same dir + same stem + same ext, suffix -vX.Y / -vX_Y / _vX_Y → keep highest
  local base dir name stem ext maj min key
  declare -A best bestv
  for f in "${FILES[@]}"; do
    name=${f##*/}; dir=${f%"$name"}
    if [[ "$name" =~ ^(.+)[-_][vV]([0-9]+)[._]([0-9]+)(\.[A-Za-z0-9]+)$ ]]; then
      stem=${BASH_REMATCH[1]}; maj=${BASH_REMATCH[2]}; min=${BASH_REMATCH[3]}; ext=${BASH_REMATCH[4]}
      key="$dir$stem$ext"
      if [ -z "${best[$key]:-}" ] || [ $((maj*1000+min)) -gt "${bestv[$key]}" ]; then
        [ -n "${best[$key]:-}" ] && PLAN+=("old-version	${best[$key]}	$f")
        best[$key]=$f; bestv[$key]=$((maj*1000+min))
      else
        PLAN+=("old-version	$f	${best[$key]}")
      fi
    fi
  done
  # 4. not committed (stay local): secrets, big files
  EXCL=()
  for f in "${FILES[@]}"; do
    [[ "$f" =~ $SECRET_RE ]] && EXCL+=("secret	$f")
    [[ "$f" =~ $ARCHIVE_RE ]] && EXCL+=("archive	$f")
    [ "$(stat -c %s -- "$f")" -gt $((MAX_MB*1024*1024)) ] && EXCL+=("over-${MAX_MB}MB	$f")
  done

  say "Gate A plan: $((${#PLAN[@]})) file(s) to quarantine"
  if [ ${#PLAN[@]} -gt 0 ]; then
    printf '  %-12s %-70s %s\n' REASON FILE KEPT
    printf '%s\n' "${PLAN[@]}" | sort -u | awk -F'\t' '{printf "  %-12s %-70s %s\n",$1,$2,$3}'
  fi
  say "Stay local, never committed: ${#EXCL[@]}"
  [ ${#EXCL[@]} -gt 0 ] && printf '%s\n' "${EXCL[@]}" | awk -F'\t' '{printf "  %-12s %s\n",$1,$2}'
  return 0
}

gate_a() {
  local stamp; stamp=$(date +%Y%m%d-%H%M%S)
  local qd="$Q/$stamp"
  [ ${#PLAN[@]} -eq 0 ] && { echo "nothing to quarantine"; return 0; }
  mkdir -p "$qd"
  local reason f kept n=0
  while IFS=$'\t' read -r reason f kept; do
    [ -f "$f" ] || continue
    mkdir -p "$qd/$(dirname "$f")"
    mv -n -- "$f" "$qd/$f"
    printf '%s\t%s\t%s\n' "$reason" "$f" "$kept" >> "$qd/MANIFEST.tsv"; n=$((n+1))
  done < <(printf '%s\n' "${PLAN[@]}" | sort -u)
  local sweep=( -not -path './_quarantine*' -not -path './.git*' ); local r
  for r in "${NESTED[@]:-}"; do [ -n "$r" ] && sweep+=( -not -path "./$r*" ); done
  find . -depth -mindepth 1 -type d -empty "${sweep[@]}" -print -delete | sed 's/^/  removed empty dir: /'
  echo "quarantined $n file(s) -> $qd  (MANIFEST.tsv inside; '$0 restore' puts them back)"
}

restore_last() {
  local last; last=$(ls -1d "$Q"/*/ 2>/dev/null | sort | tail -n1); last=${last%/}
  [ -n "$last" ] && [ -f "$last/MANIFEST.tsv" ] || { echo "no quarantine to restore"; return 0; }
  local reason f kept
  while IFS=$'\t' read -r reason f kept; do
    mkdir -p "$(dirname "$f")"; mv -n -- "$last/$f" "$f" && echo "  restored $f"
  done < "$last/MANIFEST.tsv"
  rm -f "$last/MANIFEST.tsv"; find "$last" -type d -empty -delete
  echo "restored from $last"
}

# ---------- Gate B ----------
own_repo() { [ "$(git rev-parse --show-toplevel 2>/dev/null || true)" = "$(pwd -P)" ]; }
gate_b() {
  command -v git >/dev/null || { echo "ERROR: git not found"; return 1; }
  if ! own_repo; then
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 && { echo "ERROR: $XZ sits inside another repo ($(git rev-parse --show-toplevel))"; return 1; }
    git init -q -b "$BRANCH"; echo "git init ($BRANCH)"
  fi
  git config user.name "Martin Yokohama"; git config user.email "65628989+YokohamaAIart@users.noreply.github.com"   # repo-local: GitHub email-privacy block rejects the private address
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "$REMOTE"
  git fetch -q origin "$BRANCH" || { echo "ERROR: cannot fetch $REMOTE (gh auth / network)"; return 1; }
  if ! git rev-parse -q --verify HEAD >/dev/null; then
    # virgin local repo: start from origin's Initial commit, keep local files when names collide
    git reset -q "origin/$BRANCH"
    git ls-tree -r --name-only "origin/$BRANCH" | while read -r f; do [ -e "$f" ] || git checkout -q -- "$f"; done
    echo "based on origin/$BRANCH $(git rev-parse --short "origin/$BRANCH")"
  fi
  # .gitignore: keep origin's, append ours once
  touch .gitignore; local p
  for p in "${IGNORE[@]}"; do grep -qxF -- "$p" .gitignore || echo "$p" >> .gitignore; done
  # nested repos and over-size files: local excludes
  local ex; ex=$(git rev-parse --git-path info/exclude); mkdir -p "$(dirname "$ex")"; touch "$ex"
  for p in "${NESTED[@]:-}"; do [ -n "$p" ] && { grep -qxF -- "/$p/" "$ex" || echo "/$p/" >> "$ex"; }; done
  local reason f
  for line in "${EXCL[@]:-}"; do [ -n "$line" ] || continue; IFS=$'\t' read -r reason f <<< "$line"; grep -qxF -- "/$f" "$ex" || echo "/$f" >> "$ex"; done
  git add -A
  if git diff --cached --quiet; then echo "nothing new to commit"
  else
    local big; big=$(git diff --cached --name-only --diff-filter=d -z | xargs -0 -r du -m -- | awk -v m="$MAX_MB" '$1>m{$1="";print substr($0,2)}')
    [ -n "$big" ] && { git reset -q; printf 'ABORTED: staged files over %s MB:\n%s\n' "$MAX_MB" "$big"; return 1; }
    git commit -q -m "Xiao Zhi folder: housekeeping + import $(date +%F)$TRAILER"
    git --no-pager log --oneline -1; git --no-pager show --stat --format= HEAD | tail -n 15
  fi
  if git push -u origin "$BRANCH" 2>&1; then echo "pushed -> $REMOTE ($BRANCH)"
  else echo "PUSH REJECTED. If origin moved: git pull --rebase origin $BRANCH && git push"; return 1; fi
}

case "$MODE" in
  plan)    analyse; own_repo && { say "git status"; git status --short | head -40; } || echo "(no git repo in folder yet; push will init on top of origin/$BRANCH)";;
  clean)   analyse; say "Gate A"; gate_a;;
  push)    analyse; say "Gate B"; gate_b;;
  apply)   analyse; say "Gate A"; gate_a; say "Gate B"; gate_b;;
  restore) restore_last;;
esac
