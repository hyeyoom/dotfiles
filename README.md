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

## 머신 프로필 (회사 랩탑 등)

머신마다 설치·로드 범위를 다르게 하려면 **colonize 전에**
`~/.config/dotfiles/profile`을 만든다 (없으면 전부 설치 — 개인 머신 기본값):

```sh
mkdir -p ~/.config/dotfiles && cp config/dotfiles-profile.example ~/.config/dotfiles/profile
```

| 변수 | 예 | 효과 |
|---|---|---|
| `DOTFILES_SKIP_STEPS` | `"runtimes claude"` | 해당 bootstrap 단계 통째로 건너뜀 |
| `DOTFILES_SKIP_LINKS` | `"gitconfig claude"` | 해당 심링크 생략 — **머신의 기존 파일 불가침** (.bak도 안 만듦) |
| `DOTFILES_DISABLED_TOOLS` | `"aitask"` | zsh 툴/스킬 로드 제외 (`uninstall.sh <tool>`이 이 줄을 관리) |

회사가 `~/.gitconfig`이나 `~/.claude/settings.json`을 관리하는 머신에서는
`DOTFILES_SKIP_LINKS`에 넣어두면 colonize가 절대 건드리지 않는다.
`colonize.sh --check`도 프로필을 읽어 스킵 항목을 실패가 아닌 `(skip)`으로 표시한다.

## 구조

```
colonize.sh     # 진입점: bootstrap/*.sh 순서 실행 후 install.sh 호출
bootstrap/
  10-brew.sh    # Homebrew + Brewfile 패키지
  20-zsh.sh     # oh-my-zsh + powerlevel10k + 플러그인
  30-runtimes.sh # nvm, rustup, LazyVim(nvim 설정) (jenv는 Brewfile)
  40-claude.sh  # claude CLI + settings.json/CLAUDE.md/output-styles 심링크 + CLAUDE.local.md 템플릿
  50-configs.sh # p10k/gitconfig 심링크, secrets 복호화 or ~/.*.local 템플릿 생성
  check.sh      # --check 구현
  seal.sh       # --seal 구현 (시크릿 GPG 암호화)
  reveal.sh     # --reveal 구현 (복호화해 콘솔 출력, 검증용)
Brewfile        # CLI 툴 선언 (bat, fzf, gh, jenv, neovim, ...)
config/         # 심링크되는 공용 설정 (p10k, gitconfig, claude) + *.local.example
                # claude/: settings.json, CLAUDE.md, output-styles/, CLAUDE.local.md.example
                # + dotfiles-profile.example (머신 프로필 템플릿)
secrets/        # GPG 암호화된 ~/.*.local (내 GPG 개인키로만 복호화 가능)
scripts/
  zsh/          # zshrc가 source하는 조각들 (*.zsh 전부 자동 로드, 알파벳순)
  bin/          # PATH에 얹는 단독 실행 스크립트
skills/         # Claude Code 스킬 (~/.claude/skills로 심링크 설치): tldr, verification-before-completion
install.sh      # ~/.zshrc에 로더 블록 추가 + 스킬 심링크 (멱등)
```

각 툴의 문서는 같은 디렉터리에 같은 basename의 `.md`로 둔다 (예: `zsh/aitask.zsh` ↔ `zsh/aitask.md`).

## 시크릿 정책

API 키, 토큰, SSH 접속 정보, git 신원 등 개인정보는 레포에 평문으로 절대 넣지 않는다.
홈 디렉터리의 `~/.zshrc.local`, `~/.gitconfig.local`, `~/.claude/CLAUDE.local.md`에만 두며(로더/include/임포트가 자동 로드),
`.gitignore`가 `*.local`을 막고 `colonize.sh --check`가 추적 파일에서 키 패턴을 스캔한다.
레포에는 GPG 공개키로 암호화한 사본(`secrets/*.asc`)만 올린다 — 새 머신 이동은
GPG 개인키 하나만 옮기면 끝난다 (`--seal`로 갱신, colonize가 자동 복호화).

## 설치 / 제거

```sh
./install.sh              # ~/.zshrc에 로더 블록 추가 (멱등)
./uninstall.sh            # 로더 블록 제거 (백업: ~/.zshrc.bak, 레포 파일은 유지)

./uninstall.sh aitask     # 특정 툴만 비활성화 (~/.config/dotfiles/profile에 기록 — 레포는 그대로)
./install.sh aitask       # 다시 활성화
```

`~/.zshrc`에 `# >>> dotfiles >>>` 블록이 추가되어 `scripts/zsh/*.zsh`를
(프로필의 `DOTFILES_DISABLED_TOOLS` 제외) source하고 `scripts/bin`을 PATH에 넣는다.
로더 블록이 구버전이면 재실행 시 `~/.zshrc.bak` 백업 후 자동 교체된다.
새 툴은 파일만 추가하면 다음 셸부터 자동 로드된다 (재설치 불필요).

스킬은 `~/.claude/skills/<name>` 심링크로 설치되어 레포 수정이 즉시 반영된다.
`uninstall.sh <name>` / `install.sh <name>`으로 스킬도 zsh 툴처럼 on/off 된다.

## 툴

- **aitask** — git worktree + cmux 탭 + claude 세션을 task 단위로 만들고 정리하는 런처.
  인자 없이 `aitask`를 치면 fzf 메뉴(탭 이동 / PR 생성 / drop / 새 task).
  `aitask <repo> <task>` / `aitask ls` / `aitask drop <repo> <task>` 커맨드도 그대로.
  자세한 사용법은 `aitask help`.
- **claude-cmux-notify** — Claude Code 턴 종료 시 macOS 알림, 클릭하면 해당
  cmux 워크스페이스로 점프. `claude-cmux-notify install`로 훅 등록.
  자세한 내용은 `scripts/bin/claude-cmux-notify.md`.

## Claude Code 설정

`config/claude/`의 `settings.json`, `CLAUDE.md`, `output-styles/`는 `40-claude.sh`가
`~/.claude`로 심링크하고, `skills/`는 `install.sh`가 심링크한다. 레포 수정은 다음 Claude 세션부터 반영된다.

- **CLAUDE.md** — 모델 라우팅 지침 + 코딩 행동 지침 4개(가정 먼저 말하기, 단순하게,
  요청한 곳만, 검증 후 완료 선언). §4 끝이 `verification-before-completion` 스킬을 호출한다.
- **output-styles/compact.md** — "Compact" 스타일 (결론 먼저, 개조식, 자연스러운 한국어).
  `settings.json`의 `"outputStyle": "Compact"`로 켜짐. 끄려면 `/config` → Output style → Default.
  [attention-span](https://github.com/alexgreensh/attention-span)(AGPL-3.0) Spartan 기반.
- **skills/tldr** — 슬랙 스레드·노션·로그를 "내가 해야 할 일" 중심 브리핑으로 압축 (attention-span `/tldr` 기반).
- **skills/verification-before-completion** — 완료 선언 전 증명 명령을 직접 돌리는 게이트 (obra/superpowers 기반).

개인 정보(이름, 슬랙 표시명)는 레포에 넣지 않고 `~/.claude/CLAUDE.local.md`에 둔다.
`CLAUDE.md`가 `@~/.claude/CLAUDE.local.md`로 임포트하고, colonize가
`config/claude/CLAUDE.local.md.example`에서 시드한다. tldr 스킬의 "내가 할 일" 기준 이름이 여기서 온다.
