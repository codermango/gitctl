# shellcheck shell=bash
# git.sh — git 基础能力（只定义函数，只读本地状态，不访问网络）

# 确认当前目录在 git 仓库内
require_git_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 || die "当前目录不在 git 仓库内"
}

# 当前分支名（detached HEAD 时输出为空）
current_branch() {
  git symbolic-ref --short -q HEAD || true
}

# 已合并进 HEAD 的本地分支（换行分隔）
merged_branches() {
  git branch --merged HEAD --format='%(refname:short)' 2>/dev/null || true
}

# 本地分支列表（按最近提交排序）：分支名<TAB>最近提交时间<TAB>上游状态（如 [gone]）
local_branches() {
  git for-each-ref refs/heads --sort=-committerdate \
    --format='%(refname:short)%09%(committerdate:relative)%09%(upstream:track)'
}

# 主分支名：优先 origin/HEAD，回退到本地 main / master；都没有则返回 1
main_branch() {
  local ref b
  ref="$(git symbolic-ref --short -q refs/remotes/origin/HEAD || true)"
  if [ -n "$ref" ]; then printf '%s\n' "${ref#origin/}"; return 0; fi
  for b in main master; do
    if git show-ref --verify --quiet "refs/heads/$b"; then printf '%s\n' "$b"; return 0; fi
  done
  return 1
}

# 工作区是否有未提交改动；未跟踪文件不算，它们既不挡切分支也不受删分支影响
worktree_dirty() {
  [ -n "$(git status --porcelain --untracked-files=no)" ]
}

# 分支是否已经合入 base（对 squash / rebase 合入判定为否）
branch_merged_into() {
  git merge-base --is-ancestor "$1" "$2"
}
