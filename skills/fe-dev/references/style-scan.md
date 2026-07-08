# style-scan — 레포 스타일 파악 절차

산출물: 대상 레포 루트의 `.claude/fe-style.md`. 이 파일은 이후 모든 세션의
출발점이고, 검증 루프가 "실행 명령" 섹션을 그대로 사용한다.

## 0. FE 레포 판별 (게이트)

다음 중 하나라도 만족하면 FE 레포로 본다:

- `package.json`의 dependencies/devDependencies에 react, vue, svelte, angular,
  solid-js, astro, next, nuxt 중 하나가 있다.
- vite/webpack 설정과 함께 진입 `index.html` 또는 `src/main.*`/`src/index.*`가 있다.

아니면 **즉시 중단**하고 사용자에게 "FE 레포가 아닌 것 같다"고 판별 근거와 함께
알린다. 추측으로 진행하지 않는다.

## 1. 스캔 항목

각 항목은 설정 파일 선언이 아니라 **실제 코드에서 귀납**해서 확인한다.

| 항목 | 확인 방법 |
|---|---|
| 프레임워크·언어 | package.json dependencies, tsconfig.json 유무 |
| 패키지 매니저 | lockfile: pnpm-lock.yaml → pnpm, yarn.lock → yarn, package-lock.json → npm, bun.lockb → bun |
| 실행 명령 | package.json scripts에서 dev/build/test/lint/typecheck 해당 항목. 없으면 프레임워크 기본값 대신 **없다고 기록** |
| 디렉터리·명명 규칙 | src/ 아래 실제 배치를 2~3개 기능 단위로 관찰 (pages/components/hooks 구분, PascalCase 여부, index 파일 사용 등) |
| 스타일링 | 실제 컴포넌트 파일 2~3개에서 확인: Tailwind 클래스 / CSS Modules import / styled-components / vanilla-extract 등 |
| 상태·데이터 | 전역 상태 라이브러리(redux/zustand/jotai 등)와 데이터 페칭(react-query/swr/fetch 직접) — 실제 사용 파일 경로와 함께 |
| 테스트 패턴 | 기존 테스트 파일을 최소 1개 열어 러너(vitest/jest/playwright), 위치 규칙(co-located vs __tests__), 스타일(testing-library 등)을 기록. 테스트가 없으면 없다고 기록 |
| 모노레포 | pnpm-workspace.yaml / workspaces 필드. 있으면 FE 패키지 위치와 패키지별 명령 기록 |

## 2. 산출물 템플릿

`.claude/fe-style.md`를 이 구조로 작성한다:

```markdown
# FE Style — <레포 이름> (generated <오늘 날짜>)

## 스택 요약
<프레임워크, TS 여부, 패키지 매니저 — 한두 줄>

## 실행 명령
- dev: <명령 또는 "없음">
- build: <명령>
- test: <명령>
- lint: <명령>
- typecheck: <명령 또는 "없음">

## 컨벤션
<파일 배치, 명명, import 스타일 — 실제 예시 경로 포함>

## 스타일링
<방식 + 근거가 된 파일 경로>

## 상태·데이터
<라이브러리 + 실제 사용 파일 경로>

## 테스트 패턴
<러너, 위치 규칙, 예시 테스트 파일 경로, 관례>

## 주의사항
<함정: dev 서버 포트, 필요한 env, 느린 빌드 등. 발견될 때마다 추가>
```

## 3. 갱신 정책

- 생성 날짜만 기록한다. 해시·mtime 비교 같은 자동 staleness 감지는 하지 않는다.
- 작업 중 이 파일과 실제 코드가 모순되면 **그 자리에서** 해당 섹션을 갱신한다.
- 포트 충돌, env 부재 같은 함정을 만나면 "주의사항"에 추가해 다음 세션이
  같은 함정에 빠지지 않게 한다.
