# fe-dev 스킬 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 백엔드 개발자가 FE 레포에서 작업할 때 쓰는 `fe-dev` 스킬(스타일 파악 → 작업 → 증거 기반 검증 루프)을 만들고, dotfiles의 install/uninstall이 스킬을 `~/.claude/skills`로 심링크 배포하도록 확장한다.

**Architecture:** 단일 스킬 + 단계별 reference 파일(progressive disclosure). 스킬은 FE 지식만 담고 프로세스(TDD·디버깅·완료검증)는 superpowers에 위임한다. 배포는 복사가 아닌 심링크라 레포 수정이 즉시 반영된다.

**Tech Stack:** Claude Code skill (SKILL.md + references/), POSIX sh (install/uninstall), macOS.

**Spec:** `docs/superpowers/specs/2026-07-09-fe-dev-skill-design.md`

## Global Constraints

- install.sh / uninstall.sh는 POSIX sh 유지 (`#!/bin/sh`, `set -eu`, bashism 금지). macOS 전용 관례(`sed -i ''`)는 기존 그대로 둔다.
- 스킬 frontmatter `description`은 영어(트리거 매칭용), 본문·reference는 한국어.
- 배포는 심링크만 사용. 파일 복사 금지.
- 스킬이 대상 FE 레포에 남기는 파일은 `.claude/fe-style.md` 하나뿐.
- 스킬 본문에 superpowers 프로세스 내용을 복붙하지 않는다 — 스킬 이름으로 위임만.
- 심링크 보정은 zshrc 블록 존재 여부와 독립적으로 매 실행 시 수행.
- 셸 스크립트 검증은 fake HOME(`HOME=$TESTHOME`)으로 실제 실행해서 확인한다.

---

### Task 1: skills/fe-dev/SKILL.md (오케스트레이터)

**Files:**
- Create: `skills/fe-dev/SKILL.md`

**Interfaces:**
- Produces: 디렉터리 이름 `skills/fe-dev/` (Task 5·6의 install/uninstall이 이 이름으로 심링크를 만들고 지움), reference 경로 `references/style-scan.md`, `references/fe-for-backend.md`, `references/verify-loop.md` (Task 2·3·4가 정확히 이 경로에 파일을 만들어야 함)

- [ ] **Step 1: 파일 작성**

`skills/fe-dev/SKILL.md`:

````markdown
---
name: fe-dev
description: Use when asked to add features, fix bugs, or refactor in a frontend repository (React/Vue/Next/Svelte/etc.) and the user has a backend background — establishes repo conventions first, explains plans in backend terms, delegates process to superpowers skills, and requires an evidence-based verification loop (static checks, tests, build, real browser via Playwright) before declaring completion
---

# fe-dev — FE 작업 워크플로 (백엔드 개발자용)

frontend 레포 작업을 3단계로 진행한다. 이 스킬은 FE 지식만 담당하고,
작업 프로세스는 superpowers 스킬에 위임한다.

**원칙: 스킬은 FE 지식을, superpowers는 프로세스를.**

## 체크리스트

아래 3단계를 각각 task로 만들어 순서대로 진행한다.

1. 스타일 파악
2. 태스크 분석·작업
3. 검증 루프

## 1. 스타일 파악

- 대상 레포 루트의 `.claude/fe-style.md`가 있으면 읽고 바로 2단계로.
- 없으면 `references/style-scan.md`를 읽고 절차대로 생성한다.
- FE 레포가 아니라고 판별되면(기준은 style-scan.md) 즉시 중단하고 사용자에게 알린다.
- 이후 어느 단계에서든 fe-style.md가 실제 코드와 모순되면 그 자리에서 갱신한다.

## 2. 태스크 분석·작업

- 관련 파일을 탐색하고 변경 계획을 세운다.
- 계획·결과를 사용자에게 설명할 때는 백엔드 용어로 번역한다 —
  `references/fe-for-backend.md`를 읽고 비유를 사용하되, 비유가 깨지는 지점을 명시.
- 구현 프로세스는 superpowers에 위임:
  - 요구사항이 모호한 기능 → superpowers:brainstorming
  - 구현 → superpowers:test-driven-development
  - 버그 수정 → superpowers:systematic-debugging
- 테스트는 fe-style.md의 "테스트 패턴" 섹션에 기록된 이 레포의 실제 관례를 따른다.
  새 패턴을 발명하지 않는다.

## 3. 검증 루프

- `references/verify-loop.md`를 읽고 증거 사다리를 레벨 1부터 실행한다.
- 어느 레벨이든 실패하면 수정 후 레벨 1부터 재실행. 전 레벨 green까지 반복.
- 증거 없이 완료를 선언하지 않는다 (superpowers:verification-before-completion과 동일 원칙).

## 경계

- 대상 레포에 남기는 파일은 `.claude/fe-style.md` 하나뿐이다.
  커밋/gitignore 여부는 사용자가 결정한다.
- 모노레포면 루트 fe-style.md 하나에 워크스페이스 구조와 패키지별 명령을 기록한다.
````

- [ ] **Step 2: 검증 — frontmatter와 구조 확인**

Run: `head -4 skills/fe-dev/SKILL.md`
Expected: `---` / `name: fe-dev` / `description: Use when...` 시작

- [ ] **Step 3: Commit**

```bash
git add skills/fe-dev/SKILL.md
git commit -m "feat: add fe-dev skill orchestrator"
```

---

### Task 2: references/style-scan.md (1단계 절차)

**Files:**
- Create: `skills/fe-dev/references/style-scan.md`

**Interfaces:**
- Consumes: Task 1이 참조하는 경로 `references/style-scan.md`
- Produces: 대상 레포 산출물 규격 `.claude/fe-style.md` (Task 3의 verify-loop가 "실행 명령" 섹션을 그대로 사용)

- [ ] **Step 1: 파일 작성**

`skills/fe-dev/references/style-scan.md`:

````markdown
# style-scan — 레포 스타일 파악 절차

산출물: 대상 레포 루트의 `.claude/fe-style.md`. 이 파일은 이후 모든 세션의
출발점이고, 검증 루프가 "실행 명령" 섹션을 그대로 사용한다.

## 0. FE 레포 판별 (게이트)

다음 중 하나라도 만족하면 FE 레포로 본다:

- `package.json`의 dependencies/devDependencies에 react, vue, svelte, angular,
  solid-js, astro, next, nuxt 중 하나가 있다.
- vite/webpack 설정과 함께 진입 `index.html` 또는 `src/main.*`/`src/index.*`가 있다.

아니면 **즉시 중단**하고 사용자에게 "FE 레포가 아닌 것 같다"고 판별 근거와 함께
알린다. 추측으로 진행하지 않는다.

## 1. 스캔 항목

각 항목은 설정 파일 선언이 아니라 **실제 코드에서 귀납**해서 확인한다.

| 항목 | 확인 방법 |
|---|---|
| 프레임워크·언어 | package.json dependencies, tsconfig.json 유무 |
| 패키지 매니저 | lockfile: pnpm-lock.yaml → pnpm, yarn.lock → yarn, package-lock.json → npm, bun.lockb → bun |
| 실행 명령 | package.json scripts에서 dev/build/test/lint/typecheck 해당 항목. 없으면 프레임워크 기본값 대신 **없다고 기록** |
| 디렉터리·명명 규칙 | src/ 아래 실제 배치를 2~3개 기능 단위로 관찰 (pages/components/hooks 구분, PascalCase 여부, index 파일 사용 등) |
| 스타일링 | 실제 컴포넌트 파일 2~3개에서 확인: Tailwind 클래스 / CSS Modules import / styled-components / vanilla-extract 등 |
| 상태·데이터 | 전역 상태 라이브러리(redux/zustand/jotai 등)와 데이터 페칭(react-query/swr/fetch 직접) — 실제 사용 파일 경로와 함께 |
| 테스트 패턴 | 기존 테스트 파일을 최소 1개 열어 러너(vitest/jest/playwright), 위치 규칙(co-located vs __tests__), 스타일(testing-library 등)을 기록. 테스트가 없으면 없다고 기록 |
| 모노레포 | pnpm-workspace.yaml / workspaces 필드. 있으면 FE 패키지 위치와 패키지별 명령 기록 |

## 2. 산출물 템플릿

`.claude/fe-style.md`를 이 구조로 작성한다:

```markdown
# FE Style — <레포 이름> (generated <오늘 날짜>)

## 스택 요약
<프레임워크, TS 여부, 패키지 매니저 — 한두 줄>

## 실행 명령
- dev: <명령 또는 "없음">
- build: <명령>
- test: <명령>
- lint: <명령>
- typecheck: <명령 또는 "없음">

## 컨벤션
<파일 배치, 명명, import 스타일 — 실제 예시 경로 포함>

## 스타일링
<방식 + 근거가 된 파일 경로>

## 상태·데이터
<라이브러리 + 실제 사용 파일 경로>

## 테스트 패턴
<러너, 위치 규칙, 예시 테스트 파일 경로, 관례>

## 주의사항
<함정: dev 서버 포트, 필요한 env, 느린 빌드 등. 발견될 때마다 추가>
```

## 3. 갱신 정책

- 생성 날짜만 기록한다. 해시·mtime 비교 같은 자동 staleness 감지는 하지 않는다.
- 작업 중 이 파일과 실제 코드가 모순되면 **그 자리에서** 해당 섹션을 갱신한다.
- 포트 충돌, env 부재 같은 함정을 만나면 "주의사항"에 추가해 다음 세션이
  같은 함정에 빠지지 않게 한다.
````

- [ ] **Step 2: 검증 — Task 1이 참조하는 경로와 일치 확인**

Run: `ls skills/fe-dev/references/style-scan.md && grep -c 'fe-style.md' skills/fe-dev/references/style-scan.md`
Expected: 파일 존재, fe-style.md 언급 다수

- [ ] **Step 3: Commit**

```bash
git add skills/fe-dev/references/style-scan.md
git commit -m "feat: add fe-dev style-scan reference"
```

---

### Task 3: references/verify-loop.md (3단계 절차)

**Files:**
- Create: `skills/fe-dev/references/verify-loop.md`

**Interfaces:**
- Consumes: `.claude/fe-style.md`의 "실행 명령"·"주의사항" 섹션 (Task 2 규격)
- Produces: 완료 보고 형식 (SKILL.md 3단계가 요구하는 증거의 정의)

- [ ] **Step 1: 파일 작성**

`skills/fe-dev/references/verify-loop.md`:

````markdown
# verify-loop — 증거 기반 검증 루프

작업 후 아래 증거 사다리를 **레벨 1부터 순서대로 전부** 통과해야 완료다.
명령은 fe-style.md의 "실행 명령" 섹션 것을 그대로 쓴다.

## 증거 사다리

| 레벨 | 수단 | 통과 기준 (증거) |
|---|---|---|
| 1. 정적 | lint + typecheck | 두 명령 모두 exit 0, 출력 확보 |
| 2. 테스트 | 레포 테스트 러너 | 전체 통과. 이번 작업에서 추가한 테스트가 실제로 실행됐는지 출력에서 확인 |
| 3. 빌드 | production build | exit 0 |
| 4. 런타임 | dev 서버 + Playwright로 변경 플로우 직접 조작 | 아래 상세 |
| 5. API | curl로 API route/BFF 직접 호출 | 이번 작업이 API route를 만들었거나 고쳤을 때만. 기대 상태코드 + 응답 본문 확인 |

fe-style.md에 lint/typecheck 명령이 "없음"이면 그 레벨은 건너뛰되,
완료 보고에 "이 레포에는 lint/typecheck가 없다"고 명시한다.

## 레벨 4 상세 (런타임)

1. fe-style.md의 dev 명령으로 서버를 백그라운드 기동. 포트·env는 "주의사항" 참조.
2. Playwright MCP 도구로 검증한다:
   - `browser_navigate`로 변경된 화면 진입
   - 변경 플로우를 실제로 조작 (클릭, 입력, 폼 제출 — 페이지 로드 확인만으로는 부족)
   - `browser_console_messages` — 에러 0이어야 통과 (기존에 있던 에러면 작업 전
     상태와 비교해 이번 변경이 원인이 아님을 확인하고 보고에 명시)
   - `browser_network_requests` — 이번 플로우에서 4xx/5xx 0
   - `browser_take_screenshot` — 변경 결과 스크린샷 확보
3. 검증이 끝나면 띄운 dev 서버를 종료한다.

**fallback 금지**: dev 서버 기동 실패, 브라우저 사용 불가 등으로 레벨 4를
수행할 수 없으면 건너뛰지 말고 **검증 실패로 취급해 사용자에게 보고**한다.
조용한 다운그레이드 금지.

## 루프 규칙

- 어느 레벨이든 실패 → superpowers:systematic-debugging으로 원인 규명 → 수정 →
  **레벨 1부터 재실행** (수정이 앞 레벨을 깨뜨렸을 가능성 배제).
- 같은 레벨이 같은 원인으로 3회 실패하면 루프를 멈추고, 시도한 것·실패 증거·
  가설을 정리해 사용자에게 보고한다.

## 완료 보고 형식

1. 변경 파일 목록
2. 레벨별 증거 (명령 출력 요약, 스크린샷, 콘솔/네트워크 확인 결과)
3. 남은 리스크 (검증 못 한 것, 기존부터 있던 문제 등)

증거가 없는 항목은 "완료"라고 쓰지 않는다.
````

- [ ] **Step 2: 검증 — Playwright MCP 도구 이름 확인**

Run: `grep -o 'browser_[a-z_]*' skills/fe-dev/references/verify-loop.md | sort -u`
Expected: `browser_console_messages`, `browser_navigate`, `browser_network_requests`, `browser_take_screenshot` — 실제 playwright MCP 도구 이름과 일치

- [ ] **Step 3: Commit**

```bash
git add skills/fe-dev/references/verify-loop.md
git commit -m "feat: add fe-dev verify-loop reference"
```

---

### Task 4: references/fe-for-backend.md (번역표)

**Files:**
- Create: `skills/fe-dev/references/fe-for-backend.md`

**Interfaces:**
- Consumes: SKILL.md 2단계가 "설명할 때 읽는" 참조 자료로 지정

- [ ] **Step 1: 파일 작성**

`skills/fe-dev/references/fe-for-backend.md`:

````markdown
# fe-for-backend — 백엔드 ↔ FE 개념 번역표

사용자(백엔드 개발자)에게 계획·결과를 설명할 때 이 표의 비유를 사용한다.

**설명 원칙: 비유로 시작하되, 비유가 깨지는 지점을 한 문장으로 명시한다.**

| FE 개념 | 백엔드 비유 | 비유가 깨지는 지점 |
|---|---|---|
| 컴포넌트 | 핸들러 + 템플릿 (입력 props → 출력 UI) | 핸들러와 달리 상태를 가지며 살아있는 동안 여러 번 재실행(리렌더)된다 |
| props | 함수 인자 / DTO | 부모가 바뀌면 자동으로 다시 내려온다 — 호출이 아니라 구독에 가깝다 |
| state / setState | 인스턴스 필드 + 변경 알림 | 값을 바꾸면 프레임워크가 해당 컴포넌트를 다시 실행한다 |
| 전역 상태 (Redux/zustand) | 인메모리 캐시 + pub/sub | 서버와 달리 새로고침하면 날아간다 (영속화는 별도) |
| React Query / SWR 캐시 | read-through 캐시 + TTL/무효화 | 무효화가 화면 리렌더까지 연쇄된다 |
| hook (useXxx) | 재사용 가능한 미들웨어/유틸 | 호출 순서 규칙이 있다 (조건문 안에서 호출 금지) |
| hydration | 직렬화된 상태의 역직렬화 + 리스너 재연결 | 서버 HTML과 클라이언트 렌더 결과가 다르면 경고/깨짐 (hydration mismatch) |
| CSR / SSR | 클라이언트 렌더 vs 서버 사이드 템플릿 렌더 | SSR 코드는 브라우저 API(window 등)를 쓸 수 없다 |
| API route / BFF | 컨트롤러 얇은 버전 | FE 레포 안에 살지만 실행은 서버 — curl로 직접 테스트 가능 |
| 번들러 (vite/webpack) | 빌드 도구 + 링커 | dev 모드는 번들 없이 즉석 변환이라 prod 빌드에서만 터지는 문제가 있다 |
| 리렌더 성능 문제 | N+1 쿼리와 비슷한 증식 패턴 | 프로파일링 도구가 다르다 (React DevTools Profiler) |

표에 없는 개념을 설명하게 되면, 같은 형식(비유 + 깨지는 지점)으로
이 표에 추가한다.
````

- [ ] **Step 2: 검증 — 표 형식 확인**

Run: `grep -c '^|' skills/fe-dev/references/fe-for-backend.md`
Expected: 13 이상 (헤더 2 + 항목 11)

- [ ] **Step 3: Commit**

```bash
git add skills/fe-dev/references/fe-for-backend.md
git commit -m "feat: add fe-dev backend-to-FE translation table"
```

---

### Task 5: install.sh — 스킬 심링크 설치

**Files:**
- Modify: `install.sh` (전체 교체, 아래 최종본)

**Interfaces:**
- Consumes: `skills/<name>/` 디렉터리 규칙 (Task 1), `~/.claude/skills/<name>` 심링크 규칙
- Produces: `link_skill()` 동작 — Task 6의 uninstall이 같은 심링크를 제거, Task 8의 e2e가 실제 설치에 사용

- [ ] **Step 1: 실패하는 테스트 — fake HOME에서 현재 동작 확인**

```bash
TESTHOME=$(mktemp -d) && HOME="$TESTHOME" sh install.sh && ls "$TESTHOME/.claude/skills/fe-dev"
```

Expected: FAIL — `ls: .../skills/fe-dev: No such file or directory` (현재 install.sh는 스킬을 모름)

- [ ] **Step 2: install.sh를 아래 최종본으로 교체**

```sh
#!/bin/sh
# install.sh            — idempotent installer: wire this repo into ~/.zshrc + ~/.claude/skills
# install.sh <tool>...  — re-enable tools disabled by uninstall.sh <tool>
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER="# >>> dotfiles >>>"
SKILLS_DIR="$HOME/.claude/skills"

link_skill() {
  mkdir -p "$SKILLS_DIR"
  ln -sfn "$1" "$SKILLS_DIR/$(basename "$1")"
}

if [ $# -gt 0 ]; then
  for name in "$@"; do
    found=0
    for f in "$DOTFILES/scripts/zsh/$name.zsh" "$DOTFILES/scripts/bin/$name"; do
      if [ -e "$f.disabled" ]; then
        mv "$f.disabled" "$f"
        echo "enabled: $f"
        found=1
      fi
    done
    if [ -d "$DOTFILES/skills/$name" ]; then
      link_skill "$DOTFILES/skills/$name"
      echo "enabled: skill $name -> $SKILLS_DIR/$name"
      found=1
    fi
    [ $found -eq 1 ] || echo "nothing to enable for: $name"
  done
  echo "restart your shell (or 'source $ZSHRC') to apply"
  exit 0
fi

# skills: symlink every skills/<name>/ — runs on every install,
# independent of the zshrc block below
for d in "$DOTFILES"/skills/*/; do
  [ -d "$d" ] || continue
  link_skill "${d%/}"
  echo "skill linked: $SKILLS_DIR/$(basename "$d")"
done

if grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
  echo "already installed in $ZSHRC"
  exit 0
fi

cat >> "$ZSHRC" <<EOF

$MARKER
export DOTFILES="$DOTFILES"
for f in "\$DOTFILES"/scripts/zsh/*.zsh(N); do source "\$f"; done
export PATH="\$DOTFILES/scripts/bin:\$PATH"
# <<< dotfiles <<<
EOF

echo "installed: $ZSHRC now sources $DOTFILES/scripts/zsh/*.zsh"
echo "restart your shell or run: source $ZSHRC"
```

- [ ] **Step 3: 테스트 통과 확인 (설치 + 멱등성 + 개별 enable)**

```bash
TESTHOME=$(mktemp -d)
HOME="$TESTHOME" sh install.sh                 # 1차: 링크 + zshrc 블록
readlink "$TESTHOME/.claude/skills/fe-dev"     # → <repo>/skills/fe-dev
HOME="$TESTHOME" sh install.sh                 # 2차: "already installed", 링크 유지, 에러 없음
grep -c '>>> dotfiles >>>' "$TESTHOME/.zshrc"  # → 1 (블록 중복 없음)
rm "$TESTHOME/.claude/skills/fe-dev"
HOME="$TESTHOME" sh install.sh fe-dev          # → "enabled: skill fe-dev -> ..."
readlink "$TESTHOME/.claude/skills/fe-dev"     # → 다시 생성됨
HOME="$TESTHOME" sh install.sh no-such-tool    # → "nothing to enable for: no-such-tool"
```

Expected: 주석대로 전부 통과. `set -eu` 아래에서 어떤 단계도 비정상 종료 없음.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: install skills into ~/.claude/skills via symlink"
```

---

### Task 6: uninstall.sh — 스킬 심링크 제거

**Files:**
- Modify: `uninstall.sh` (전체 교체, 아래 최종본)

**Interfaces:**
- Consumes: Task 5의 심링크 규칙 (`~/.claude/skills/<name>` → `$DOTFILES/skills/<name>`)

- [ ] **Step 1: 실패하는 테스트 — 현재 uninstall이 스킬 링크를 남기는 것 확인**

```bash
TESTHOME=$(mktemp -d)
HOME="$TESTHOME" sh install.sh
HOME="$TESTHOME" sh uninstall.sh
ls "$TESTHOME/.claude/skills/"
```

Expected: FAIL — `fe-dev` 링크가 남아 있음 (제거됐어야 함)

- [ ] **Step 2: uninstall.sh를 아래 최종본으로 교체**

```sh
#!/bin/sh
# uninstall.sh            — remove the dotfiles block from ~/.zshrc and skill
#                           symlinks from ~/.claude/skills (full unlink)
# uninstall.sh <tool>...  — disable specific tools: rename to *.disabled,
#                           remove skill symlink (re-enable with: install.sh <tool>)
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER_BEGIN="# >>> dotfiles >>>"
MARKER_END="# <<< dotfiles <<<"
SKILLS_DIR="$HOME/.claude/skills"

if [ $# -eq 0 ]; then
  # skill symlinks pointing into this repo
  if [ -d "$SKILLS_DIR" ]; then
    for link in "$SKILLS_DIR"/*; do
      [ -L "$link" ] || continue
      case "$(readlink "$link")" in
        "$DOTFILES"/skills/*)
          rm "$link"
          echo "removed skill link: $link"
          ;;
      esac
    done
  fi

  if grep -qF "$MARKER_BEGIN" "$ZSHRC" 2>/dev/null; then
    cp "$ZSHRC" "$ZSHRC.bak"
    sed -i '' "/^$MARKER_BEGIN\$/,/^$MARKER_END\$/d" "$ZSHRC"
    echo "removed dotfiles block from $ZSHRC (backup: $ZSHRC.bak)"
  else
    echo "no dotfiles block in $ZSHRC"
  fi
  echo "files under $DOTFILES are untouched"
  exit 0
fi

for name in "$@"; do
  found=0
  for f in "$DOTFILES/scripts/zsh/$name.zsh" "$DOTFILES/scripts/bin/$name"; do
    if [ -e "$f" ]; then
      mv "$f" "$f.disabled"
      echo "disabled: $f -> $f.disabled"
      found=1
    fi
  done
  if [ -d "$DOTFILES/skills/$name" ] && [ -L "$SKILLS_DIR/$name" ]; then
    rm "$SKILLS_DIR/$name"
    echo "disabled: skill $name (removed $SKILLS_DIR/$name)"
    found=1
  fi
  [ $found -eq 1 ] || echo "no such tool: $name (looked for scripts/zsh/$name.zsh, scripts/bin/$name, skills/$name)"
done
echo "restart your shell (or 'source $ZSHRC') to apply"
```

- [ ] **Step 3: 테스트 통과 확인 (전체 제거 + 개별 disable + 왕복)**

```bash
TESTHOME=$(mktemp -d)
HOME="$TESTHOME" sh install.sh
HOME="$TESTHOME" sh uninstall.sh fe-dev            # → "disabled: skill fe-dev ..."
ls "$TESTHOME/.claude/skills/" | grep -c fe-dev    # → 0
HOME="$TESTHOME" sh install.sh fe-dev              # 왕복: 다시 enable
HOME="$TESTHOME" sh uninstall.sh                   # 전체 제거
ls "$TESTHOME/.claude/skills/" | grep -c fe-dev    # → 0
grep -c '>>> dotfiles' "$TESTHOME/.zshrc"          # → 0 (블록 제거됨)
HOME="$TESTHOME" sh uninstall.sh                   # 재실행: "no dotfiles block", 에러 없음 (멱등)
```

Expected: 주석대로 전부 통과. 마지막 재실행이 exit 0.

주의: `grep -c`는 매치 0일 때 exit 1이므로 확인 단계에서는 `|| true`를 붙이거나 출력만 본다.

- [ ] **Step 4: Commit**

```bash
git add uninstall.sh
git commit -m "feat: uninstall removes skill symlinks; per-tool disable covers skills"
```

---

### Task 7: README 갱신

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: Task 1~6의 최종 동작 (구조, install/uninstall UX)

- [ ] **Step 1: 구조 다이어그램에 skills 추가**

`README.md`의 구조 블록을 다음으로 교체:

```markdown
```
scripts/
  zsh/          # zshrc가 source하는 함수들 (*.zsh 전부 자동 로드)
  bin/          # PATH에 얹는 단독 실행 스크립트
skills/         # Claude Code 스킬 (~/.claude/skills로 심링크 설치)
install.sh      # ~/.zshrc에 로더 블록 추가 + 스킬 심링크 (멱등)
```
```

설치/제거 섹션 아래에 한 줄 추가:

```markdown
스킬은 `~/.claude/skills/<name>` 심링크로 설치되어 레포 수정이 즉시 반영된다.
`uninstall.sh <name>` / `install.sh <name>`으로 스킬도 zsh 툴처럼 on/off 된다.
```

- [ ] **Step 2: 툴 목록에 fe-dev 추가**

`## 툴` 섹션에 추가:

```markdown
- **fe-dev** (skill) — 백엔드 개발자용 FE 작업 워크플로.
  레포 스타일 파악(`.claude/fe-style.md` 영속화) → superpowers 위임 작업 →
  playwright/curl 증거 기반 검증 루프. Claude Code에서 FE 레포 작업 시 자동 트리거.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document skills directory and fe-dev"
```

---

### Task 8: E2E 검증 — 실제 설치 + 스킬 로드 확인

**Files:**
- 없음 (검증만)

**Interfaces:**
- Consumes: Task 1~6 전부

- [ ] **Step 1: 실제 HOME에 설치**

```bash
./install.sh
readlink ~/.claude/skills/fe-dev
```

Expected: `<repo>/skills/fe-dev` 출력. zshrc는 이미 설치돼 있으면 "already installed" (스킬 링크는 그와 무관하게 생성됨 — Global Constraints 확인 지점).

- [ ] **Step 2: 스킬 인식 확인**

새 Claude Code 세션(또는 현재 세션의 스킬 목록)에서 `fe-dev`가 user-invocable 스킬로 보이는지 확인. 보이지 않으면 frontmatter(name과 디렉터리명 일치, description 존재)를 점검한다.

- [ ] **Step 3: superpowers:writing-skills 검증 절차 적용**

superpowers:writing-skills 스킬을 읽고, 그 안의 스킬 검증 체크리스트(설명이 트리거를 정확히 기술하는지, 본문이 절차로 실행 가능한지)를 fe-dev에 적용한다. 발견된 문제는 수정 후 재확인.

- [ ] **Step 4: 실전 사이클 (수동, 별도 세션)**

실제 FE 레포 하나에서 소형 태스크(문구 변경 + 테스트 수준)로 1→2→3단계 풀 사이클을 실행한다. 확인 포인트:
- `.claude/fe-style.md`가 템플릿 구조대로 생성되는가
- 검증 루프가 레벨 1~4를 실제로 수행하고 증거를 첨부하는가
- fallback 금지 규칙이 지켜지는가 (레벨 4 불가 시 실패 보고)

발견된 문제는 skills/fe-dev/ 파일 수정으로 반영 (심링크라 재설치 불필요).

- [ ] **Step 5: 최종 커밋 (수정 사항이 있었다면)**

```bash
git add skills/fe-dev
git commit -m "fix: adjust fe-dev skill after end-to-end run"
```

---

## Self-Review 결과

- **스펙 커버리지**: 스펙 §1(구조·배포)→Task 1,5,6 / §2(SKILL.md)→Task 1 / §3(style-scan)→Task 2 / §4(verify-loop)→Task 3 / §5(번역표)→Task 4 / §6(엣지)→Task 2 게이트·Task 3 fallback·모노레포는 SKILL.md 경계 섹션 / §7(자체 검증)→Task 8 / README→Task 7. 갭 없음.
- **플레이스홀더**: 없음 — 모든 파일 내용과 명령이 실제 값.
- **일관성**: 디렉터리명 `fe-dev` = frontmatter `name` = install/uninstall 대상명. reference 경로 3개가 Task 1 본문과 Task 2·3·4 생성 경로에서 동일. `link_skill`/`SKILLS_DIR`는 Task 5·6에서 동일 규칙.
