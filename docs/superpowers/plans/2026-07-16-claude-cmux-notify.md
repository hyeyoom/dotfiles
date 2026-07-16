# claude-cmux-notify 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude Code Stop 훅이 cmux 네이티브 macOS 알림을 띄우고 클릭 시 해당 워크스페이스로 점프하게 하는 `claude-cmux-notify` 툴(설치 서브커맨드 포함)을 dotfiles에 추가한다.

**Architecture:** 단일 POSIX sh 스크립트. 알림 모드는 `cmux notify`(배너·클릭 점프는 cmux가 처리, 실측 검증됨), install/uninstall은 내장 python3 heredoc이 `~/.claude/settings.json`을 백업 후 편집.

**Tech Stack:** POSIX sh, python3 stdlib(json), cmux CLI, terminal-notifier(폴백).

**Spec:** `docs/superpowers/specs/2026-07-16-claude-cmux-notify-design.md`

## Global Constraints

- 알림 모드는 어떤 실패에도 exit 0 (훅 체인을 막지 않는다). stderr에만 로그.
- install/uninstall은 편집 전 `settings.json.bak-<timestamp>` 백업. 파싱 실패 시 원본 불변으로 중단.
- 제거 대상은 command에 `terminal-notifier` 또는 `claude-cmux-notify`가 포함된 훅 엔트리만. 다른 훅·무관 키(statusLine 등)는 보존.
- env `CLAUDE_CMUX_NOTIFY_SETTINGS`로 settings.json 경로 오버라이드 가능 (기본 `~/.claude/settings.json`).
- 훅 등록은 Stop만. Notification은 등록하지 않는다 (cmux 래퍼가 이미 알림).
- 작업 브랜치에서 진행, 완료 후 main 머지 + origin push.

---

### Task 1: scripts/bin/claude-cmux-notify

**Files:**
- Create: `scripts/bin/claude-cmux-notify` (실행 권한)

**Interfaces:**
- Produces: 실행 파일 절대 경로 (install이 settings.json에 기록), env `CLAUDE_CMUX_NOTIFY_SETTINGS`, 서브커맨드 `install`/`uninstall` — Task 2 문서와 Task 4 테스트가 이 계약을 사용

- [ ] **Step 1: 실패 확인 (RED)**

Run: `echo '{}' | claude-cmux-notify` → `command not found`

- [ ] **Step 2: 파일 작성**

```sh
#!/bin/sh
# claude-cmux-notify            — Claude Code hook: macOS notification via cmux;
#                                 clicking it jumps to the originating workspace
# claude-cmux-notify install    — register Stop hook in ~/.claude/settings.json
#                                 (removes old terminal-notifier hook entries)
# claude-cmux-notify uninstall  — remove hook entries installed by this script
set -u

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

case "${1:-}" in
  install|uninstall)
    CLAUDE_CMUX_NOTIFY_SELF="$SELF" exec python3 - "$1" <<'PY'
import json, os, shutil, sys, time

mode = sys.argv[1]
path = os.path.abspath(
    os.environ.get("CLAUDE_CMUX_NOTIFY_SETTINGS")
    or os.path.expanduser("~/.claude/settings.json"))
self_path = os.environ["CLAUDE_CMUX_NOTIFY_SELF"]

data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except ValueError as e:
        sys.exit(f"error: cannot parse {path} ({e}); no changes made")
    backup = f"{path}.bak-{time.strftime('%Y%m%d%H%M%S')}"
    shutil.copy2(path, backup)
    print(f"backup: {backup}")

hooks = data.setdefault("hooks", {})
removed = 0
for event in ("Stop", "Notification", "PreToolUse", "PostToolUse"):
    kept = []
    for entry in hooks.get(event, []):
        cmds = [h.get("command", "") for h in entry.get("hooks", [])]
        if any("terminal-notifier" in c or "claude-cmux-notify" in c for c in cmds):
            removed += 1
        else:
            kept.append(entry)
    if kept:
        hooks[event] = kept
    else:
        hooks.pop(event, None)

if mode == "install":
    hooks.setdefault("Stop", []).append(
        {"matcher": ".*", "hooks": [{"type": "command", "command": self_path}]})
if not hooks:
    data.pop("hooks", None)

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"removed {removed} notification hook entries from {path}")
if mode == "install":
    print(f"installed: Stop hook -> {self_path}")
    print("takes effect for new Claude Code sessions")
PY
    ;;
  "") ;;
  *)
    echo "usage: claude-cmux-notify [install|uninstall]  (no args: hook mode, reads JSON on stdin)" >&2
    exit 2
    ;;
esac

# ---- hook mode: never fail the hook chain ----
payload=$(cat 2>/dev/null || true)

event=""; cwd=""; message=""
if command -v python3 >/dev/null 2>&1; then
  parsed=$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
for k in ("hook_event_name", "cwd", "message"):
    v = d.get(k, "")
    print(v.replace("\n", " ") if isinstance(v, str) else "")
' 2>/dev/null) || parsed=""
  event=$(printf '%s\n' "$parsed" | sed -n 1p)
  cwd=$(printf '%s\n' "$parsed" | sed -n 2p)
  message=$(printf '%s\n' "$parsed" | sed -n 3p)
fi

title="Claude Code"
subtitle=""
[ -n "$cwd" ] && subtitle=$(basename "$cwd")
case "$event" in
  Stop|"") body="작업이 끝났습니다" ;;
  *)       body="${message:-$event}" ;;
esac

if [ -n "${CMUX_WORKSPACE_ID:-}" ] && command -v cmux >/dev/null 2>&1; then
  if cmux notify --title "$title" ${subtitle:+--subtitle "$subtitle"} --body "$body" \
       --workspace "$CMUX_WORKSPACE_ID" \
       ${CMUX_SURFACE_ID:+--surface "$CMUX_SURFACE_ID"} >/dev/null 2>&1; then
    exit 0
  fi
  echo "claude-cmux-notify: cmux notify failed, falling back" >&2
fi
if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier -title "$title" ${subtitle:+-subtitle "$subtitle"} \
    -message "$body" >/dev/null 2>&1 || true
fi
exit 0
```

Run: `chmod +x scripts/bin/claude-cmux-notify`

- [ ] **Step 3: 알림 모드 테스트 (GREEN)**

```bash
printf '{"hook_event_name":"Stop","cwd":"%s"}' "$PWD" | scripts/bin/claude-cmux-notify
echo "exit=$?"                                   # → 0
cmux list-notifications | head -2                # 최상단에 Claude Code / dotfiles / 작업이 끝났습니다
printf 'not json' | scripts/bin/claude-cmux-notify; echo "exit=$?"   # → 0 (기본 메시지)
CMUX_WORKSPACE_ID= scripts/bin/claude-cmux-notify </dev/null; echo "exit=$?"  # → 0 (폴백 경로)
```

- [ ] **Step 4: Commit**

```bash
git add scripts/bin/claude-cmux-notify
git commit -m "feat: add claude-cmux-notify hook tool"
```

---

### Task 2: install/uninstall 왕복 테스트

**Files:**
- 없음 (Task 1 산출물 검증)

**Interfaces:**
- Consumes: `CLAUDE_CMUX_NOTIFY_SETTINGS`, `install`/`uninstall`

- [ ] **Step 1: fake settings.json으로 왕복 검증**

```bash
S=$(mktemp -d)/settings.json
cp ~/.claude/settings.json "$S"                                  # 실제 구조 복사 (훅 4개 포함)
export CLAUDE_CMUX_NOTIFY_SETTINGS="$S"
scripts/bin/claude-cmux-notify install                           # removed 4, installed Stop
python3 -c "import json;d=json.load(open('$S'));print(len(d['hooks']['Stop']), sorted(d['hooks']), 'statusLine' in d)"
# → 1 ['Stop'] True
scripts/bin/claude-cmux-notify install                           # 멱등: removed 1, 다시 1개
python3 -c "import json;d=json.load(open('$S'));print(len(d['hooks']['Stop']))"   # → 1
scripts/bin/claude-cmux-notify uninstall
python3 -c "import json;d=json.load(open('$S'));print('hooks' in d)"              # → False
echo 'broken' > "$S" && scripts/bin/claude-cmux-notify install; echo "exit=$?"    # 파싱 에러로 중단, 파일 불변
rm -rf "$(dirname "$S")"; unset CLAUDE_CMUX_NOTIFY_SETTINGS
```

Expected: 주석대로. 백업 파일이 매 실행 생성됨.

- [ ] **Step 2: 문제 발견 시 수정 후 커밋, 없으면 넘어감**

---

### Task 3: 문서 + README

**Files:**
- Create: `scripts/bin/claude-cmux-notify.md`
- Modify: `README.md` (툴 목록)

- [ ] **Step 1: claude-cmux-notify.md 작성**

내용: 개요(1 훅 = 1 배너 = 클릭 시 워크스페이스 점프), 요구사항(cmux + 알림 권한 1회 허용, python3, 선택 terminal-notifier), 사용법(install/uninstall/훅 모드), 동작 세부(cmux notify 경로·폴백·Stop만 등록하는 이유 — cmux 래퍼가 입력 대기를 이미 알림), 새 머신 재현 절차.

- [ ] **Step 2: README 툴 목록에 항목 추가**

```markdown
- **claude-cmux-notify** — Claude Code 턴 종료 시 macOS 알림, 클릭하면 해당
  cmux 워크스페이스로 점프. `claude-cmux-notify install`로 훅 등록.
  자세한 내용은 `scripts/bin/claude-cmux-notify.md`.
```

- [ ] **Step 3: Commit**

```bash
git add scripts/bin/claude-cmux-notify.md README.md
git commit -m "docs: document claude-cmux-notify"
```

---

### Task 4: 실 설치 + E2E + main 푸시

- [ ] **Step 1: 실제 설치**

```bash
scripts/bin/claude-cmux-notify install
cat ~/.claude/settings.json    # Stop 1개(절대 경로), 기존 terminal-notifier 훅 4개 제거 확인
```

- [ ] **Step 2: E2E** — 새 훅은 새 세션부터 적용되므로, 사용자에게 안내: 다음 턴 종료 시(또는 새 세션에서) 배너 클릭 → 워크스페이스 점프 확인. cmux notify 등록 자체는 Task 1 Step 3에서 검증됨.

- [ ] **Step 3: main 머지 + push**

```bash
git checkout main && git merge feat/claude-cmux-notify && git branch -d feat/claude-cmux-notify
git push origin main
```

## Self-Review 결과

- 스펙 커버리지: §1→Task 1·3, §2(알림 모드)→Task 1, §3(install)→Task 1·2, §4(에러)→Task 1 코드·Task 2 파싱 실패 케이스, §5(검증)→Task 2·4. 갭 없음.
- 플레이스홀더: 없음. 전체 스크립트 코드 포함.
- 일관성: env 이름 `CLAUDE_CMUX_NOTIFY_SETTINGS`, 백업 패턴, 제거 기준이 스펙과 동일.
