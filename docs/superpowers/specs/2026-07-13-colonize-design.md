# colonize.sh — 새 머신 원커맨드 부트스트랩 설계

날짜: 2026-07-13
상태: 승인됨

## 목표

새 macOS 머신에서 `git clone && ./colonize.sh` 한 번으로 전체 개발 환경을 재현한다:
brew + CLI 툴, zsh 환경(oh-my-zsh/p10k/플러그인), 런타임(jenv/nvm/rust), Claude Code,
개인 alias/설정. 멱등하며 몇 번을 재실행해도 안전하다.

**1급 원칙: 개인정보/시크릿은 레포에 절대 들어가지 않는다.**

## 범위

- 플랫폼: macOS 전용
- 레포가 소스오브트루스: zshrc 내용을 레포로 이주, `~/.zshrc`는 얇게
- Claude Code: CLI 설치 + `~/.claude/settings.json` 심링크 (플러그인은 안내만)

## 구조

```
dotfiles/
  colonize.sh          # 진입점: bootstrap/*.sh 순서 실행. --check 모드 지원
  bootstrap/
    10-brew.sh         # Homebrew 설치 → brew bundle
    20-zsh.sh          # oh-my-zsh + powerlevel10k + 플러그인 3종 (git clone)
    30-runtimes.sh     # nvm(git clone), rustup. jenv는 Brewfile
    40-claude.sh       # claude CLI 공식 인스톨러 + settings.json 심링크
    50-configs.sh      # p10k/gitconfig 심링크, *.local 템플릿 생성
  Brewfile             # bat, neovim, fzf, gh, jenv, gnupg, terminal-notifier ...
  config/
    p10k.zsh           # ~/.p10k.zsh → 심링크
    gitconfig          # ~/.gitconfig → 심링크 (공용 설정만 + include .local)
    zshrc.local.example
    gitconfig.local.example
    claude/settings.json  # ~/.claude/settings.json → 심링크
  scripts/zsh/         # (기존) + 00-omz.zsh, aliases.zsh, path.zsh 추가
  install.sh           # (기존) 로더 블록에 ~/.zshrc.local source 추가
```

colonize.sh 마지막 단계에서 기존 `install.sh`를 호출해 zshrc 로더 블록과
스킬 심링크를 연결한다.

## zshrc 이주

기존 `~/.zshrc` 내용을 용도별로 `scripts/zsh/*.zsh`로 분해 (로더가 알파벳순 로드):

- `00-omz.zsh` — p10k instant prompt, omz/테마/플러그인 로드, compinit, zstyle, p10k.zsh source
- `aliases.zsh` — cat=bat, vim=nvim, python=python3, cls, finhi, tm 등 공용 alias
- `path.zsh` — jenv, nvm, cargo, Android SDK, JAVA_HOME, bun 등 PATH/환경변수
  (머신 고유 경로는 존재 체크 가드)

이주 후 `~/.zshrc` = p10k instant prompt 주의사항 없이 로더 블록만 남는 얇은 파일.
기존 파일은 `~/.zshrc.pre-colonize.bak`으로 백업.

중복 제거: brew 경로의 zsh-syntax-highlighting 직접 source는 omz 플러그인과
중복이므로 제거 (omz 플러그인만 유지).

## 시크릿/개인정보 분리 (1급 원칙)

레포에 절대 넣지 않는 것: API 키·토큰, SSH 접속 정보(호스트/pem), 이메일 등 식별 정보.

- `~/.zshrc.local` — NOTION_API_KEY 등 env, SSH alias(moimAlpha 등), 머신 고유 설정.
  로더 블록 마지막에 존재 시 source. 없으면 colonize가 example 템플릿 복사.
- `~/.gitconfig.local` — `[user]` name/email/signingkey/password, `[commit] gpgsign`.
  레포 `config/gitconfig`는 credential helper, core, gpg program, `[include]`만 포함.
- Claude `settings.json`은 감사 결과 시크릿 없음 → 심링크 가능.
- 안전망:
  - `.gitignore`에 `*.local` 명시
  - `colonize.sh --check`에 시크릿 스캔 포함: 레포 추적 파일에서
    `ghp_|ntn_|sk-|api[_-]?key\s*=|password\s*=|BEGIN.*PRIVATE` 패턴 grep → 경고
- 이주 시 현재 zshrc/gitconfig의 시크릿 라인은 각 `.local` 파일로만 이동.

## 에러 처리 / 검증

- `set -eu`, 단계별 시작/완료 로그. 실패 시 어느 단계인지 출력 후 중단.
- 모든 단계 멱등: 설치돼 있으면 skip, 심링크는 `ln -sfn`, 기존 실파일은 `.bak` 백업.
- `colonize.sh --check`: 설치 없이 항목별 ✓/✗ 상태 + 시크릿 스캔.
- 완료 검증: `--check` 전항목 ✓, `zsh -ic` 스모크 테스트(alias/PATH/프롬프트),
  git 커밋 서명 동작 확인.

## 비범위

- Linux 지원, JDK/Android SDK 자체 설치(경로 가드만), Claude 플러그인 자동 설치(안내만),
  conda(현재 주석 처리 상태 유지 → 이주 대상 아님), qemu 버전 고정 경로(가드 처리)
