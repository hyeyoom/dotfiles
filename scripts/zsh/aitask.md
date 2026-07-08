# aitask

git worktree + cmux 탭 + Claude 세션을 **task 단위로 만들고 정리하는 런처**.

"1 task = 1 branch = 1 worktree = 1 cmux 탭 = 1 Claude 세션" 모델을 명령 하나로 실행한다.
worktree는 Docker 컨테이너처럼 disposable하게 쓴다: 만들고 → 작업하고 → 머지하고 → 버린다.

## 요구사항

- zsh (zshrc 로더가 source하는 함수라서 bash 불가)
- git 2.5+ (worktree)
- [cmux](https://cmux.com) — Unix socket CLI 포함 버전 (0.64+에서 검증)
- [Claude Code](https://claude.com/claude-code) CLI (`claude`)

## 사용법

```sh
aitask <repo> <task>          # = aitask new
aitask new  <repo> <task>     # worktree + cmux 탭 + claude + git pane 생성
aitask done <repo> <task>     # base에 머지 → worktree/브랜치 제거 → 탭 닫기
aitask drop <repo> <task>     # 머지 없이 폐기 (확인 프롬프트)
aitask ls                     # 모든 루트의 진행 중 task 목록
aitask root add <path>        # 레포 루트 등록
aitask root ls                # 루트 목록
aitask help
```

### 예시

```sh
aitask arcana toss-review-fix
# → ~/github/arcana.wt/toss-review-fix worktree (branch task/toss-review-fix)
# → cmux 탭 "arcana/toss-review-fix": 왼쪽 claude, 오른쪽 git status/log
# → worktree에 CLAUDE.local.md 생성 (작업 스코프, Claude가 매 턴 자동 로드)

# ... Claude와 작업, worktree에서 커밋 ...

aitask done arcana toss-review-fix
# → canonical checkout에 --no-ff 머지, worktree/브랜치 삭제, cmux 탭 닫기
```

## repo 인자 해석

- `arcana`처럼 이름만 주면 등록된 모든 루트에서 `<root>/arcana/.git`을 검색한다.
- 두 루트에 같은 이름이 있으면 후보를 전부 보여주고 에러로 멈춘다.
- `/`가 포함되면 경로로 직접 해석한다: `aitask ~/work/arcana fix-login`

## 디렉터리 규칙

```
<root>/
  arcana/                    # canonical checkout — 항상 깨끗하게 유지
  arcana.wt/                 # disposable worktrees
    toss-review-fix/
    card-copy-revision/
```

worktree는 origin이 있으면 `origin/HEAD`(기본 브랜치 최신)에서 분기하고,
없으면 로컬 `HEAD`에서 분기한다. canonical checkout은 절대 건드리지 않는다
(`pull`/`checkout` 없음, `fetch`만 수행).

## 설정

- **루트 목록**: `~/.config/aitask/roots` — 한 줄에 하나. 파일이 없으면 기본값 `~/github`.
  `aitask root add`를 처음 실행하는 순간 기본값을 승계해서 파일이 생긴다.
- **환경변수**:
  | 변수 | 기본값 | 설명 |
  |---|---|---|
  | `AITASK_ROOTS_FILE` | `~/.config/aitask/roots` | 루트 목록 파일 경로 |
  | `AITASK_AGENT_CMD` | `claude` | 탭 왼쪽 pane에서 실행할 에이전트 명령 (codex 등으로 교체 가능) |

## done의 안전장치

- worktree에 커밋 안 된 변경이 있으면 중단하고 `git status`를 보여준다.
- canonical checkout이 dirty하면 중단한다 (리뷰 중인 상태를 머지로 덮지 않도록).
- 머지는 `--no-ff`라 task 단위 히스토리가 머지 커밋으로 남는다.

PR 리뷰를 거치고 싶으면 `done` 대신 worktree에서 `gh pr create`를 쓰고,
머지 후 `aitask drop`으로 정리하면 된다.

## 동작 세부

- cmux 제어는 전부 공식 socket CLI를 쓴다: `new-workspace --cwd --command`,
  `new-split`, `send`/`send-key`, `find-window`, `close-workspace`.
- 탭 이름은 `<repo>/<task>`로 고정하고, `done`/`drop`이 이 이름으로 탭을 찾아 닫는다.
  탭 이름을 손으로 바꾸면 자동으로 못 닫는다 (직접 닫으면 됨).
- `CLAUDE.local.md`는 base 레포의 `.git/info/exclude`에 자동 등록되어 커밋에 섞이지 않는다.
- git pane 초기 명령은 셸 기동 레이스를 피하려고 1초 지연 후 백그라운드로 주입한다.

## 같이 쓰면 좋은 것

- `cmux hooks setup --agent claude` — Claude 상태(작업 중/입력 대기)를 cmux 탭·피드에 표시.
  병렬 세션 여러 개 돌릴 때 사실상 필수.
- `cmux diff --source last-turn` — Claude가 방금 턴에 만든 diff를 pane으로 시각화.
