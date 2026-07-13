# dotfiles

개인 커스텀 툴/셸 설정 저장소. 새 macOS 머신에서 한 번에 전체 환경을 재현한다.

## 새 머신 셋업

```sh
git clone https://github.com/hyeyoom/dotfiles.git ~/github/dotfiles
cd ~/github/dotfiles
./colonize.sh             # brew + zsh 환경 + 런타임 + claude + 설정 전부 설치 (멱등)
./colonize.sh --check     # 설치 없이 항목별 상태 점검 + 레포 시크릿 스캔
```

시크릿(`~/.zshrc.local`, `~/.gitconfig.local`)은 GPG 개인키를 먼저 import해 두면
colonize가 `secrets/*.asc`에서 자동 복호화한다. 키가 없으면 빈 템플릿이 생기니
직접 채우면 된다. 시크릿을 수정했으면 `./colonize.sh --seal`로 다시 암호화해 커밋.

## 구조

```
colonize.sh     # 진입점: bootstrap/*.sh 순서 실행 후 install.sh 호출
bootstrap/
  10-brew.sh    # Homebrew + Brewfile 패키지
  20-zsh.sh     # oh-my-zsh + powerlevel10k + 플러그인
  30-runtimes.sh # nvm, rustup, LazyVim(nvim 설정) (jenv는 Brewfile)
  40-claude.sh  # claude CLI + settings.json 심링크
  50-configs.sh # p10k/gitconfig 심링크, secrets 복호화 or ~/.*.local 템플릿 생성
  check.sh      # --check 구현
  seal.sh       # --seal 구현 (시크릿 GPG 암호화)
Brewfile        # CLI 툴 선언 (bat, fzf, gh, jenv, neovim, ...)
config/         # 심링크되는 공용 설정 (p10k, gitconfig, claude) + *.local.example
secrets/        # GPG 암호화된 ~/.*.local (내 GPG 개인키로만 복호화 가능)
scripts/
  zsh/          # zshrc가 source하는 조각들 (*.zsh 전부 자동 로드, 알파벳순)
  bin/          # PATH에 얹는 단독 실행 스크립트
skills/         # Claude Code 스킬 (~/.claude/skills로 심링크 설치)
install.sh      # ~/.zshrc에 로더 블록 추가 + 스킬 심링크 (멱등)
```

각 툴의 문서는 같은 디렉터리에 같은 basename의 `.md`로 둔다 (예: `zsh/aitask.zsh` ↔ `zsh/aitask.md`).

## 시크릿 정책

API 키, 토큰, SSH 접속 정보, git 신원 등 개인정보는 레포에 평문으로 절대 넣지 않는다.
홈 디렉터리의 `~/.zshrc.local`, `~/.gitconfig.local`에만 두며(로더/include가 자동 로드),
`.gitignore`가 `*.local`을 막고 `colonize.sh --check`가 추적 파일에서 키 패턴을 스캔한다.
레포에는 GPG 공개키로 암호화한 사본(`secrets/*.asc`)만 올린다 — 새 머신 이동은
GPG 개인키 하나만 옮기면 끝난다 (`--seal`로 갱신, colonize가 자동 복호화).

## 설치 / 제거

```sh
./install.sh              # ~/.zshrc에 로더 블록 추가 (멱등)
./uninstall.sh            # 로더 블록 제거 (백업: ~/.zshrc.bak, 레포 파일은 유지)

./uninstall.sh aitask     # 특정 툴만 비활성화 (*.zsh → *.zsh.disabled rename)
./install.sh aitask       # 다시 활성화
```

`~/.zshrc`에 `# >>> dotfiles >>>` 블록이 추가되어 `scripts/zsh/*.zsh`를 전부 source하고
`scripts/bin`을 PATH에 넣는다. 이미 설치돼 있으면 아무것도 하지 않는다.
새 툴은 파일만 추가하면 다음 셸부터 자동 로드된다 (재설치 불필요).

스킬은 `~/.claude/skills/<name>` 심링크로 설치되어 레포 수정이 즉시 반영된다.
`uninstall.sh <name>` / `install.sh <name>`으로 스킬도 zsh 툴처럼 on/off 된다.

## 툴

- **aitask** — git worktree + cmux 탭 + claude 세션을 task 단위로 만들고 정리하는 런처.
  `aitask <repo> <task>` / `aitask done <repo> <task>` / `aitask ls` / `aitask root add <path>`.
  자세한 사용법은 `aitask help`.
- **fe-dev** (skill) — 백엔드 개발자용 FE 작업 워크플로.
  레포 스타일 파악(`.claude/fe-style.md` 영속화) → superpowers 위임 작업(부재 시
  내장 fallback) → playwright/curl 증거 기반 검증 루프. FE 레포 작업 시 자동 트리거.
