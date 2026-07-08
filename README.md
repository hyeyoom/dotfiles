# dotfiles

개인 커스텀 툴/셸 설정 저장소.

## 구조

```
scripts/
  zsh/          # zshrc가 source하는 함수들 (*.zsh 전부 자동 로드)
  bin/          # PATH에 얹는 단독 실행 스크립트
install.sh      # ~/.zshrc에 로더 블록을 멱등하게 추가
```

각 툴의 문서는 같은 디렉터리에 같은 basename의 `.md`로 둔다 (예: `zsh/aitask.zsh` ↔ `zsh/aitask.md`).

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

## 툴

- **aitask** — git worktree + cmux 탭 + claude 세션을 task 단위로 만들고 정리하는 런처.
  `aitask <repo> <task>` / `aitask done <repo> <task>` / `aitask ls` / `aitask root add <path>`.
  자세한 사용법은 `aitask help`.
