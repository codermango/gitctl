#!/usr/bin/env bash
# 冒烟测试：验证语法、bash 3.2 兼容性与基础命令行为（在临时仓库里跑，不碰真实仓库）
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/gitctl"
SOURCES=("$BIN" "$ROOT"/lib/*.sh "$ROOT"/commands/*.sh)
PASS=0; FAIL=0

ok()  { printf '  \033[32m✔\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31m✘\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# expect <描述> <期望退出码> <命令...>
expect() {
  local desc="$1" want="$2" got
  shift 2
  "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then ok "$desc"; else bad "$desc（退出码 ${got}，期望 ${want}）"; fi
}

echo "1) 语法检查"
for f in "${SOURCES[@]}"; do
  expect "bash -n $(basename "$f")" 0 bash -n "$f"
done

echo "2) bash 3.2 兼容：变量后紧跟非 ASCII 字符必须写 \${VAR}"
if perl -ne 'exit 1 if /\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]/' "${SOURCES[@]}"; then
  ok "无裸变量紧跟多字节字符"
else
  bad "存在裸变量紧跟多字节字符（bash 3.2 下会报 unbound variable），定位: perl -ne 'print \"\$ARGV:\$.: \$_\" if /\\\$[A-Za-z_][A-Za-z0-9_]*[^\\x00-\\x7F]/' <文件>"
fi

echo "3) shellcheck（未安装则跳过）"
if command -v shellcheck >/dev/null 2>&1; then
  expect "shellcheck 全部文件" 0 shellcheck -s bash "${SOURCES[@]}"
else
  printf '  − 未安装 shellcheck，跳过（brew install shellcheck）\n'
fi

echo "4) 功能冒烟（显式用 /bin/bash 3.2 执行）"
# 临时目录：一个非 git 目录 + 一个空 git 仓库
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git init -q "$TMP/repo"

expect "help"                     0 /bin/bash "$BIN" help
expect "version"                  0 /bin/bash "$BIN" --version
expect "未知命令应报错"           1 /bin/bash "$BIN" nosuchcmd
expect "clean 带参数应报错"       1 /bin/bash "$BIN" clean foo
expect "仓库外 clean 应报错"      1 /bin/bash -c "cd '$TMP' && '$BIN' clean </dev/null"
expect "仓库内非交互 clean 应报错" 1 /bin/bash -c "cd '$TMP/repo' && '$BIN' clean </dev/null"
expect "无参数默认走 clean"       1 /bin/bash -c "cd '$TMP/repo' && '$BIN' </dev/null"

# done 的测试只覆盖联网前的守卫路径，任何一条都走不到 git pull
GIT_Q=(git -c user.email=t@example.com -c user.name=t)
"${GIT_Q[@]}" init -q "$TMP/main"
"${GIT_Q[@]}" -C "$TMP/main" commit -q --allow-empty -m init
"${GIT_Q[@]}" -C "$TMP/main" branch -M main
cp -R "$TMP/main" "$TMP/feature"
"${GIT_Q[@]}" -C "$TMP/feature" checkout -q -b feature
cp -R "$TMP/feature" "$TMP/dirty"
"${GIT_Q[@]}" -C "$TMP/dirty" commit -q --allow-empty -m tracked
echo changed > "$TMP/dirty/tracked.txt"
"${GIT_Q[@]}" -C "$TMP/dirty" add tracked.txt
cp -R "$TMP/main" "$TMP/detached"
"${GIT_Q[@]}" -C "$TMP/detached" checkout -q --detach

expect "done 带参数应报错"         1 /bin/bash "$BIN" done foo
expect "仓库外 done 应报错"        1 /bin/bash -c "cd '$TMP' && '$BIN' done </dev/null"
expect "已在主分支时 done 应报错"  1 /bin/bash -c "cd '$TMP/main' && '$BIN' done </dev/null"
expect "detached HEAD done 应报错" 1 /bin/bash -c "cd '$TMP/detached' && '$BIN' done </dev/null"
expect "工作区脏时 done 应报错"    1 /bin/bash -c "cd '$TMP/dirty' && '$BIN' done </dev/null"

echo
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32m全部通过\033[0m（%s 项）\n' "$PASS"
else
  printf '\033[31m%s 项失败\033[0m / %s 项通过\n' "$FAIL" "$PASS"
  exit 1
fi
