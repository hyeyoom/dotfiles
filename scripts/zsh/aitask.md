# aitask

git worktree + cmux 탭 + Claude 세션을 **task 단위로 만들고 정리하는 런처**.

"1 task = 1 branch = 1 worktree = 1 cmux 탭 = 1 Claude 세션" 모델을 명령 하나로 실행한다.
worktree는 Docker 컨테이너처럼 disposable하게 쓴다: 만들고 → 작업하고 → PR 올리고 → 버린다.

## 요구사항

- zsh (zshrc 로더가 source하는 함수라서 bash 불가)
- git 2.5+ (worktree)
- [cmux](https://cmux.com) — Unix socket CLI 포함 버전 (0.64+에서 검증)
- [Claude Code](https://claude.com/claude-code) CLI (`claude`)
- fzf — 인터랙티브 메뉴에만 필요 (없으면 커맨드는 전부 동작)
- gh — PR 상태 표시·PR 생성에만 필요 (없으면 해당 기능만 조용히 생략)

## 사용법

```sh
aitask                        # 인터랙티브 메뉴 (fzf) — 아래 참조
aitask <repo> <task> [prefix|-] [탭제목]   # = aitask new
aitask new  <repo> <task> [prefix|-] [탭제목]
                              # worktree + cmux 탭 + claude + git pane 생성
                              # branch = <prefix>/<task> (기본 task/)
                              # 탭제목 지정 시 탭이 "<repo>/<task> · <탭제목>"
                              # prefix 자리에 -를 주면 기본 접두사 유지
aitask done <repo> <task>     # base에 머지 → worktree/브랜치 제거 → 탭 닫기
aitask drop <repo> <task>     # 폐기 (상태 요약 + 확인, 아래 안전장치 참조)
aitask ls                     # 진행 중 task 목록 + push/머지/PR 상태
aitask root add <path>        # 레포 루트 등록
aitask root ls                # 루트 목록
aitask help
```

### 인터랙티브 메뉴

인자 없이 `aitask`를 실행하면 fzf 메뉴가 뜬다. 커맨드/이름을 기억할 필요가 없다.

- 진행 중 task 목록 (repo/task, 브랜치, 상태 플래그, PR 상태). 오른쪽
  preview에 해당 worktree의 `git status` + 최근 로그.
- task 선택 → 액션 선택:
  - **탭으로 이동** — 해당 cmux 탭에 포커스. 탭을 닫아버렸으면 재생성.
  - **PR 생성** — `git push -u origin <branch>` 후 `gh pr create --web`.
    커밋 안 된 변경이나 커밋 0개면 안내하고 중단.
  - **drop** — 아래 안전장치를 거쳐 폐기.
- `[+ new task]` → repo를 fzf로 고르고 task 이름 입력 → 브랜치 접두사 선택
  (task / features / hotfix / bugfix / release / chore) → 탭 제목 입력
  (엔터로 생략하면 기본 `<repo>/<task>`).
- task가 하나도 없으면 바로 새 task 생성 흐름으로 진입.

### 예시

```sh
aitask arcana toss-review-fix
# → ~/github/arcana.wt/toss-review-fix worktree (branch task/toss-review-fix)
# → cmux 탭 "arcana/toss-review-fix": 왼쪽 claude, 오른쪽 git status/log
# → worktree에 CLAUDE.local.md 생성 (작업 스코프, Claude가 매 턴 자동 로드)
# 같은 명령을 다시 치면 탭을 새로 만들지 않고 기존 탭에 포커스만 한다.

# ... Claude와 작업, worktree에서 커밋 ...

aitask            # 메뉴에서 task 선택 → "PR 생성" → 리뷰/머지 후 → "drop"
```

## task 이름과 브랜치 접두사

task 이름은 `영숫자 . _ -`만 허용, 첫 글자는 영숫자 (예: `AIT-123`,
`AIT-123-fix-login`). `/`·공백은 거부된다 — 슬래시가 든 이름은 worktree가
중첩 경로에 생겨 `ls`에 안 보이고 drop 시 이름 불일치를 일으키기 때문.

브랜치 네이밍 컨벤션(`features/…`, `hotfix/…`)은 이름이 아니라 **접두사 인자**로
지정한다. worktree 디렉터리는 항상 평평하게 유지되고 브랜치만 달라진다:

```sh
aitask arcana AIT-123 features   # worktree arcana.wt/AIT-123, branch features/AIT-123
aitask arcana oops-fix hotfix    # branch hotfix/oops-fix
aitask arcana refactor-db        # branch task/refactor-db (기본)
```

`done`/`drop`은 접두사를 따로 기억하지 않고 worktree의 실제 브랜치를 조회해서
동작한다. 같은 task를 `new`로 다시 열면 접두사 인자와 무관하게 기존 브랜치를
유지한다.

## repo 인자 해석

- `arcana`처럼 이름만 주면 등록된 모든 루트에서 `<root>/arcana/.git`을 검색한다.
- 두 루트에 같은 이름이 있으면 후보를 전부 보여주고 에러로 멈춘다.
- `/`가 포함되면 경로로 직접 해석한다: `aitask ~/work/arcana fix-login`

## 디렉터리 규칙

```
<root>/
  arcana/                    # canonical checkout — 항상 깨끗하게 유지
  arcana.wt/                 # disposable worktrees (마지막 task drop 시 자동 삭제)
    toss-review-fix/
    card-copy-revision/
```

worktree는 origin이 있으면 `origin/HEAD`(기본 브랜치 최신)에서 분기하고,
없으면 로컬 `HEAD`에서 분기한다. canonical checkout은 절대 건드리지 않는다
(`pull`/`checkout` 없음, `fetch`만 수행).

## ls 출력

```
arcana    toss-review-fix   task/toss-review-fix   *dirty ↑2       PR:open
arcana    card-copy         task/card-copy         merged          PR:merged
```

플래그: `*dirty`(미커밋 변경) / `↑n`·`↓n`(upstream 대비 ahead/behind, upstream이
없으면 origin 기본 브랜치 대비 ahead) / `local`(upstream 없음) / `merged`(origin
기본 브랜치에 포함됨). PR 상태는 repo당 `gh pr list` 1회로 조회하며 gh가 없거나
실패하면 생략된다 (5초 timeout, `timeout`/`gtimeout` 있을 때만).

## drop의 안전장치

drop은 확인 전에 상태 요약을 보여준다:

```
aitask: arcana/toss-review-fix (task/toss-review-fix)
  uncommitted : yes
  unpushed    : 2 commits (no upstream)
  merged      : no (into origin/main)
  PR          : OPEN https://github.com/...
```

- **안전한 상태** (clean이고 unpushed 0): 기존처럼 `[y/N]` 확인.
- **미보존 작업이 있는 상태** (dirty이거나 unpushed 커밋 존재): task 이름을
  그대로 타이핑해야 삭제된다. 병렬 task 여러 개를 돌리다 이름을 착각해서
  진행 중인 작업을 날리는 사고를 막기 위한 것.

## done의 안전장치

- worktree에 커밋 안 된 변경이 있으면 중단하고 `git status`를 보여준다.
- canonical checkout이 dirty하면 중단한다 (리뷰 중인 상태를 머지로 덮지 않도록).
- 머지는 `--no-ff`라 task 단위 히스토리가 머지 커밋으로 남는다.

PR 워크플로우가 기본이라면 `done` 대신 메뉴의 "PR 생성"을 쓰고, 머지 후
`drop`으로 정리한다. `done`은 origin 없는 로컬 전용 레포에서 유용하다.

## 동작 세부

- cmux 제어는 전부 공식 socket CLI를 쓴다: `new-workspace --cwd --command`,
  `new-split`, `send`/`send-key`, `find-window`, `select-workspace`,
  `close-workspace`.
- 탭 이름은 `<repo>/<task>` 또는 탭 제목 지정 시 `<repo>/<task> · <제목>`.
  탭 조회는 `<repo>/<task>` **정확 일치 + ` · ` 접미 허용**으로 한다
  (`find-window`는 substring 매칭이라 그대로 쓰면 `arcana/fix`가
  `arcana/fix-login`에 걸린다 — 타이틀의 상태 아이콘 접두를 벗겨 비교).
  ` · ` 구분자 앞부분을 손으로 바꾸면 자동으로 못 닫는다 (직접 닫으면 됨).
- `new`는 멱등: worktree·`CLAUDE.local.md`·탭이 이미 있으면 만들지 않고
  기존 탭에 포커스만 한다. `CLAUDE.local.md`에 손으로 넣은 내용은 보존된다.
- `CLAUDE.local.md`는 base 레포의 `.git/info/exclude`에 자동 등록되어 커밋에 섞이지 않는다.
- git pane 초기 명령은 셸 기동 레이스를 피하려고 1초 지연 후 백그라운드로 주입한다.

## 설정

- **루트 목록**: `~/.config/aitask/roots` — 한 줄에 하나. 파일이 없으면 기본값 `~/github`.
  `aitask root add`를 처음 실행하는 순간 기본값을 승계해서 파일이 생긴다.
- **환경변수**:
  | 변수 | 기본값 | 설명 |
  |---|---|---|
  | `AITASK_ROOTS_FILE` | `~/.config/aitask/roots` | 루트 목록 파일 경로 |
  | `AITASK_AGENT_CMD` | `claude` | 탭 왼쪽 pane에서 실행할 에이전트 명령 (codex 등으로 교체 가능) |
  | `AITASK_BRANCH_PREFIX` | `task` | 접두사 인자 생략 시 기본 브랜치 접두사 |
  | `AITASK_BRANCH_PREFIXES` | `task features hotfix bugfix release chore` | 메뉴에서 고를 수 있는 접두사 목록 (공백 구분) |

## 같이 쓰면 좋은 것

- `cmux hooks setup --agent claude` — Claude 상태(작업 중/입력 대기)를 cmux 탭·피드에 표시.
  병렬 세션 여러 개 돌릴 때 사실상 필수.
- `cmux diff --source last-turn` — Claude가 방금 턴에 만든 diff를 pane으로 시각화.
