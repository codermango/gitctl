# shellcheck shell=bash
# clean — 交互式清理本地分支：空格多选，Enter 确认后删除
# 视口只画屏幕放得下的行数，光标移出时滚动；兼容 bash 3.2（不用关联数组，选中状态用 0/1 数组）

# 读一个按键并归类为动作：up / down / toggle / all / enter / quit / none
_clean_key() {
  local key rest=""
  IFS= read -rsn1 key || { printf 'quit'; return; }
  case "$key" in
    $'\033')
      # 方向键是 ESC [ A/B 三字节；单独按 ESC（1 秒内无后续字节）视为取消
      IFS= read -rsn2 -t 1 rest || true
      case "$rest" in
        '[A') printf 'up' ;;
        '[B') printf 'down' ;;
        '')   printf 'quit' ;;
        *)    printf 'none' ;;
      esac ;;
    '')  printf 'enter' ;;
    ' ') printf 'toggle' ;;
    k)   printf 'up' ;;
    j)   printf 'down' ;;
    a|A) printf 'all' ;;
    q|Q) printf 'quit' ;;
    *)   printf 'none' ;;
  esac
}

# 绘制视口内的选项 + 状态行，共 vis+1 行（读取调用方的 rows/sel/n/cur/top/vis 变量）
# shellcheck disable=SC2154
_clean_draw() {
  local i box picked=0 above below hint=""
  for ((i = 0; i < n; i++)); do
    if [ "${sel[$i]}" -eq 1 ]; then picked=$((picked + 1)); fi
  done
  for ((i = top; i < top + vis; i++)); do
    if [ "${sel[$i]}" -eq 1 ]; then box="[${GREEN}x${RESET}]"; else box='[ ]'; fi
    if [ "$i" -eq "$cur" ]; then
      printf '  \033[7m ▸ \033[0m%s \033[7m%s \033[0m\033[K\n' "$box" "${rows[$i]}"
    else
      printf '     %s %s \033[K\n' "$box" "${rows[$i]}"
    fi
  done
  above="$top"; below=$(( n - top - vis ))
  if [ "$above" -gt 0 ]; then hint=" · ↑ 上面还有 ${above} 项"; fi
  if [ "$below" -gt 0 ]; then hint="${hint} · ↓ 下面还有 ${below} 项"; fi
  printf '  \033[2m[%d/%d] 已选 %d 个%s\033[0m\033[K\n' "$(( cur + 1 ))" "$n" "$picked" "$hint"
}

# 内置多选菜单：空格切换选中，Enter 确认；选中的分支写入 CLEAN_SELECTED 数组
_clean_menu() {
  local n="${#names[@]}" sel=() cur=0 top=0 vis term_rows action i m
  for ((i = 0; i < n; i++)); do sel[$i]=0; done

  term_rows="$(tput lines 2>/dev/null || true)"
  case "$term_rows" in ''|*[!0-9]*) term_rows=24 ;; esac
  vis=$(( term_rows - 5 ))              # 预留提示行、状态行和 shell 提示符
  if [ "$vis" -lt 3 ]; then vis=3; fi
  if [ "$vis" -gt "$n" ]; then vis="$n"; fi

  info "空格选择要删除的分支，Enter 删除，a 全选，q/ESC 取消"
  printf '\033[?25l'                    # 隐藏光标；EXIT 时恢复（含 die / Ctrl+C）
  trap 'printf "\033[?25h"' EXIT

  _clean_draw
  while :; do
    action="$(_clean_key)"
    case "$action" in
      up)     cur=$(( (cur - 1 + n) % n )) ;;
      down)   cur=$(( (cur + 1) % n )) ;;
      toggle) sel[$cur]=$(( 1 - sel[cur] )) ;;
      all)
        # 还有未选中的则全选，否则全不选
        m=1
        for ((i = 0; i < n; i++)); do
          if [ "${sel[$i]}" -eq 0 ]; then m=0; break; fi
        done
        for ((i = 0; i < n; i++)); do sel[$i]=$(( 1 - m )); done ;;
      enter)
        # 没选任何分支时 Enter 不动作（状态行显示「已选 0 个」）
        m=0
        for ((i = 0; i < n; i++)); do m=$(( m + sel[i] )); done
        if [ "$m" -gt 0 ]; then break; fi ;;
      quit)
        printf '\033[%dA\033[J\033[?25h' "$(( vis + 1 ))"
        return 0 ;;
    esac
    # 光标移出视口时滚动窗口（含首尾环绕跳转）
    if [ "$cur" -lt "$top" ]; then top="$cur"; fi
    if [ "$cur" -ge $(( top + vis )) ]; then top=$(( cur - vis + 1 )); fi
    printf '\033[%dA' "$(( vis + 1 ))"  # 光标回到菜单顶部重绘
    _clean_draw
  done

  printf '\033[%dA\033[J\033[?25h' "$(( vis + 1 ))" # 清掉菜单，恢复光标
  for ((i = 0; i < n; i++)); do
    if [ "${sel[$i]}" -eq 1 ]; then CLEAN_SELECTED+=("${names[$i]}"); fi
  done
}

cmd_clean() {
  [ $# -eq 0 ] || die "clean 不接受参数"
  require_git_repo
  [ -t 0 ] || die "clean 需要交互式终端"

  # 收集本地分支与展示行（当前分支不可删除，直接排除）
  local cur_branch merged names=() rows=() name date track mark
  cur_branch="$(current_branch)"
  merged="$(merged_branches)"
  while IFS=$'\t' read -r name date track; do
    if [ -z "$name" ] || [ "$name" = "$cur_branch" ]; then continue; fi
    mark=""
    if [ "$track" = "[gone]" ]; then mark="${YELLOW}上游已删${RESET} "; fi
    if ! printf '%s\n' "$merged" | grep -qxF -- "$name"; then mark="${mark}${RED}未合并${RESET}"; fi
    names+=("$name")
    rows+=("$(printf '%-36s %s%-16s%s %s' "$name" "$DIM" "$date" "$RESET" "$mark")")
  done < <(local_branches)

  if [ "${#names[@]}" -eq 0 ]; then
    info "没有可清理的本地分支${cur_branch:+（只有当前分支 ${cur_branch}）}"
    return 0
  fi
  if [ -n "$cur_branch" ]; then
    info "当前分支 ${BOLD}${cur_branch}${RESET} 不可删除，已排除"
  fi

  CLEAN_SELECTED=()
  _clean_menu
  if [ "${#CLEAN_SELECTED[@]}" -eq 0 ]; then info "已取消"; return 0; fi

  # 列出选中项并确认后强制删除（-D；未合并分支在列表中已有标记）
  local b ans ok=0 fail=0
  printf '将删除以下 %d 个本地分支:\n' "${#CLEAN_SELECTED[@]}"
  for b in "${CLEAN_SELECTED[@]}"; do
    printf '  %s-%s %s\n' "$RED" "$RESET" "$b"
  done
  printf '确认删除？[y/N] '
  IFS= read -r ans || ans=""
  case "$ans" in y|Y|yes|YES) ;; *) info "已取消"; return 0 ;; esac

  for b in "${CLEAN_SELECTED[@]}"; do
    if git branch -D "$b" >/dev/null 2>&1; then
      printf '  %s✔%s 已删除 %s\n' "$GREEN" "$RESET" "$b"
      ok=$((ok + 1))
    else
      printf '  %s✘%s 删除失败 %s\n' "$RED" "$RESET" "$b"
      fail=$((fail + 1))
    fi
  done
  if [ "$fail" -eq 0 ]; then
    info "完成：已删除 ${ok} 个分支"
  else
    die "已删除 ${ok} 个，失败 ${fail} 个"
  fi
}
