# 머신 프로필 계층 + aitask 추적 개선

날짜: 2026-08-05
상태: 승인됨 (분석 → 사용자 goal 지시로 확정)

## 1. 문제

세 가지 지적이 하나의 원인으로 수렴한다: **머신마다 다를 수 있는 것들이 전부
암묵적 관례로 결정되고, 변주를 표현할 데이터 계층이 없다.**

1. **머신 종속** — 회사 랩탑에서 위험한 동작:
   - `50-configs.sh` / `40-claude.sh`가 기존 `~/.gitconfig`, `~/.claude/settings.json`을
     무조건 `.bak`으로 밀고 개인 설정을 심링크한다. 회사가 관리하는 설정
     (강제 user.email, credential helper, 사내 Claude 정책)을 조용히 덮어씀.
   - `/opt/homebrew` 하드코딩 (Intel Mac에서 brew 미탐지).
2. **선택지 없음**:
   - `colonize.sh`가 bootstrap 전 단계를 무조건 실행. LazyVim·p10k가 필요 없는
     머신이라는 개념이 없음.
   - 유일한 opt-out인 `uninstall.sh <tool>`이 **추적 파일을 `.disabled`로 rename**
     → 그 머신에서 레포가 영구 dirty, `git pull` 충돌.
3. **aitask 추적 누락**:
   - 경로 인자로 만든 task(`aitask ~/work/foo fix`)는 생성은 되는데 루트 미등록이라
     `ls`/메뉴에 영영 안 보인다. 생성 성공 + 추적 조용한 실패의 비대칭.
   - 중첩 레포(`~/github/org/repo`)도 같은 이유로 이름 해석·추적 불가.

## 2. 결정 요약

| # | 결정 | 근거 |
|---|---|---|
| D1 | 머신 로컬 프로필 파일 `~/.config/dotfiles/profile` (POSIX sh, 레포 밖) | 머신별 상태를 레포 밖으로. 없으면 지금과 동일(전부 설치) |
| D2 | `DOTFILES_SKIP_STEPS` — bootstrap 단계 스킵 | colonize에 선택지 부여 |
| D3 | `DOTFILES_SKIP_LINKS` — `p10k gitconfig claude` 심링크 생략, 기존 파일 불가침 | 회사 관리 설정 보호 |
| D4 | `DOTFILES_DISABLED_TOOLS` — zsh 툴/스킬 비활성화. `.disabled` rename 폐지 | 레포 dirty 문제 제거 |
| D5 | zshrc 로더 블록 v2: profile을 source하고 DISABLED를 건너뜀. `install.sh`가 기존 블록을 내용 비교 후 자동 교체 | 블록 업그레이드 경로 확보 (일회성 아님) |
| D6 | brew prefix를 `/opt/homebrew` → `/usr/local` 순 탐지 | Intel Mac |
| D7 | aitask: 경로로 repo를 해석할 때 부모 디렉터리를 roots에 **자동 등록** (stderr 안내) | 생성/추적 비대칭 제거. 중첩 레포도 경로로 열면 그 시점부터 추적됨 |
| D8 | `colonize.sh --check`가 profile을 반영해 스킵 항목을 실패가 아닌 `(skip)`으로 표시 | 회사 랩탑에서 --check가 항상 빨간불이 되는 것 방지 |

## 3. 프로필 파일 명세

위치: `~/.config/dotfiles/profile`. 템플릿: `config/dotfiles-profile.example`.
형식: POSIX sh 변수 할당만 (sh와 zsh 양쪽에서 source됨).

```sh
DOTFILES_SKIP_STEPS=""     # bootstrap 단계. "30-runtimes" 또는 번호 없이 "runtimes"
DOTFILES_SKIP_LINKS=""     # p10k | gitconfig | claude — 심링크 안 하고 기존 파일 유지
DOTFILES_DISABLED_TOOLS="" # zsh 툴/스킬 이름. install.sh/uninstall.sh <tool>이 관리
```

- 파일이 없으면 모든 변수는 빈 값 = 현재 동작 그대로 (기존 사용자 무영향).
- colonize는 시작 시 profile 부재를 안내만 한다 (자동 생성하지 않음 — 개인
  머신에서 파일이 생기는 노이즈 방지). 회사 랩탑 절차는 README에 명시:
  clone → profile 작성 → colonize.
- `DOTFILES_DISABLED_TOOLS` 줄은 installer가 sed로 편집하므로
  `DOTFILES_DISABLED_TOOLS="..."` 한 줄 형식을 유지해야 한다 (템플릿에 명시).

## 4. 컴포넌트별 설계

### colonize.sh
- profile을 source한 뒤 각 `bootstrap/[0-9]*.sh`에 대해 basename(`30-runtimes`)
  또는 축약명(`runtimes`)이 `DOTFILES_SKIP_STEPS`에 있으면 `==> ... (skip)` 출력 후 건너뜀.

### bootstrap/40-claude.sh, 50-configs.sh
- 각자 profile을 source (colonize 경유가 아닌 단독 실행도 동일 동작).
- `DOTFILES_SKIP_LINKS`에 `claude`/`gitconfig`/`p10k`가 있으면 해당 심링크
  단계를 통째로 생략 — **기존 파일을 `.bak`으로 옮기지도 않는다**.
- 시크릿 unseal/seed는 유지 (없을 때만 생성이라 원래 불가침).

### zshrc 로더 블록 v2 + install.sh
```zsh
# >>> dotfiles >>>
export DOTFILES="<repo path>"
[ -f "$HOME/.config/dotfiles/profile" ] && source "$HOME/.config/dotfiles/profile"
for f in "$DOTFILES"/scripts/zsh/*.zsh(N); do
  case " ${DOTFILES_DISABLED_TOOLS:-} " in
    (*" ${${f:t}%.zsh} "*) ;;
    (*) source "$f" ;;
  esac
done
export PATH="$DOTFILES/scripts/bin:$PATH"
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
# <<< dotfiles <<<
```
- install.sh는 원하는 블록을 생성해 기존 블록과 **내용 비교** — 다르면
  `~/.zshrc.bak` 백업 후 마커 사이를 교체. 같으면 no-op. 이제 로더 개선이
  재실행만으로 배포된다.
- 레거시 마이그레이션: `*.zsh.disabled` 발견 시 원래 이름으로 되돌리고 그
  이름을 profile의 DISABLED에 추가 (의미 보존 + 레포 청소). bin `.disabled`는
  되돌리기만 하고 경고 (bin은 profile 비활성화 미지원 — PATH가 디렉터리 단위).

### install.sh <tool> / uninstall.sh <tool>
- rename 대신 profile의 `DOTFILES_DISABLED_TOOLS` 목록을 편집.
- uninstall: 목록에 추가 + 스킬 심링크 제거. install: 목록에서 제거 + 스킬 재링크.
- 대상 존재 검증은 유지 (`scripts/zsh/<name>.zsh` 또는 `skills/<name>`).

### bootstrap/check.sh
- profile source 후: 스킵된 단계의 섹션(runtimes 등), 스킵된 링크, 비활성 툴을
  `- <name> (skip)`으로 표시하고 실패로 세지 않음.

### brew prefix (10-brew.sh, 00-omz.zsh, path.zsh)
- `/opt/homebrew/bin/brew` → `/usr/local/bin/brew` 순서로 탐지해 shellenv.
- path.zsh의 qemu 경로는 shellenv가 export하는 `HOMEBREW_PREFIX` 사용.

### aitask 루트 자동 등록 (aitask.zsh)
- `_aitask_base`의 경로 분기에서 레포 검증 후 `${p:h}`가 roots에 없으면
  roots 파일에 추가하고 stderr로 안내 (`aitask: root 자동 등록: ...`).
- `root add`와 동일하게 첫 기록 시 암묵 기본값(~/github)을 승계.
- done/drop/multi 등 `_aitask_base`를 쓰는 모든 경로에 일괄 적용 — 등록은
  ls 표시 범위를 넓힐 뿐이라 부작용 없음.

## 5. 거부한 대안

- **Brewfile core/optional 분리** — 패키지 8개 규모에서 과설계. `10-brew` 단계
  스킵으로 충분. 커지면 재검토.
- **aitask 생성 레지스트리 파일** — glob 관례와 이중 장부가 되어 drift 위험.
  루트 자동 등록이 같은 문제를 상태 추가 없이 해결.
- **roots 파일의 dotfiles 편입** — 루트는 본질적으로 머신마다 다르다.
  머신 로컬 유지, README에 명시.
- **profile 자동 생성** — 개인 머신 노이즈. 템플릿 + 문서로 대체.

## 6. 검증 기준

- fixture HOME에서: install.sh 블록 생성/멱등/v1→v2 자동 교체, uninstall→profile
  기록→로더가 해당 툴 스킵, install <tool>→복원.
- fixture HOME에서: `DOTFILES_SKIP_LINKS=gitconfig`로 50-configs 실행 시 기존
  `~/.gitconfig`이 그대로 남고 `.bak`도 생기지 않음.
- 가짜 bootstrap 디렉터리로 colonize 스킵 로직 (전체 이름/축약명 모두).
- aitask fixture: 루트 밖 경로로 new → roots에 자동 등록 + `ls`에 표시.
- 기존 사용자(프로필 없음) 경로: 모든 스크립트가 현재와 동일 동작.
