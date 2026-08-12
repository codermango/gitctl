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
