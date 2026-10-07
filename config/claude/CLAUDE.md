# 모델 라우팅 지침 (전역 — 모든 프로젝트 공통)

작업 성격으로 모델을 고른다. Agent 툴·Workflow `agent()`로 서브에이전트를 띄울 땐 `model`을 항상 명시한다.

| 작업 | 모델 | 규칙 |
|---|---|---|
| **추론 — 아주아주 어려운 문제** | `fable` (Fable 5.1) | 아키텍처 결정, 원인 불명 장애, 여러 제약이 얽힌 설계처럼 답이 자명하지 않은 것만 |
| **추론 — 자명한 편이고 사용자 아이디어가 핵심인 문제** | `opus` (Opus 5.5) | 방향은 사용자가 이미 줬고 그걸 구체화·정리하는 일. 깊게 재해석하지 말고 사용자 아이디어를 따른다 |
| **코딩** | `opus` (Opus 5.5) — **무조건** | 구현·수정·디버깅·리팩터링 전부. 메인이 Fable이어도 코드는 opus 서브에이전트가 쓴다 |
| **검토** | 코드를 쓴 것과 **다른** `opus` 인스턴스, 또는 advisor 역할의 `fable` | 작성자가 자기 코드를 검토하지 않는다. 일반 검토는 다른 opus, 판단이 어려운 것만 fable |
| **문서 읽기·쓰기·분석** | `sonnet` (Sonnet 5.5) | 코드베이스 탐색·요약, 문서 작성, 조사, 로그·데이터 분석 |

추가 규칙:
- 메인 세션 모델은 사용자가 고른다. 메인이 Fable일 때 문제가 자명하면 Fable이 길게 추론하지 말고 opus에 맡긴다.
- fable은 비싸다. 서브에이전트를 fable로 도배하지 않는다 — 위 표의 "아주 어려운 추론"과 "advisor 검토"에만 쓴다.
- 서브에이전트 결과를 사용자에게 전하기 전에 메인이 사실 관계(테스트 통과 여부, 실제 변경 파일)를 직접 확인한다.

# Coding behavior

Guidelines to reduce common LLM coding mistakes. They bias toward caution over speed; for trivial tasks, use judgment.

## 1. Think before coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

- State your assumptions explicitly before implementing.
- If multiple interpretations exist, present them. Don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- Ask when a wrong assumption would be expensive or hard to reverse (schema, API contract, data migration, scope of a ticket). For cheap, reversible choices, state the assumption and proceed; a subagent or background run that cannot ask must always proceed under a stated assumption.
- A question you must wait on goes last in the reply, numbered (Q1, Q2) so it can be answered by number.
- A question or a discussion gets an answer, not an edit. "질문임", "이야기 해줘", "어떻게 할 건지 말해줘" mean do not modify files, update docs, or commit. When scope is narrowed ("A만 해", "배포는 하지 말고"), stay inside it. If it is unclear whether something is a question or an instruction, answer it and ask in one closing line whether to proceed.

## 2. Simplicity first

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify. If unsure whether code is verbose or non-YAGNI, have an adversarial subagent cross-check instead of guessing.

## 3. Surgical changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it. Don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

## 4. Goal-driven execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

Tests cover regressions that could break and the new spec. Don't hang extra tests on every branch; unnecessary tests are over-engineering too.

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

For UI or web changes, tests alone are not enough: run the app, look at it (playwright or a browser), and report what you saw. When the user says they will do a step themselves ("내가 할게", "뭐 해야할지만 말해"), give a numbered checklist of their steps only, with no explanation unless asked.

Before claiming anything is done, fixed, or passing, load the `verification-before-completion` skill and apply its gate: run the proving command fresh in this turn, read the full output, then state the claim with the evidence. A subagent's "success" is not evidence; check the diff and run the check yourself. If verification is impossible, say what was not verified instead of claiming completion.

These guidelines are working if: fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

# 사용자 (머신 로컬)

이름, 슬랙 표시명 등 개인 정보는 레포 밖 `~/.claude/CLAUDE.local.md`에 둔다 (config/claude/CLAUDE.local.md.example 참조).

@~/.claude/CLAUDE.local.md
