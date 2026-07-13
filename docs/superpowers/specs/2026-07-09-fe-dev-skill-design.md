# fe-dev 스킬 설계

백엔드 개발자가 잘 모르는 frontend 레포에서 작업을 맡길 때 쓰는 Claude Code 스킬.
"레포 스타일 파악 → 태스크 분석·작업(테스트 포함) → 증거 기반 검증 루프"를 하나의
워크플로로 묶는다.

## 결정 사항 (브레인스토밍 결과)

| 항목 | 결정 |
|---|---|
| 대상 | 범용 — 어떤 FE 레포든 처음 열었을 때 동작 (스택 감지부터 시작) |
| 검증 수준 | 증거 기반 완전 자동 — 테스트 + 실제 앱 조작까지 통과해야 완료 선언 |
| 스타일 파악 결과 | 대상 레포에 `.claude/fe-style.md`로 영속화, 이후 세션은 읽고 시작 |
| superpowers 관계 | 조합 — 이 스킬은 FE 지식만, 프로세스(TDD·디버깅)는 superpowers에 위임. 부재 시 SKILL.md 내장 standalone fallback(한 줄 에센스 수준)으로 동작 |
| 구조 | 단일 스킬 + 단계별 reference 파일 (progressive disclosure) |
| 배포 | dotfiles 레포 `skills/`에 두고 install.sh가 `~/.claude/skills/`로 심링크 |

## 1. 스킬 구조와 배포

```
dotfiles/
  skills/
    fe-dev/
      SKILL.md                  # 진입점: 워크플로 오케스트레이터 (얇게)
      references/
        style-scan.md           # 1단계: 레포 스타일 파악 절차
        fe-for-backend.md       # 백엔드 ↔ FE 개념 번역표
        verify-loop.md          # 3단계: 검증 루프 절차·판정 기준
```

- `install.sh`: `skills/*/`를 `~/.claude/skills/<name>` 심링크로 설치 (멱등).
  심링크라 레포에서 스킬을 수정하면 재설치 없이 즉시 반영된다.
  심링크 보정은 zshrc 블록 존재 여부와 **독립적으로** 매 실행 시 수행한다
  (기존 "이미 설치돼 있으면 아무것도 하지 않는다" 로직은 zshrc 블록에만 적용).
- `uninstall.sh` (전체): 이 레포를 가리키는 심링크만 제거.
- `uninstall.sh fe-dev` / `install.sh fe-dev`: 스킬 단위 on/off —
  기존 zsh/bin 툴과 동일한 UX (심링크 제거/재생성으로 구현).
- README의 구조 다이어그램과 툴 목록에 skills 항목 추가.

## 2. SKILL.md — 오케스트레이터

frontmatter `description`으로 트리거 명시: "frontend 레포에서 기능 추가·수정·버그픽스
요청을 받았을 때. 사용자는 백엔드 배경이며 FE 세부사항은 번역해서 설명해야 한다."

본문은 3단계 체크리스트와 전환 규칙만 담는다:

1. **스타일 파악** — 대상 레포에 `.claude/fe-style.md`가 있으면 읽고 2단계로.
   없거나 실제 코드와 모순이 발견되면 `references/style-scan.md` 절차로 생성/갱신.
2. **태스크 분석·작업** — 관련 파일 탐색 → 변경 계획을 백엔드 용어로 번역해 설명
   (`references/fe-for-backend.md` 참조) → 구현은 superpowers에 위임:
   모호한 기능이면 brainstorming, 구현은 test-driven-development,
   버그면 systematic-debugging. 테스트는 fe-style.md에 기록된 이 레포의
   테스트 패턴을 따른다.
3. **검증 루프** — `references/verify-loop.md` 로드. 증거 사다리 전 레벨이
   green이 될 때까지 수정↔재검증 반복. 완료 선언은 증거 첨부 필수.

핵심 원칙: **스킬은 FE 지식을, superpowers는 프로세스를.** 프로세스 내용을
이 스킬에 복붙하지 않는다.

## 3. style-scan.md — 1단계 상세

스캔 항목:

- package.json: 프레임워크, scripts, 패키지 매니저(lockfile로 판별), 테스트 러너
- tsconfig / eslint / prettier 설정
- 디렉터리 구조와 컴포넌트 명명 규칙 (실제 파일에서 귀납)
- 스타일링 방식 (Tailwind / CSS Modules / styled-components / vanilla-extract …)
- 상태 관리·데이터 페칭 패턴 (기존 코드에서 실제 사용례 확인)
- 기존 테스트 파일의 실제 패턴 (러너 설정만이 아니라 예시 파일 자체)
- 모노레포 여부와 워크스페이스 구조

산출물 — 대상 레포의 `.claude/fe-style.md`:

```markdown
# FE Style — <repo> (generated <date>)
## 스택 요약        # framework, TS 여부, 패키지 매니저
## 실행 명령        # dev / build / test / lint / typecheck — 검증 루프가 그대로 사용
## 컨벤션          # 파일 배치, 명명, import 스타일
## 스타일링
## 상태·데이터
## 테스트 패턴      # 러너, 실제 예시 파일 경로, 관례
## 주의사항        # 함정: dev 서버 포트, 필요한 env, 느린 빌드 등
```

갱신 정책: 생성 날짜만 기록하고, 코드와 모순이 발견되는 즉시 갱신한다.
해시 비교 등 정교한 staleness 감지는 하지 않는다 (YAGNI).

## 4. verify-loop.md — 3단계 상세

증거 사다리 — 아래에서부터 전부 통과해야 완료:

| 레벨 | 수단 | 증거 |
|---|---|---|
| 1. 정적 | lint + typecheck (fe-style.md의 명령) | 명령 출력 |
| 2. 테스트 | 레포의 테스트 러너 | 통과 출력 (이번에 추가한 테스트 포함) |
| 3. 빌드 | production build | 성공 출력 |
| 4. 런타임 | dev 서버 기동 → playwright로 변경된 플로우 직접 조작 | 스크린샷 + 콘솔 에러 0 + 실패 네트워크 요청 0 |
| 5. API (해당 시) | curl로 API route / BFF 직접 호출 | 상태코드 + 응답 본문 |

런타임 검증(레벨 4)은 playwright MCP 도구를 사용한다:
`browser_navigate` → 변경된 플로우 조작(클릭·입력·폼 제출) →
`browser_console_messages`로 콘솔 에러 확인 → `browser_network_requests`로
4xx/5xx 확인 → `browser_take_screenshot`. CDP 수준의 확인(콘솔·네트워크)은
이 도구들이 커버한다.

루프 규칙:

- 어느 레벨이든 실패 → superpowers:systematic-debugging으로 원인 규명 → 수정 →
  **레벨 1부터 재실행** (수정이 앞 레벨을 깨뜨렸을 가능성 배제).
- 같은 레벨에서 같은 원인으로 3회 실패하면 루프를 멈추고 상황을 보고한다
  (무한 루프 방지).
- fallback 금지: dev 서버 기동 실패, 브라우저 불가 환경 등으로 레벨 4를 수행할 수
  없으면 건너뛰지 않고 **실패로 취급해 보고**한다. 조용한 다운그레이드는
  "증거 기반 완전 자동" 결정과 모순이다.

완료 보고 형식: 변경 파일 목록, 레벨별 증거, 남은 리스크.
superpowers:verification-before-completion과 합치되게 — 증거 없이 완료 선언 금지.

뒷정리: 스킬이 띄운 dev 서버는 검증 후 종료한다.

## 5. fe-for-backend.md — 번역표

사용자에게 설명할 때만 로드하는 참조 자료. 예시:

| FE 개념 | 백엔드 비유 |
|---|---|
| 컴포넌트 | 핸들러 + 템플릿 (입력 props → 출력 UI) |
| props | 함수 인자 / DTO |
| 상태 관리 (Redux 등) | 인메모리 캐시 + pub/sub |
| hydration | 직렬화된 상태의 역직렬화 + 리스너 재연결 |
| CSR / SSR | 클라이언트 렌더 vs 서버 사이드 템플릿 렌더 |
| React Query 캐시 | read-through 캐시 + TTL/무효화 |

구현 시 표를 확장한다. 설명 원칙: 비유로 시작하되 비유가 깨지는 지점을 명시.

## 6. 에러 처리·엣지 케이스

- **FE 레포가 아님**: 1단계에서 감지(FE 프레임워크·package.json 부재)하면 즉시
  중단하고 사용자에게 알린다.
- **모노레포**: 루트 `.claude/fe-style.md` 하나에 워크스페이스 구조와
  패키지별 실행 명령을 기록한다.
- **`.claude/` 커밋 곤란**: 파일 위치는 바꾸지 않고, 사용자가 대상 레포에서
  gitignore 여부만 결정한다.
- **포트 충돌·env 부재**: fe-style.md의 주의사항 섹션에 기록해 다음 세션이
  같은 함정에 빠지지 않게 한다.

## 7. 스킬 자체 검증

- 구현 시 superpowers:writing-skills의 작성·검증 절차를 따른다.
- 완료 후 실제 FE 레포 하나에서 소형 태스크로 1→2→3단계 풀 사이클을 실행해
  스킬이 의도대로 동작하는지 확인한다.

## 비범위 (YAGNI)

- 검증 하니스의 셸 스크립트 추출 (`scripts/bin/`) — 패턴이 굳은 뒤 고려
- fe-style.md의 자동 staleness 감지 (해시·mtime 비교)
- 스택별 전용 reference (React 전용, Vue 전용 등) — 범용 절차로 시작
