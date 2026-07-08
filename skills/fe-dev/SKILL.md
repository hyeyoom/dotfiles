---
name: fe-dev
description: Use when asked to add features, fix bugs, or refactor in a frontend repository (React/Vue/Next/Svelte/etc.), especially when the user has a backend background or is unfamiliar with frontend conventions, styling, state management, or browser testing
---

# fe-dev — FE 작업 워크플로 (백엔드 개발자용)

frontend 레포 작업을 3단계로 진행한다. 이 스킬은 FE 지식만 담당하고,
작업 프로세스는 superpowers 스킬에 위임한다.

**원칙: 스킬은 FE 지식을, superpowers는 프로세스를.**

## 체크리스트

아래 3단계를 각각 task로 만들어 순서대로 진행한다.

1. 스타일 파악
2. 태스크 분석·작업
3. 검증 루프

## 1. 스타일 파악

- 대상 레포 루트의 `.claude/fe-style.md`가 있으면 읽고 바로 2단계로.
- 없으면 `references/style-scan.md`를 읽고 절차대로 생성한다.
- FE 레포가 아니라고 판별되면(기준은 style-scan.md) 즉시 중단하고 사용자에게 알린다.
- 이후 어느 단계에서든 fe-style.md가 실제 코드와 모순되면 그 자리에서 갱신한다.

## 2. 태스크 분석·작업

- 관련 파일을 탐색하고 변경 계획을 세운다.
- 계획·결과를 사용자에게 설명할 때는 백엔드 용어로 번역한다 —
  `references/fe-for-backend.md`를 읽고 비유를 사용하되, 비유가 깨지는 지점을 명시.
- 구현 프로세스는 superpowers가 설치돼 있으면 위임:
  - 요구사항이 모호한 기능 → superpowers:brainstorming
  - 구현 → superpowers:test-driven-development
  - 버그 수정 → superpowers:systematic-debugging
- superpowers 스킬이 목록에 없으면 아래 "standalone fallback"을 따른다.
- 테스트는 fe-style.md의 "테스트 패턴" 섹션에 기록된 이 레포의 실제 관례를 따른다.
  새 패턴을 발명하지 않는다.

## 3. 검증 루프

- `references/verify-loop.md`를 읽고 증거 사다리를 레벨 1부터 실행한다.
- 어느 레벨이든 실패하면 수정 후 레벨 1부터 재실행. 전 레벨 green까지 반복.
- 증거 없이 완료를 선언하지 않는다 (superpowers:verification-before-completion과 동일 원칙).

## standalone fallback (superpowers 부재 시)

superpowers 스킬이 목록에 없을 때만 적용하는 최소 프로세스. 있으면 반드시 위임한다.

- **모호한 요구사항**: 구현 전에 목적·제약·완료 기준을 질문으로 좁히고,
  접근 방식을 합의받은 뒤 시작한다.
- **구현**: 실패하는 테스트를 먼저 작성해 실패를 확인한 뒤, 통과하는 최소 구현을
  작성한다. 테스트보다 구현을 먼저 썼다면 버리고 다시 한다.
- **버그**: 추측으로 고치지 않는다. 재현 → 원인 규명 → 원인을 잡는 실패 테스트 →
  수정 → 테스트 통과 확인 순서.
- **완료 선언**: verify-loop.md의 증거 사다리가 그대로 게이트다
  (superpowers 유무와 무관하게 항상 적용).

## 경계

- 대상 레포에 남기는 파일은 `.claude/fe-style.md` 하나뿐이다.
  커밋/gitignore 여부는 사용자가 결정한다.
- 모노레포면 루트 fe-style.md 하나에 워크스페이스 구조와 패키지별 명령을 기록한다.
