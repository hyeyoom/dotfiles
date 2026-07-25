# aitask — git worktree + cmux tab + claude launcher
# usage:
#   aitask <repo> <task>          # = aitask new <repo> <task>
#   aitask new  <repo> <task>     # worktree + cmux tab + claude + git pane
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

# exact-title workspace lookup (find-window is substring match, "No matches" goes to stdout)
_aitask_find_ws() {
  local title=$1 line ref t
  CMUX_QUIET=1 cmux find-window "$title" 2>/dev/null | while IFS= read -r line; do
    ref=${line%%[[:space:]]*}
    [[ $ref == workspace:* ]] || continue
    t=${line#*\"}; t=${t%\"}
    # cmux prefixes the title with a single status-icon token (e.g. "⠂ ", "✳ ")
    if [[ $t == "$title" ]] || { [[ $t == *" $title" ]] && [[ ${t%" $title"} != *' '* ]] }; then
      print -r -- "$ref"; return 0
    fi
  done
  return 1
}

# resolve repo name/path -> canonical checkout dir (echoed)
_aitask_base() {
  local repo=$1 root hits=()
  if [[ $repo == */* ]]; then
    local p=${repo/#\~/$HOME}
    p=${p:A}
    [[ -d $p/.git ]] || { print -u2 "aitask: not a git repo: $p"; return 1; }
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
  local repo=$1 task=$2
  [[ -n $repo && -n $task ]] || { print -u2 "usage: aitask new <repo> <task>"; return 1; }
  _aitask_valid_task "$task" || return 1

  local base; base=$(_aitask_base "$repo") || return 1
  local name=${base:t}
  local wt=${base:h}/$name.wt/$task
  local branch=task/$task

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
  out=$(CMUX_QUIET=1 cmux new-workspace --name "$name/$task" --cwd "$wt" \
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
  local branch=task/$task

  [[ -d $wt ]] || { print -u2 "aitask: no such worktree: $wt"; return 1; }

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
  _aitask_close_tab "$name/$task"
  print -r -- "aitask: merged $branch into $(git -C "$base" branch --show-current), cleaned up"
}

_aitask_drop() {
  local repo=$1 task=$2
  [[ -n $repo && -n $task ]] || { print -u2 "usage: aitask drop <repo> <task>"; return 1; }

  local base; base=$(_aitask_base "$repo") || return 1
  local name=${base:t}
  local wt=${base:h}/$name.wt/$task
  local branch=task/$task

  [[ -d $wt ]] || { print -u2 "aitask: no such worktree: $wt"; return 1; }
  print -n "drop $wt and delete $branch? [y/N] "
  local ans; read -r ans
  [[ $ans == [yY]* ]] || return 1

  git -C "$base" worktree remove --force "$wt"
  git -C "$base" branch -D "$branch" 2>/dev/null
  _aitask_close_tab "$name/$task"
  print -r -- "aitask: dropped $name/$task"
}

# one tab-separated line per worktree:
# repo  task  wt  branch  dirty  ahead  behind  upstream  merged
_aitask_status() {
  local root wtroot wt name task branch dirty ahead behind upstream merged def
  while IFS= read -r root; do
    root=${root/#\~/$HOME}
    for wtroot in "$root"/*.wt(N/); do
      name=${${wtroot:t}%.wt}
      for wt in "$wtroot"/*(N/); do
        git -C "$wt" rev-parse --git-dir &>/dev/null || continue
        task=${wt:t}
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
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$name" "$task" "$wt" "${branch:-?}" "$dirty" "${ahead:-0}" "${behind:-0}" "$upstream" "$merged"
      done
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
  local -a lines bases
  lines=(${(f)"$(_aitask_status)"})
  (( $#lines )) || { print -r -- "aitask: no active tasks"; return 0 }
  local -A prmap
  local line base br st url
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
  for line in $lines; do
    local f=("${(@ps:\t:)line}")
    base=${${f[3]:h}%.wt}
    local pr=${prmap[$base@${f[4]}]:-}
    printf '%-14s %-26s %-24s %-18s %s\n' \
      "$f[1]" "$f[2]" "$f[4]" "$(_aitask_flags $f[5] $f[6] $f[7] $f[8] $f[9])" \
      "${pr:+PR:${(L)pr}}"
  done
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
    done)       shift; _aitask_done "$@" ;;
    drop)       shift; _aitask_drop "$@" ;;
    ls|list)    _aitask_ls ;;
    root|roots) shift; _aitask_root "$@" ;;
    help|-h|--help|"")
      cat <<'EOF'
usage:
  aitask <repo> <task>          # = aitask new <repo> <task>
  aitask new  <repo> <task>     # worktree + cmux tab + claude + git pane
  aitask done <repo> <task>     # merge into base, remove worktree/branch, close tab
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
