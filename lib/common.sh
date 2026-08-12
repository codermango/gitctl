# shellcheck shell=bash
# common.sh — 日志、颜色
# 只定义常量与函数，由 bin/gitctl 统一 source，不可独立执行

# shellcheck disable=SC2034  # 颜色常量供其他模块使用
RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'

info() { printf '%s==>%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s警告:%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%s错误:%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
