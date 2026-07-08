# dotfiles

개인 커스텀 툴/셸 설정 저장소.

## 구조

```
scripts/
  zsh/          # zshrc가 source하는 함수들 (*.zsh 전부 자동 로드)
  bin/          # PATH에 얹는 단독 실행 스크립트
install.sh      # ~/.zshrc에 로더 블록을 멱등하게 추가
```

## 설치

```sh
./install.sh
```

`~/.zshrc`에 `# >>> dotfiles >>>` 블록이 추가되어 `scripts/zsh/*.zsh`를 전부 source하고
`scripts/bin`을 PATH에 넣는다. 이미 설치돼 있으면 아무것도 하지 않는다.

## 툴

- **aitask** — git worktree + cmux 탭 + claude 세션을 task 단위로 만들고 정리하는 런처.
  `aitask <repo> <task>` / `aitask done <repo> <task>` / `aitask ls` / `aitask root add <path>`.
  자세한 사용법은 `aitask help`.
