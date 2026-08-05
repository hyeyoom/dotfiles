# 구현 플랜: 머신 프로필 계층 + aitask 추적 개선

스펙: `docs/superpowers/specs/2026-08-05-machine-profile.md`

## Task 1 — 프로필 템플릿
- `config/dotfiles-profile.example` 작성 (3개 변수 + 주석, DISABLED 줄 형식 경고)

## Task 2 — colonize.sh 단계 스킵
- profile source, `skip_step` 헬퍼 (전체명/축약명), `(skip)` 출력
- profile 부재 시 시작 안내 한 줄

## Task 3 — 링크 보호
- 40-claude.sh / 50-configs.sh: profile source + `skip_link` 헬퍼
- 검증: fixture HOME + SKIP_LINKS=gitconfig → 기존 파일 불가침, .bak 없음

## Task 4 — brew prefix
- 10-brew.sh, 00-omz.zsh 이중 탐지, path.zsh는 HOMEBREW_PREFIX

## Task 5 — 로더 블록 v2 + installer 재작성
- install.sh: 블록 생성→비교→백업 후 교체(awk splice), 레거시 .disabled 마이그레이션
- install.sh <tool> / uninstall.sh <tool>: profile DISABLED 목록 편집 (공유 헬퍼 중복 정의)
- 검증: fixture HOME에서 신규 설치/멱등/v1 블록 업그레이드/disable→로더 스킵→enable

## Task 6 — check.sh profile 반영
- 스킵 단계·링크·툴을 `(skip)`으로, fail 미집계

## Task 7 — aitask 루트 자동 등록
- `_aitask_ensure_root` + `_aitask_base` 경로 분기에서 호출
- 검증: fixture roots — 미등록 경로 new → 파일에 추가 + ls 표시, 재실행 멱등

## Task 8 — 문서 + 배포
- README(프로필 섹션, 회사 랩탑 절차, 설치/제거 갱신), aitask.md(자동 등록)
- 실기기 `install.sh` 실행으로 로더 블록 v2 반영 확인
- 커밋 + push (settings.json, scripts/bin/boogie 제외)
