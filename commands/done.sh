# shellcheck shell=bash
# done — 收工回主分支：切主分支 → git pull → 删除刚才待的那个分支

cmd_done() {
  [ $# -eq 0 ] || die "done 不接受参数"
  require_git_repo

  local branch main ans
  branch="$(current_branch)"
  [ -n "$branch" ] || die "当前处于 detached HEAD，请先切到一个分支"

  main="$(main_branch)" || die "找不到主分支（origin/HEAD 未设置，本地也没有 main / master）"
  [ "$branch" != "$main" ] || die "当前已在主分支 ${BOLD}${main}${RESET}，无需操作"

  if worktree_dirty; then
    die "工作区有未提交的改动，请先 commit 或 stash"
  fi

  info "切换到 ${BOLD}${main}${RESET}"
  if ! git switch -q "$main" 2>/dev/null && ! git checkout -q "$main"; then
    die "切换到 ${main} 失败"
  fi

  info "拉取最新提交（git pull --ff-only）"
  # pull 失败就此打住：合并状态是对着旧的主分支算的，此时删分支不安全
  if ! git pull --ff-only; then
    die "pull 失败：已停在 ${main}，分支 ${branch} 未删除"
  fi

  # 不用 git branch -d 的合并判定：它比对的是上游而非主分支，已 push 但未合入的分支会被直接放行
  if branch_merged_into "$branch" "$main"; then
    if git branch -D "$branch" >/dev/null 2>&1; then
      info "已删除分支 ${BOLD}${branch}${RESET}"
      return 0
    fi
    die "删除分支 ${branch} 失败"
  fi

  warn "${branch} 的提交不在 ${main} 上（squash / rebase 合入时也会这样）"
  printf '强制删除 %s？[y/N] ' "$branch"
  IFS= read -r ans || ans=""
  case "$ans" in
    y|Y|yes|YES) ;;
    *) info "已保留分支 ${BOLD}${branch}${RESET}"; return 0 ;;
  esac

  if git branch -D "$branch" >/dev/null 2>&1; then
    info "已强制删除分支 ${BOLD}${branch}${RESET}"
  else
    die "删除分支 ${branch} 失败"
  fi
}
