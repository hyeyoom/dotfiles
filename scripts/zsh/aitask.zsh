# aitask — git worktree + cmux tab + claude launcher
# usage:
#   aitask                        # interactive fzf menu (jump / PR / drop / new)
#   aitask <repo> <task> [prefix] # = aitask new <repo> <task> [prefix]
#   aitask new  <repo> <task> [prefix]  # worktree + cmux tab + claude + git pane
#                                 # branch = <prefix>/<task> (default: task/)
#   aitask multi <task> <repo> <repo>... [-p prefix] [-t title]
#                                 # multi-repo ticket: umbrella dir + per-repo worktrees
#   aitask done <repo> <task>     # merge into base, remove worktree/branch, close tab
#   aitask drop <repo> <task>     # discard without merging
#   aitask ls                     # list active tasks across all roots
#   aitask root add <path>        # register a repo root
#   aitask root ls                # list roots
#
# repo resolution: bare name is searched under every root; a path containing
# "/" is used as-is. Ambiguous names across roots are reported as an error.

: "${AITASK_CONFIG_DIR:=$HOME/.config/aitask}"
: "${AITASK_ROOTS_FILE:=$AITASK_CONFIG_DIR/roots}"
: "${AITASK_AGENT_CMD:=claude}"
: "${AITASK_BRANCH_PREFIX:=task}"
: "${AITASK_BRANCH_PREFIXES:=task features hotfix bugfix release chore}"

_aitask_roots() {
  if [[ -s $AITASK_ROOTS_FILE ]]; then
    grep -Ev '^[[:space:]]*(#|$)' "$AITASK_ROOTS_FILE"
  else
    print -r -- "$HOME/github"
  fi
}

_aitask_valid_task() {
  [[ $1 =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]] && return 0
  print -u2 "aitask: invalid task name '$1'"
  print -u2 "aitask: allowed: letters/digits/._- , must start with letter or digit (e.g. TASK-123-fix-login)"
  return 1
}

_aitask_valid_prefix() {
  [[ $1 =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]] && return 0
  print -u2 "aitask: invalid branch prefix '$1' (single level, letters/digits/._- e.g. features, hotfix)"
  return 1
}

# actual branch of a worktree (falls back to <default prefix>/<task> if unreadable)
_aitask_wt_branch() {
  local b
  b=$(git -C "$1" branch --show-current 2>/dev/null)
  print -r -- "${b:-$AITASK_BRANCH_PREFIX/$2}"
}

# title match: exact "<repo>/<task>" or with custom suffix "<repo>/<task> · <epic>"
_aitask_match_title() {
  [[ $1 == "$2" || $1 == "$2 · "* ]]
}

# workspace lookup by "<repo>/<task>" (find-window is substring match,
# "No matches" goes to stdout, custom tab titles append " · <epic>")
_aitask_find_ws() {
  local title=$1 line ref t
  CMUX_QUIET=1 cmux find-window "$title" 2>/dev/null | while IFS= read -r line; do
    ref=${line%%[[:space:]]*}
    [[ $ref == workspace:* ]] || continue
    t=${line#*\"}; t=${t%\"}
    # cmux prefixes the title with a single status-icon token (e.g. "⠂ ", "✳ ")
    if _aitask_match_title "$t" "$title" \
       || { [[ $t == *' '* ]] && _aitask_match_title "${t#* }" "$title" }; then
      print -r -- "$ref"; return 0
    fi
  done
  return 1
}

# auto-register the parent dir of a path-resolved repo as a root, so the
# worktrees created next to it show up in ls/menu (silent otherwise)
_aitask_ensure_root() {
  local root=$1 r
  while IFS= read -r r; do
    [[ ${r/#\~/$HOME} == "$root" ]] && return 0
  done < <(_aitask_roots)
  mkdir -p "${AITASK_ROOTS_FILE:h}"
  # seed defaults on first write so the implicit ~/github isn't lost
  [[ -f $AITASK_ROOTS_FILE ]] || _aitask_roots > "$AITASK_ROOTS_FILE"
  print -r -- "$root" >> "$AITASK_ROOTS_FILE"
  print -u2 "aitask: root 자동 등록: $root (ls/메뉴에 포함됨 — 해제: $AITASK_ROOTS_FILE 편집)"
}

# resolve repo name/path -> canonical checkout dir (echoed)
_aitask_base() {
  local repo=$1 root hits=()
  if [[ $repo == */* ]]; then
    local p=${repo/#\~/$HOME}
    p=${p:A}
    [[ -d $p/.git ]] || { print -u2 "aitask: not a git repo: $p"; return 1; }
    _aitask_ensure_root "${p:h}"
    print -r -- "$p"; return 0
  fi
  while IFS= read -r root; do
    root=${root/#\~/$HOME}
    [[ -d $root/$repo/.git ]] && hits+=("$root/$repo")
  done < <(_aitask_roots)
  case $#hits in
    0) print -u2 "aitask: repo '$repo' not found under roots:"; _aitask_roots >&2; return 1 ;;
    1) print -r -- "$hits[1]" ;;
    *) print -u2 "aitask: '$repo' is ambiguous, use a full path:"
       print -u2 -l -- "$hits[@]"; return 1 ;;
  esac
}

_aitask_new() {
  local repo=$1 task=$2 prefix=${3:-$AITASK_BRANCH_PREFIX} title=$4
  [[ $prefix == - ]] && prefix=$AITASK_BRANCH_PREFIX   # "-" = default, allows title without prefix
  title=${title//\"/}                                  # quotes break find-window parsing
  [[ -n $repo && -n $task ]] || { print -u2 "usage: aitask new <repo> <task> [branch-prefix|-] [tab-title]"; return 1; }
  _aitask_valid_task "$task" || return 1
  _aitask_valid_prefix "$prefix" || return 1

  local base; base=$(_aitask_base "$repo") || return 1
  local name=${base:t}
  local wt=${base:h}/$name.wt/$task
  local branch=$prefix/$task
  # existing worktree keeps whatever branch it was created with
  [[ -d $wt ]] && branch=$(_aitask_wt_branch "$wt" "$task")

  if [[ ! -d $wt ]]; then
    local start=HEAD
    if git -C "$base" remote get-url origin &>/dev/null; then
      git -C "$base" fetch origin --prune || return 1
      start=$(git -C "$base" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo HEAD)
    fi
    mkdir -p "${wt:h}"
    git -C "$base" worktree add "$wt" -b "$branch" "$start" || return 1
  fi

  # task scope — auto-loaded by Claude Code every turn (keep user edits on re-run)
  [[ -f $wt/CLAUDE.local.md ]] || cat > "$wt/CLAUDE.local.md" <<EOF
이 worktree는 $branch 전용이다.

범위:
- "$task" 작업만 수행한다. 범위 밖 리팩터링 금지.
- public API / DB schema 변경 금지 (필요하면 먼저 물어볼 것).

방식:
- 먼저 관련 파일을 찾고 변경 계획을 요약한 뒤, 승인받고 수정한다.
- 완료 후 변경 파일, 테스트 결과, 리스크를 요약한다.
EOF
  grep -qx 'CLAUDE.local.md' "$base/.git/info/exclude" 2>/dev/null \
    || echo 'CLAUDE.local.md' >> "$base/.git/info/exclude"

  # cmux: left = agent, right = git status
  local out ws sf
  if ws=$(_aitask_find_ws "$name/$task"); then
    CMUX_QUIET=1 cmux select-workspace --workspace "$ws" >/dev/null 2>&1
    print -r -- "aitask: $name/$task already open (tab $ws) — focused"
    return 0
  fi
  local tab=$name/$task${title:+" · $title"}
  out=$(CMUX_QUIET=1 cmux new-workspace --name "$tab" --cwd "$wt" \
        --command "$AITASK_AGENT_CMD") || return 1
  ws=${out##* }

  out=$(CMUX_QUIET=1 cmux new-split right --workspace "$ws" --focus false) || return 0
  sf=$(awk '{print $2}' <<< "$out")
  ( sleep 1
    CMUX_QUIET=1 cmux send --workspace "$ws" --surface "$sf" \
      "git -c color.status=always status --short --branch && git log --oneline -5"
    CMUX_QUIET=1 cmux send-key --workspace "$ws" --surface "$sf" Enter
  ) &!
  print -r -- "aitask: $name/$task ready ($wt, branch $branch, tab $ws)"
}

_aitask_close_tab() {
  local ws
  ws=$(_aitask_find_ws "$1") || return 0
  CMUX_QUIET=1 cmux close-workspace --workspace "$ws" >/dev/null 2>&1
}

_aitask_done() {
  local repo=$1 task=$2
  [[ -n $repo && -n $task ]] || { print -u2 "usage: aitask done <repo> <task>"; return 1; }

  local base; base=$(_aitask_base "$repo") || return 1
  local name=${base:t}
  local wt=${base:h}/$name.wt/$task

  [[ -d $wt ]] || { print -u2 "aitask: no such worktree: $wt"; return 1; }
  local branch; branch=$(_aitask_wt_branch "$wt" "$task")

  if [[ -n $(git -C "$wt" status --porcelain) ]]; then
    print -u2 "aitask: worktree has uncommitted changes, commit or stash first:"
    git -C "$wt" status --short >&2
    return 1
  fi
  if [[ -n $(git -C "$base" status --porcelain) ]]; then
    print -u2 "aitask: canonical checkout is dirty ($base), clean it before merging"
    return 1
  fi

  git -C "$base" merge --no-ff "$branch" -m "Merge $branch" || return 1
  git -C "$base" worktree remove "$wt" || return 1
  git -C "$base" branch -d "$branch"
  rmdir "${base:h}/$name.wt" 2>/dev/null
  _aitask_close_tab "$name/$task"
  print -r -- "aitask: merged $branch into $(git -C "$base" branch --show-current), cleaned up"
}

_aitask_drop() {
  local repo=$1 task=$2
  [[ -n $repo && -n $task ]] || { print -u2 "usage: aitask drop <repo> <task>"; return 1; }

  local base; base=$(_aitask_base "$repo") || return 1
  local name=${base:t}
  local wt=${base:h}/$name.wt/$task

  [[ -d $wt ]] || { print -u2 "aitask: no such worktree: $wt"; return 1; }
  local branch; branch=$(_aitask_wt_branch "$wt" "$task")

  local dirty=0 unpushed=0 merged=no note="" def basehead prline=""
  [[ -n $(git -C "$wt" status --porcelain 2>/dev/null) ]] && dirty=1
  def=$(git -C "$wt" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
  if git -C "$wt" rev-parse --abbrev-ref '@{u}' &>/dev/null; then
    unpushed=$(git -C "$wt" rev-list --count '@{u}..HEAD' 2>/dev/null)
  elif [[ -n $def ]]; then
    unpushed=$(git -C "$wt" rev-list --count "$def..HEAD" 2>/dev/null)
    note=" (no upstream)"
  else
    basehead=$(git -C "$base" rev-parse HEAD 2>/dev/null)
    [[ -n $basehead ]] && unpushed=$(git -C "$wt" rev-list --count "$basehead..HEAD" 2>/dev/null)
    note=" (no origin, vs local $name HEAD)"
  fi
  if [[ -n $def ]]; then
    git -C "$wt" merge-base --is-ancestor HEAD "$def" 2>/dev/null && merged=yes
  elif [[ -n $basehead ]]; then
    git -C "$wt" merge-base --is-ancestor HEAD "$basehead" 2>/dev/null && merged=yes
  fi
  prline=$(_aitask_prlist "$base" | awk -F'\t' -v b="$branch" '$1==b {print $2" "$3; exit}')

  print -r -- "aitask: $name/$task ($branch)"
  print -r -- "  uncommitted : $( ((dirty)) && print yes || print no )"
  print -r -- "  unpushed    : ${unpushed:-0} commits$note"
  print -r -- "  merged      : $merged${def:+ (into $def)}"
  [[ -n $prline ]] && print -r -- "  PR          : $prline"

  local ans
  if (( dirty )) || (( ${unpushed:-0} > 0 )); then
    print -n "미보존 작업이 있습니다. 정말 삭제하려면 task 이름 '$task' 입력: "
    read -r ans
    [[ $ans == "$task" ]] || { print -u2 "aitask: aborted"; return 1 }
  else
    print -n "drop $wt and delete $branch? [y/N] "
    read -r ans
    [[ $ans == [yY]* ]] || return 1
  fi

  git -C "$base" worktree remove --force "$wt" || return 1
  git -C "$base" branch -D "$branch" 2>/dev/null
  rmdir "${base:h}/$name.wt" 2>/dev/null
  _aitask_close_tab "$name/$task"
  print -r -- "aitask: dropped $name/$task"
}

# git facts for one worktree, tab-separated:
# branch  dirty  ahead  behind  upstream  merged   (ahead = unpushed proxy)
_aitask_wt_fields() {
  local wt=$1 branch dirty ahead behind upstream merged def
  branch=$(git -C "$wt" branch --show-current 2>/dev/null)
  dirty=0; [[ -n $(git -C "$wt" status --porcelain 2>/dev/null) ]] && dirty=1
  upstream=0; ahead=0; behind=0; merged=-
  def=$(git -C "$wt" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
  if git -C "$wt" rev-parse --abbrev-ref '@{u}' &>/dev/null; then
    upstream=1
    read -r behind ahead <<< "$(git -C "$wt" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)"
  elif [[ -n $def ]]; then
    ahead=$(git -C "$wt" rev-list --count "$def..HEAD" 2>/dev/null)
  fi
  if [[ -n $def ]]; then
    if git -C "$wt" merge-base --is-ancestor HEAD "$def" 2>/dev/null
    then merged=1; else merged=0; fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${branch:-?}" "$dirty" "${ahead:-0}" "${behind:-0}" "$upstream" "$merged"
}

# one tab-separated line per single-repo worktree:
# repo  task  wt  branch  dirty  ahead  behind  upstream  merged
_aitask_status() {
  local root wtroot wt name
  while IFS= read -r root; do
    root=${root/#\~/$HOME}
    for wtroot in "$root"/*.wt(N/); do
      name=${${wtroot:t}%.wt}
      for wt in "$wtroot"/*(N/); do
        git -C "$wt" rev-parse --git-dir &>/dev/null || continue
        printf '%s\t%s\t%s\t%s\n' "$name" "${wt:t}" "$wt" "$(_aitask_wt_fields "$wt")"
      done
    done
  done < <(_aitask_roots)
}

# multi-repo tickets: one "task<TAB>umbrella-dir" line each
_aitask_multis() {
  local root um
  while IFS= read -r root; do
    root=${root/#\~/$HOME}
    for um in "$root"/multi.wt/*(N/); do
      [[ -f $um/.aitask-repos ]] && printf '%s\t%s\n' "${um:t}" "$um"
    done
  done < <(_aitask_roots)
}

# open/merged/closed PRs for a repo, best-effort (5s timeout when available)
_aitask_prlist() {
  local base=$1
  local -a tt=()
  (( $+commands[gh] )) || return 0
  git -C "$base" remote get-url origin &>/dev/null || return 0
  (( $+commands[timeout] )) && tt=(timeout 5)
  (( ! $#tt && $+commands[gtimeout] )) && tt=(gtimeout 5)
  (cd "$base" && $tt gh pr list --state all --limit 100 \
     --json headRefName,state,url \
     --jq '.[] | [.headRefName, .state, .url] | @tsv' 2>/dev/null)
}

_aitask_flags() {  # $1..$5 = dirty ahead behind upstream merged
  local flags=""
  (( $1 )) && flags+="*dirty "
  (( $2 )) && flags+="↑$2 "
  (( $3 )) && flags+="↓$3 "
  [[ $4 == 0 ]] && flags+="local "
  [[ $5 == 1 ]] && flags+="merged "
  print -r -- "${flags% }"
}

_aitask_ls() {
  local -a lines multis bases
  lines=(${(f)"$(_aitask_status)"})
  multis=(${(f)"$(_aitask_multis)"})
  (( $#lines || $#multis )) || { print -r -- "aitask: no active tasks"; return 0 }
  local -A prmap
  local line m um mtask base br st url
  for line in $lines; do
    local f=("${(@ps:\t:)line}")
    base=${${f[3]:h}%.wt}
    (( ${bases[(Ie)$base]} )) || bases+=("$base")
  done
  for m in $multis; do
    um=${m#*$'\t'}
    for base in ${(f)"$(<$um/.aitask-repos)"}; do
      (( ${bases[(Ie)$base]} )) || bases+=("$base")
    done
  done
  for base in $bases; do
    while IFS=$'\t' read -r br st url; do
      prmap[$base@$br]=$st
    done < <(_aitask_prlist "$base")
  done
  for line in $lines; do
    local f=("${(@ps:\t:)line}")
    base=${${f[3]:h}%.wt}
    local pr=${prmap[$base@${f[4]}]:-}
    printf '%-14s %-26s %-24s %-18s %s\n' \
      "$f[1]" "$f[2]" "$f[4]" "$(_aitask_flags $f[5] $f[6] $f[7] $f[8] $f[9])" \
      "${pr:+PR:${(L)pr}}"
  done
  for m in $multis; do
    mtask=${m%%$'\t'*}; um=${m#*$'\t'}
    for base in ${(f)"$(<$um/.aitask-repos)"}; do
      local d=$um/${base:t}
      [[ -d $d ]] || continue
      local f=("${(@ps:\t:)$(_aitask_wt_fields "$d")}")
      local pr=${prmap[$base@${f[1]}]:-}
      printf '%-14s %-26s %-24s %-18s %s\n' \
        "multi/$mtask" "${base:t}" "$f[1]" "$(_aitask_flags $f[2] $f[3] $f[4] $f[5] $f[6])" \
        "${pr:+PR:${(L)pr}}"
    done
  done
}

_aitask_pr() {  # $1 = worktree path; push -u then gh pr create --web
  local wt=$1
  (( $+commands[gh] )) || { print -u2 "aitask: gh가 필요합니다 (brew install gh)"; return 1 }
  local branch; branch=$(git -C "$wt" branch --show-current 2>/dev/null)
  [[ -n $branch ]] || { print -u2 "aitask: cannot determine branch in $wt"; return 1 }
  if [[ -n $(git -C "$wt" status --porcelain 2>/dev/null) ]]; then
    print -u2 "aitask: 커밋 안 된 변경이 있습니다. 커밋 후 다시 시도:"
    git -C "$wt" status --short >&2
    return 1
  fi
  local def; def=$(git -C "$wt" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
  if [[ -n $def && $(git -C "$wt" rev-list --count "$def..HEAD" 2>/dev/null) == 0 ]]; then
    print -u2 "aitask: $def 이후 커밋이 없습니다 — PR로 만들 변경이 없음"
    return 1
  fi
  git -C "$wt" push -u origin "$branch" || return 1
  (cd "$wt" && gh pr create --web)
}

# ---- multi-repo tickets: one umbrella dir, one claude session over N worktrees ----

_aitask_multi_tab() {  # $1=umbrella $2=task $3=title
  local um=$1 task=$2 title=$3 out ws sf
  if ws=$(_aitask_find_ws "multi/$task"); then
    CMUX_QUIET=1 cmux select-workspace --workspace "$ws" >/dev/null 2>&1
    print -r -- "aitask: multi/$task already open (tab $ws) — focused"
    return 0
  fi
  local tab=multi/$task${title:+" · $title"}
  out=$(CMUX_QUIET=1 cmux new-workspace --name "$tab" --cwd "$um" \
        --command "$AITASK_AGENT_CMD") || return 1
  ws=${out##* }
  out=$(CMUX_QUIET=1 cmux new-split right --workspace "$ws" --focus false) \
    || { print -r -- "aitask: multi/$task ready ($um, tab $ws)"; return 0 }
  sf=$(awk '{print $2}' <<< "$out")
  ( sleep 1
    CMUX_QUIET=1 cmux send --workspace "$ws" --surface "$sf" \
      'for d in */; do echo "== $d"; git -C "$d" -c color.status=always status --short --branch; done'
    CMUX_QUIET=1 cmux send-key --workspace "$ws" --surface "$sf" Enter
  ) &!
  print -r -- "aitask: multi/$task ready ($um, tab $ws)"
}

_aitask_multi_new() {
  local prefix=$AITASK_BRANCH_PREFIX title="" task
  local -a rest=()
  while (( $# )); do
    case $1 in
      -p) prefix=$2; shift 2 ;;
      -t) title=$2; shift 2 ;;
      *)  rest+=("$1"); shift ;;
    esac
  done
  [[ $prefix == - || -z $prefix ]] && prefix=$AITASK_BRANCH_PREFIX
  title=${title//\"/}
  task=$rest[1]
  (( $#rest >= 3 )) || { print -u2 "usage: aitask multi <task> <repo> <repo>... [-p prefix] [-t 탭제목]"; return 1 }
  _aitask_valid_task "$task" || return 1
  _aitask_valid_prefix "$prefix" || return 1
  local branch=$prefix/$task

  local -a bases=()
  local r base
  for r in "${(@)rest[2,-1]}"; do
    base=$(_aitask_base "$r") || return 1
    (( ${bases[(Ie)$base]} )) || bases+=("$base")
  done
  (( $#bases >= 2 )) || { print -u2 "aitask: multi에는 서로 다른 레포가 2개 이상 필요"; return 1 }

  local proot; proot=$(_aitask_roots | head -1); proot=${proot/#\~/$HOME}
  local um=$proot/multi.wt/$task
  mkdir -p "$um"

  local wt start
  for base in $bases; do
    wt=$um/${base:t}
    [[ -d $wt ]] && continue
    start=HEAD
    if git -C "$base" remote get-url origin &>/dev/null; then
      git -C "$base" fetch origin --prune || return 1
      start=$(git -C "$base" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo HEAD)
    fi
    git -C "$base" worktree add "$wt" -b "$branch" "$start" || return 1
  done

  print -rl -- $bases > "$um/.aitask-repos"

  [[ -f $um/CLAUDE.local.md ]] || cat > "$um/CLAUDE.local.md" <<EOF
이 디렉터리는 멀티 레포 티켓 "$task" 전용 워크스페이스다 (각 멤버 branch $branch).

멤버 레포 (변경은 이 하위 디렉터리 안에서만, 커밋은 레포별로 각자):
$(for base in $bases; do print -r -- "- ${base:t}/"; done)

범위:
- "$task" 작업만 수행한다. 범위 밖 리팩터링 금지.
- public API / DB schema 변경 금지 (필요하면 먼저 물어볼 것).

방식:
- 먼저 관련 파일을 찾고 레포별 변경 계획을 요약한 뒤, 승인받고 수정한다.
- 완료 후 레포별 변경 파일, 테스트 결과, 리스크를 요약한다.
EOF

  _aitask_multi_tab "$um" "$task" "$title"
}

_aitask_multi_pr() {  # $1=umbrella; PR per member repo that has commits
  local um=${1%/} task=${${1%/}:t}
  [[ -f $um/.aitask-repos ]] || { print -u2 "aitask: not a multi task: $um"; return 1 }
  local -a bases=(${(f)"$(<$um/.aitask-repos)"})
  local base wt def n rc=0
  for base in $bases; do
    wt=$um/${base:t}
    [[ -d $wt ]] || continue
    def=$(git -C "$wt" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
    if [[ -n $def ]]; then
      n=$(git -C "$wt" rev-list --count "$def..HEAD" 2>/dev/null)
      if [[ $n == 0 && -z $(git -C "$wt" status --porcelain 2>/dev/null) ]]; then
        print -r -- "aitask: ${base:t}: 변경 없음 — 스킵"
        continue
      fi
    fi
    print -r -- "aitask: ${base:t}: PR 생성..."
    _aitask_pr "$wt" || rc=1
  done
  return $rc
}

_aitask_multi_drop() {  # $1=umbrella
  local um=${1%/} task=${${1%/}:t}
  [[ -f $um/.aitask-repos ]] || { print -u2 "aitask: not a multi task: $um"; return 1 }
  local -a bases=(${(f)"$(<$um/.aitask-repos)"})
  local base wt risky=0
  local -a f
  print -r -- "aitask: multi/$task"
  for base in $bases; do
    wt=$um/${base:t}
    [[ -d $wt ]] || continue
    f=("${(@ps:\t:)$(_aitask_wt_fields "$wt")}")
    printf '  %-14s branch %-24s uncommitted %-4s unpushed %-3s merged %s\n' \
      "${base:t}:" "$f[1]" "$( ((f[2])) && print yes || print no )" "${f[3]:-0}" \
      "$([[ $f[6] == 1 ]] && print yes || print no)"
    (( f[2] )) && risky=1
    (( ${f[3]:-0} > 0 )) && risky=1
  done

  local ans
  if (( risky )); then
    print -n "미보존 작업이 있습니다. 정말 삭제하려면 task 이름 '$task' 입력: "
    read -r ans
    [[ $ans == "$task" ]] || { print -u2 "aitask: aborted"; return 1 }
  else
    print -n "drop multi/$task (전 멤버 worktree/브랜치 삭제)? [y/N] "
    read -r ans
    [[ $ans == [yY]* ]] || return 1
  fi

  local branch
  for base in $bases; do
    wt=$um/${base:t}
    [[ -d $wt ]] || continue
    branch=$(git -C "$wt" branch --show-current 2>/dev/null)
    git -C "$base" worktree remove --force "$wt" || return 1
    [[ -n $branch ]] && git -C "$base" branch -D "$branch" 2>/dev/null
  done
  rm -f "$um/.aitask-repos" "$um/CLAUDE.local.md"
  rmdir "$um" 2>/dev/null
  rmdir "${um:h}" 2>/dev/null
  _aitask_close_tab "multi/$task"
  print -r -- "aitask: dropped multi/$task"
}

_aitask_menu_new() {
  local -a rows=()
  local root g base
  while IFS= read -r root; do
    root=${root/#\~/$HOME}
    for g in "$root"/*/.git(N); do
      base=${g:h}
      rows+=("$base"$'\t'"$(printf '%-28s %s' "${base:t}" "${${base:h}/#$HOME/~}")")
    done
  done < <(_aitask_roots)
  (( $#rows )) || { print -u2 "aitask: no repos under roots"; return 1 }

  local -a sels bases
  sels=(${(f)"$(print -rl -- "$rows[@]" \
        | fzf --multi --delimiter '\t' --with-nth '2..' \
              --header '레포 선택 — Tab으로 복수 선택하면 멀티 레포 task')"}) || return 0
  (( $#sels )) || return 0
  local s
  for s in $sels; do bases+=("${s%%$'\t'*}"); done

  local task
  while true; do
    print -n "task 이름 (영숫자 . _ -): "
    read -r task || return 1
    [[ -z $task ]] && return 1
    _aitask_valid_task "$task" && break
  done
  local prefix
  prefix=$(print -rl -- ${=AITASK_BRANCH_PREFIXES} \
           | fzf --header "브랜치 접두사 선택 → <접두사>/$task") || return 0
  prefix=${prefix:-$AITASK_BRANCH_PREFIX}
  local title
  print -n "탭 제목 — 에픽/피처 이름 (엔터 = 생략): "
  read -r title

  if (( $#bases >= 2 )); then
    local -a targs=()
    [[ -n $title ]] && targs=(-t "$title")
    _aitask_multi_new -p "$prefix" $targs "$task" "$bases[@]"
  else
    _aitask_new "$bases[1]" "$task" "$prefix" "$title"
  fi
}

_aitask_menu() {
  (( $+commands[fzf] )) || { print -u2 "aitask: 메뉴에는 fzf가 필요합니다 (brew install fzf)"; aitask help; return 1 }
  local -a lines multis bases rows
  lines=(${(f)"$(_aitask_status)"})
  multis=(${(f)"$(_aitask_multis)"})
  (( $#lines || $#multis )) || { _aitask_menu_new; return $? }

  local -A prmap
  local line m um mtask base br st url
  for line in $lines; do
    local f=("${(@ps:\t:)line}")
    base=${${f[3]:h}%.wt}
    (( ${bases[(Ie)$base]} )) || bases+=("$base")
  done
  for base in $bases; do
    while IFS=$'\t' read -r br st url; do
      prmap[$base@$br]=$st
    done < <(_aitask_prlist "$base")
  done

  rows=($'__new__\t[+ new task]')
  for line in $lines; do
    local f=("${(@ps:\t:)line}")
    base=${${f[3]:h}%.wt}
    local pr=${prmap[$base@${f[4]}]:-}
    rows+=("$f[3]"$'\t'"$(printf '%-30s %-24s %-16s %s' \
      "$f[1]/$f[2]" "$f[4]" "$(_aitask_flags $f[5] $f[6] $f[7] $f[8] $f[9])" "${pr:+PR:${(L)pr}}")")
  done
  for m in $multis; do
    mtask=${m%%$'\t'*}; um=${m#*$'\t'}
    local -a members=()
    local d
    for d in "$um"/*(N/); do
      git -C "$d" rev-parse --git-dir &>/dev/null && members+=("${d:t}")
    done
    rows+=("$um"$'\t'"$(printf '%-30s %s' "multi/$mtask" "[${(j:+:)members}]")")
  done

  local sel
  sel=$(print -rl -- "$rows[@]" | fzf --ansi --delimiter '\t' --with-nth '2..' \
        --header 'task 선택 → 액션 / Esc 종료' \
        --preview 'if [ -f {1}/.aitask-repos ]; then cd {1} 2>/dev/null && for d in */; do echo "== $d"; git -C "$d" -c color.status=always status --short --branch 2>/dev/null; echo; done; else git -C {1} -c color.status=always status --short --branch 2>/dev/null && echo && git -C {1} log --oneline --color=always -8 2>/dev/null || echo "새 task를 생성합니다"; fi' \
        --preview-window 'right,55%') || return 0
  local wt=${sel%%$'\t'*}
  [[ $wt == __new__ ]] && { _aitask_menu_new; return $? }

  local task=${wt:t}
  local action
  if [[ -f $wt/.aitask-repos ]]; then
    action=$(print -rl -- '탭으로 이동' 'PR 생성 (레포별 push + gh pr create --web)' 'drop — 전 멤버 worktree/브랜치 폐기' '취소' \
             | fzf --header "multi/$task") || return 0
    case $action in
      탭으로*) _aitask_multi_tab "$wt" "$task" "" ;;
      PR*)    _aitask_multi_pr "$wt" ;;
      drop*)  _aitask_multi_drop "$wt" ;;
      *)      return 0 ;;
    esac
    return
  fi

  base=${${wt:h}%.wt}
  local name=${base:t}
  action=$(print -rl -- '탭으로 이동' 'PR 생성 (push + gh pr create --web)' 'drop — worktree/브랜치 폐기' '취소' \
           | fzf --header "$name/$task") || return 0
  case $action in
    탭으로*)
      local ws
      if ws=$(_aitask_find_ws "$name/$task"); then
        CMUX_QUIET=1 cmux select-workspace --workspace "$ws" >/dev/null 2>&1
      else
        _aitask_new "$base" "$task"   # worktree/scope 존재 → 탭만 재생성
      fi ;;
    PR*)   _aitask_pr "$wt" ;;
    drop*) _aitask_drop "$base" "$task" ;;
    *)     return 0 ;;
  esac
}

_aitask_root() {
  case $1 in
    add)
      [[ -n $2 ]] || { print -u2 "usage: aitask root add <path>"; return 1; }
      local p=${2/#\~/$HOME}; p=${p:A}
      [[ -d $p ]] || { print -u2 "aitask: no such directory: $p"; return 1; }
      mkdir -p "${AITASK_ROOTS_FILE:h}"
      # seed defaults on first write so the implicit ~/github isn't lost
      [[ -f $AITASK_ROOTS_FILE ]] || _aitask_roots > "$AITASK_ROOTS_FILE"
      grep -qxF "$p" "$AITASK_ROOTS_FILE" || print -r -- "$p" >> "$AITASK_ROOTS_FILE"
      _aitask_root ls
      ;;
    ls|list|"")
      _aitask_roots
      ;;
    *)
      print -u2 "usage: aitask root <add|ls> [path]"; return 1
      ;;
  esac
}

aitask() {
  emulate -L zsh
  local cmd=$1
  case $cmd in
    new)        shift; _aitask_new "$@" ;;
    multi)      shift; _aitask_multi_new "$@" ;;
    done)       shift; _aitask_done "$@" ;;
    drop)       shift; _aitask_drop "$@" ;;
    ls|list)    _aitask_ls ;;
    root|roots) shift; _aitask_root "$@" ;;
    "")         _aitask_menu ;;
    help|-h|--help)
      cat <<'EOF'
usage:
  aitask                        # 인터랙티브 메뉴 (fzf): 탭 이동 / PR 생성 / drop / 새 task
  aitask <repo> <task> [prefix|-] [탭제목]
                                # = aitask new. branch = <prefix>/<task> (기본 task/)
                                # 탭제목 지정 시 cmux 탭이 "<repo>/<task> · <탭제목>"
                                # prefix 자리에 - 를 주면 기본 접두사 유지
  aitask new  <repo> <task> [prefix|-] [탭제목]
  aitask multi <task> <repo> <repo>... [-p prefix] [-t 탭제목]
                                # 멀티 레포 티켓: 우산 디렉터리 하나에 레포별 worktree,
                                # claude 세션 하나가 전 멤버를 봄. drop/PR은 메뉴에서
  aitask done <repo> <task>     # merge into base, remove worktree/branch, close tab
                                # (멀티 task는 done 미지원 — PR 워크플로우 사용)
  aitask drop <repo> <task>     # discard without merging
  aitask ls                     # list active tasks across all roots
  aitask root add <path>        # register a repo root
  aitask root ls                # list roots

repo: bare name is searched under every root; a path containing "/" is
used as-is. Ambiguous names across roots are reported as an error.
EOF
      ;;
    *)          _aitask_new "$@" ;;   # aitask <repo> <task>
  esac
}
