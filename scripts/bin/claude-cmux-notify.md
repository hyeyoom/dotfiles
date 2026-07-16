# claude-cmux-notify

Claude Code 턴이 끝나면 macOS 알림을 띄우고, **배너를 클릭하면 그 이벤트가
발생한 cmux 워크스페이스로 점프**하는 훅 툴.

알림은 cmux 네이티브(`cmux notify`)로 보낸다. 배너 표시·클릭 점프·읽음 관리·
"지금 보고 있는 탭이면 배너 억제"까지 전부 cmux가 처리하므로, 여러 세션을
병렬로 돌릴 때 끝난 세션만 조용히 알려준다.

## 요구사항

- [cmux](https://cmux.com) — socket CLI 포함 버전
- **macOS 알림 권한**: 시스템 설정 > 알림 > cmux 허용 (머신당 1회 수동)
- python3 (`install`/`uninstall` 서브커맨드와 훅 JSON 파싱)
- terminal-notifier (선택) — cmux 밖에서 실행될 때의 폴백. 없으면 폴백 생략

## 사용법

```sh
claude-cmux-notify install     # ~/.claude/settings.json에 Stop 훅 등록
claude-cmux-notify uninstall   # 등록 해제
```

`install`은 편집 전에 `settings.json.bak-<timestamp>` 백업을 만들고,
command에 `terminal-notifier`/`claude-cmux-notify`가 들어간 기존 알림 훅
엔트리(Stop/Notification/PreToolUse/PostToolUse)를 제거한 뒤 Stop 훅 하나만
등록한다. 다른 훅과 설정 키는 건드리지 않는다. 재실행해도 중복 등록 없음(멱등).
새 Claude Code 세션부터 적용된다.

훅 모드(인자 없음)는 Claude가 넘겨주는 JSON을 stdin으로 받아 동작하므로
직접 호출할 일은 없다. 테스트하려면:

```sh
printf '{"hook_event_name":"Stop","cwd":"%s"}' "$PWD" | claude-cmux-notify
```

## 동작 세부

- 워크스페이스 식별은 세션 환경변수 `CMUX_WORKSPACE_ID`/`CMUX_SURFACE_ID`로
  한다 — 훅은 Claude 프로세스의 env를 상속하므로 별도 조회가 없다.
- 알림 내용: title `Claude Code`, subtitle은 작업 디렉터리 이름, body는
  Stop이면 "작업이 끝났습니다", 다른 이벤트면 훅 JSON의 `message`.
- **Stop만 등록하는 이유**: 입력 대기("Claude is waiting for your input")
  알림은 cmux의 Claude 래퍼 통합이 이미 네이티브로 만든다. 여기서 또 만들면
  배너가 두 개씩 뜬다.
- 훅 모드는 어떤 실패(파싱 실패, cmux 소켓 다운 등)에도 exit 0 —
  훅 체인을 막지 않는다. cmux를 못 쓰면 terminal-notifier 일반 배너로
  폴백한다 (점프 없음).
- 테스트용: env `CLAUDE_CMUX_NOTIFY_SETTINGS`로 settings.json 경로를
  오버라이드할 수 있다.

## 새 머신에서 환경 재현

```sh
git clone <이 레포> && cd dotfiles
./install.sh                   # zsh 툴 + 스킬 + PATH
scripts/bin/claude-cmux-notify install   # Claude 훅 등록
# 시스템 설정 > 알림 > cmux 허용 (1회)
```
