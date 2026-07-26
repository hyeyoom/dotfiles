# aitask v2 설계 — drop 안전장치 + 상태 표시 + fzf 메뉴

`aitask`를 실제 운영 패턴("worktree로 병렬 세션 격리, 통합은 PR, 정리는 drop")에
맞게 보강한다. 핵심: drop이 유일한 정리 경로인데 안전장치가 없던 것을 고치고,
명령어 타이핑 대신 fzf 메뉴로 조작할 수 있게 한다.

## 결정 사항 (브레인스토밍 결과)

| 항목 | 결정 | 근거 |
|---|---|---|
| 메뉴 진입 | `aitask` 인자 없이 실행 = 메뉴. help는 `aitask help`로 이동 | 타이핑 최소화. 기존 no-arg는 help였으므로 잃는 기능 없음 |
| 메뉴 방식 | fzf 2단계: task 선택 → 액션 선택. `--preview`로 git status/log 표시 | 발견 가능성·실수 방지 우선. fzf 0.74 설치 확인됨 |
| 메뉴 액션 | 탭 이동 / PR 생성 / drop / 새 task | 사용자 선택 (전부) |
| 상태 정보 | 로컬 git(dirty·ahead/behind·upstream·머지 여부) + repo당 `gh pr list` 1회 | 네트워크 실패 시 로컬 정보만으로 동작 (best-effort) |
| `done` | 현행 유지, 메뉴에는 미노출 | origin 없는 로컬 레포에서 여전히 유용 |
| task 이름 | `[A-Za-z0-9._-]+`만 허용, `/`·공백·`..` 거부 | `features/TASK-123`식 이름이 중첩 worktree를 만들어 ls에 안 보이고 drop 이름 불일치를 일으키던 버그의 근본 원인 제거 |

## 실측으로 확인된 기존 버그 (이번에 수정)

1. **`find-window`는 substring 매칭** — `arcana/fix` 탭을 닫으려다
   `arcana/fix-login` 탭이 걸릴 수 있다. 정확 타이틀 비교로 교체.
2. **"No matches"가 stdout으로 나옴** — `_aitask_close_tab`이 `ws="No"`로
   `close-workspace --workspace No`를 호출한다 (에러가 /dev/null로 숨겨져
   무해했을 뿐). 출력 파싱을 방어적으로 교체.
3. **`new` 재실행 시 cmux 탭 중복 생성** + `CLAUDE.local.md` 무조건 덮어쓰기.
4. **슬래시 포함 task 이름** — worktree가 중첩 경로에 생겨 `ls`(1단계 glob)에
   안 보이고, drop 시 정확한 이름을 기억해야만 지워짐.

## 1. 파일 구성

```
scripts/zsh/aitask.zsh   # 수정 (단일 파일 유지)
scripts/zsh/aitask.md    # 문서 갱신
```

새 의존성: fzf(메뉴에만 필요 — 없으면 메뉴 진입 시 안내 후 종료),
gh(PR 상태·PR 생성에만 필요 — 없으면 해당 기능만 생략). 기존 커맨드 경로는
fzf/gh 없이도 전부 동작한다.

## 2. task 이름 검증 — `_aitask_valid_task`

- 허용: `^[A-Za-z0-9][A-Za-z0-9._-]*$` (선두는 영숫자 — `.`·`..`·`-x` 차단)
- `_aitask_new` 진입 시 검사, 위반 시 규칙을 보여주는 에러로 즉시 중단.
- 티켓 기반 이름은 `TASK-123` 또는 `TASK-123-fix-login` 형태를 쓴다.
  브랜치는 기존대로 `task/<이름>`이라 `features/` 접두사는 불필요.
- 기존에 만들어진 중첩 worktree는 마이그레이션하지 않는다 (경로를 알면
  `aitask drop`이 여전히 동작하고, 새로 만드는 것만 막으면 됨).

## 3. cmux 탭 헬퍼 — 정확 매칭

- `_aitask_find_ws <title>`: `find-window` 출력에서 각 행의 따옴표 안 타이틀을
  추출, 선두 상태 아이콘(`⠂`/`✳` 등 + 공백)을 제거한 뒤 `<title>`과 **정확
  일치**하는 첫 행의 `workspace:<n>` ref만 반환. "No matches" 행은 ref 패턴
  (`workspace:`)이 아니므로 자연 탈락.
- `_aitask_close_tab`은 이 헬퍼를 사용.
- `_aitask_new`: 탭 생성 전 `_aitask_find_ws "$name/$task"` 확인 —
  있으면 `select-workspace`로 포커스만 하고 "already open" 안내 후 종료.
- `CLAUDE.local.md`는 **없을 때만** 생성 (사용자 편집 보존).

## 4. 상태 수집 — `_aitask_status`

worktree 하나에 대해 탭 구분 한 줄을 출력한다:

```
repo<TAB>task<TAB>wt경로<TAB>branch<TAB>dirty<TAB>ahead<TAB>behind<TAB>upstream<TAB>merged
```

- dirty: `git status --porcelain` 비어있지 않음
- upstream: `git rev-parse --abbrev-ref @{u}` 성공 여부
- ahead/behind: upstream 있으면 `git rev-list --left-right --count @{u}...HEAD`
- merged: `git merge-base --is-ancestor HEAD <origin기본브랜치>` (origin 없으면 공란)
- PR 상태는 여기서가 아니라 **repo당 1회** `gh pr list --state all --limit 100
  --json headRefName,state,url`로 모아 브랜치명으로 join한다.
  `gh`는 5초 timeout, 실패/부재 시 PR 컬럼 생략. 캐시는 두지 않는다 (YAGNI).

`ls`와 메뉴가 이 함수를 공유한다. `ls`는 사람이 읽는 정렬된 컬럼으로 포맷:

```
arcana   toss-review-fix   task/toss-review-fix   *dirty ↑2        PR#41 open
arcana   card-copy         task/card-copy         merged           PR#39 merged
```

## 5. drop 안전장치

drop 확인 전에 상태 요약을 보여준다:

```
aitask: arcana/toss-review-fix (task/toss-review-fix)
  uncommitted: 3 files
  unpushed:    2 commits (no upstream)
  merged into origin/main: no
  PR: none
```

- **안전** (merged, 또는 upstream 있고 ahead=0이며 clean): 기존처럼 `[y/N]`.
- **위험** (dirty이거나 unpushed 커밋 존재): task 이름을 그대로 타이핑해야
  진행되는 강한 확인. `[y/N]`보다 오조작 비용을 높인다.
- drop/done 후 비게 된 `<repo>.wt/` 디렉터리는 `rmdir`로 정리 (비어있을 때만).

unpushed 판정: upstream이 있으면 ahead 커밋 수, 없으면 분기점
(`origin/HEAD` 또는 로컬 HEAD) 이후 커밋 수.

## 6. fzf 메뉴 — `aitask` (인자 없음)

1. 모든 root의 task를 `_aitask_status`로 수집. 첫 행에 `[+ new task]` 고정.
2. fzf 표시: `repo/task  branch  상태플래그  PR` (wt 경로는 숨김 필드,
   `--delimiter '\t' --with-nth` 사용). preview 창은 오른쪽에
   `git -C {wt} status --short --branch && git log --oneline -8`
   (fzf preview는 셸 함수를 못 부르므로 인라인 git 명령으로 구성).
3. task 선택 → 액션 fzf:
   - **탭으로 이동** — `_aitask_find_ws`로 찾아 `select-workspace`.
     탭이 없으면(닫았던 경우) `new`와 동일한 방식으로 탭 재생성.
   - **PR 생성** — worktree에서 `git push -u origin <branch>` 후
     `gh pr create --web`. 커밋이 없으면 안내만 하고 중단.
   - **drop** — §5의 안전장치 포함 drop 실행.
   - **취소**
4. `[+ new task]` → repo fzf(모든 root의 git 레포 스캔) → task 이름 `read`
   (검증 실패 시 재입력) → `_aitask_new`.
5. task가 하나도 없으면 바로 repo 선택(새 task 생성 흐름)으로 진입.
6. fzf 부재 시: 안내 메시지 + `aitask help` 출력.

## 7. 에러 처리 원칙

- gh/네트워크: 항상 best-effort. 느리거나 실패해도 메뉴·ls는 로컬 정보로 동작.
- git 조작(worktree add/remove, branch -D, push): 실패 시 즉시 중단하고
  git의 에러를 그대로 노출.
- cmux 조작: 실패해도 git 상태는 이미 정합적이므로 경고만 하고 진행.

## 7.5 브랜치 접두사 (2026-07-26 추가)

팀 브랜치 네이밍 컨벤션(`features/…`, `hotfix/…`) 요구로 추가. task 이름
검증(§2)은 유지하고, 접두사를 별도 인자로 받는다:

- `aitask new <repo> <task> [prefix]` — branch는 `<prefix>/<task>`,
  worktree는 여전히 `<repo>.wt/<task>` (평평함 유지 — §2의 버그 재발 방지).
- 기본값 `AITASK_BRANCH_PREFIX=task`, 메뉴 선택지 `AITASK_BRANCH_PREFIXES`
  (기본: task features hotfix bugfix release chore). 접두사도 단일 레벨
  슬러그만 허용.
- `done`/`drop`은 `task/<이름>` 가정을 버리고 worktree의 실제 브랜치를
  조회(`git branch --show-current`)해서 머지/삭제한다. `new` 재실행 시
  기존 worktree의 브랜치가 우선한다 (접두사 인자 무시).

## 7.6 커스텀 탭 제목 (2026-07-26 추가)

에픽/피처 이름을 cmux 탭에 표시하고 싶다는 요구. 탭 추적을 깨지 않는 것이
제약: 탭 타이틀은 `<repo>/<task> · <제목>` 형식으로 고정하고,
`_aitask_find_ws`의 매칭을 "정확 일치 또는 `<repo>/<task> · ` 접두"로
확장한다. 제목 미지정 시 기존과 동일. CLI는 4번째 인자
(`aitask new <repo> <task> [prefix|-] [제목]`, `-`는 기본 접두사 유지),
메뉴는 접두사 선택 뒤 제목 프롬프트(엔터=생략). 제목의 `"`는 find-window
출력 파싱을 깨므로 제거한다.

## 7.7 멀티 레포 티켓 (2026-07-27 추가)

티켓 하나가 여러 레포에 걸치고 AI 세션 하나가 전부를 봐야 하는 요구.
우산(umbrella) 방식 채택: `<primary root>/multi.wt/<task>/` 안에 멤버
레포별 worktree를 배치하고, cmux 탭·claude를 우산 cwd로 띄운다.

- CLI: `aitask multi <task> <repo>... [-p prefix] [-t 탭제목]`.
  메뉴: repo 선택 fzf가 `--multi` — 2개 이상 선택 시 자동으로 multi 흐름.
- 매니페스트 `.aitask-repos`(멤버 base 경로)로 done/drop/ls/PR이 멤버를 추적.
  우산은 git repo가 아니므로 CLAUDE.local.md에 구조 안내를 자동 생성.
- 탭 이름 `multi/<task>`(제목 접미 규칙 동일). 상태 수집은
  `_aitask_wt_fields`로 단일/멀티가 공유하도록 리팩터링.
- PR: 멤버 순회, 변경 있는 레포만 push + pr create (티켓 1 = PR N).
- drop: 멤버별 요약, 하나라도 dirty/unpushed면 이름 타이핑 확인.
- done 미지원 (부분 머지 상태 위험 — PR 워크플로우 전용).
- 레포가 `multi`라는 이름이면 우산 디렉터리와 충돌 가능 — 매니페스트
  파일 유무로 구분하므로 실동작은 안전, 문서화만 해둠.

부수 개선: 메뉴의 repo 선택 리스트를 full path 대신
`이름  <루트(~축약)>` 2컬럼으로 표시 (경로는 숨김 필드).

## 8. 검증

자동 테스트 관례가 없는 레포이므로, 임시 디렉터리에 origin 포함 git fixture를
만들어 비대화형 경로를 실제 실행으로 확인한다:

- 슬러그 검증: `features/x`·`..`·공백 거부, `TASK-123` 허용
- `_aitask_status`: dirty/ahead/merged 각 상태의 fixture에서 필드 값 확인
- drop 안전장치: 위험 상태에서 이름 불일치 입력 시 중단, 일치 시 삭제
- `new` 멱등: 두 번 실행 시 worktree·CLAUDE.local.md·탭이 하나씩만
- 메뉴·cmux 흐름: 수동 확인 (탭 이동, PR 생성, preview)
