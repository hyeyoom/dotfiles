# claude-cmux-notify 설계

Claude Code 훅이 턴 종료 시 macOS 알림을 띄우고, 클릭하면 해당 이벤트가 발생한
cmux 워크스페이스로 점프하는 툴. dotfiles `scripts/bin/`에 배포한다.

## 결정 사항 (브레인스토밍 결과)

| 항목 | 결정 | 근거 |
|---|---|---|
| 알림 경로 | cmux 네이티브 `cmux notify` | 실측: 배너 표시 + 클릭 시 워크스페이스 점프 확인됨 (2026-07-16). 읽음 관리·포커스 중 억제도 cmux가 처리 |
| 훅 이벤트 | **Stop만** | 입력 대기("Claude is waiting for your input")는 cmux Claude 래퍼가 이미 네이티브로 알림 — 중복 방지 |
| 기존 훅 | terminal-notifier 훅 4개(Stop/Notification/PreToolUse/PostToolUse) 제거 | Pre/PostToolUse는 매 도구 호출마다 배너를 띄우는 스팸. Stop/Notification은 새 방식이 대체 |
| 폴백 | cmux 밖이거나 CLI 부재 시 terminal-notifier 일반 배너 (점프 없음) | terminal-notifier 권한 승인 확인됨 (auth=7) |
| 워크스페이스 식별 | 세션 env `CMUX_WORKSPACE_ID` / `CMUX_SURFACE_ID` | 훅은 Claude 프로세스의 env를 상속 — 별도 조회 불필요 |
| settings.json 편집 | python3 stdlib(json) | macOS 개발 머신 기본 존재, 의존성 없음 |

## 전제 조건 (새 머신 체크리스트)

- cmux 앱 + macOS 알림 권한 허용 (시스템 설정 > 알림 > cmux, 1회 수동)
- python3 (install/uninstall 서브커맨드용)
- terminal-notifier (선택 — cmux 밖 폴백용, 없으면 폴백 생략)

환경 재현: `git clone` → `./install.sh` → `claude-cmux-notify install`.

## 1. 파일 구성

```
scripts/bin/claude-cmux-notify      # 실행 파일 (POSIX sh + python3 heredoc)
scripts/bin/claude-cmux-notify.md   # 문서 (레포 관례: 같은 basename)
```

`scripts/bin`은 이미 zshrc 로더가 PATH에 넣으므로 추가 배포 작업 없음.
README 툴 목록에 항목 추가.

## 2. 알림 모드 (기본 동작)

훅이 `claude-cmux-notify` 를 인자 없이 호출하면:

1. stdin의 훅 JSON에서 `hook_event_name`, `cwd`, `message`(있으면)를 읽는다.
2. 메시지 구성:
   - title: `Claude Code`
   - subtitle: `basename(cwd)` (없으면 생략)
   - body: Stop → `작업이 끝났습니다`, 그 외 이벤트 → JSON의 `message` 값
     (없으면 이벤트 이름). 스크립트는 이벤트 종류에 무관하게 동작한다 —
     설치는 Stop만 하지만, 사용자가 다른 이벤트에 수동으로 걸어도 된다.
3. 발송:
   - `CMUX_WORKSPACE_ID`가 있고 `cmux` CLI가 있으면:
     `cmux notify --title ... --subtitle ... --body ... --workspace $CMUX_WORKSPACE_ID --surface $CMUX_SURFACE_ID`
   - 아니면 terminal-notifier가 있으면 일반 배너 (점프 없음).
   - 둘 다 없으면 조용히 exit 0.
4. 어떤 실패도 훅 체인을 막지 않는다: 항상 exit 0, stderr에만 로그.

## 3. install 서브커맨드

`claude-cmux-notify install`:

1. `~/.claude/settings.json`을 `settings.json.bak-<timestamp>`로 백업.
2. python3로 JSON 편집:
   - `hooks.Stop / Notification / PreToolUse / PostToolUse` 각 배열에서
     command에 `terminal-notifier` 또는 `claude-cmux-notify`가 들어간 엔트리를
     제거 (다른 훅은 보존). 빈 배열이 되면 키 자체를 제거.
   - `hooks.Stop`에 `{matcher: ".*", hooks: [{type: "command", command: "<이 스크립트의 절대 경로>"}]}` 추가.
3. 결과 요약 출력 (제거한 훅 수, 추가한 훅).

멱등: 재실행하면 자기 자신을 제거 후 다시 추가하므로 중복 등록 없음.

`claude-cmux-notify uninstall`: 백업 후 위 제거 로직만 수행 (추가 없음).
terminal-notifier 엔트리는 install이 이미 제거했으므로, uninstall의 대상은
사실상 `claude-cmux-notify` 엔트리다.

## 4. 에러 처리

- settings.json이 없으면 install은 `{"hooks": {...}}`만 담긴 새 파일 생성.
- settings.json 파싱 실패 시 install은 중단하고 백업 경로 안내 (원본 불변).
- 알림 모드에서 stdin이 JSON이 아니어도 기본 메시지로 발송 (exit 0).
- `cmux notify` 실패(소켓 다운 등) 시 terminal-notifier 폴백 시도 후 exit 0.

## 5. 검증

- **알림 모드**: 훅 JSON 샘플을 stdin으로 넣어 실행 → `cmux list-notifications`
  최상단에 등록 확인. 실제 배너·클릭 점프는 install 후 실 세션 턴 종료로 확인
  (이번 브레인스토밍에서 수동 테스트로 이미 검증됨).
- **install/uninstall**: env `CLAUDE_CMUX_NOTIFY_SETTINGS`로 settings.json 경로를
  오버라이드할 수 있다 (기본 `~/.claude/settings.json`, 테스트 전용). fake 파일로
  왕복 테스트 — 기존 훅 4개 제거·Stop 등록·멱등성·무관 키(statusLine 등) 보존 확인.
- 실제 install 후 이 세션 응답 종료 시 배너 확인.

## 비범위 (YAGNI)

- Notification(입력 대기) 훅 등록 — cmux 래퍼가 이미 처리.
- 하이브리드 경로 자동 감지 (cmux 권한 상태 확인 등).
- Linux 지원.
