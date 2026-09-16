# gitctl — Git 日常操作助手

两个子命令：

- `gitctl clean` 交互式清理本地分支：列出当前仓库的本地分支，空格多选，Enter 确认后删除。
  列表按最近提交排序，并标注「上游已删」（远端分支已被删除）和「未合并」，方便判断哪些能安全删。
- `gitctl done` 收工回主分支：切到主分支 → `git pull --ff-only` → 删除刚才待的那个分支。

## 项目结构

```
gitctl/
├── bin/gitctl          # 入口：加载模块、解析参数、分发子命令
├── lib/                # 基础能力，单一职责一个模块（只定义函数）
│   ├── common.sh       #   日志、颜色
│   └── git.sh          #   git 只读查询（分支列表、合并状态等）
├── commands/           # 子命令实现，一个命令一个文件（cmd_* 函数）
│   ├── clean.sh        #   交互式多选删除本地分支
│   └── done.sh         #   回主分支、pull、删掉刚才的分支
├── test/smoke.sh       # 冒烟测试（语法 + bash 3.2 兼容 + 功能）
└── Makefile            # make install / make test
```

修改指南：加子命令 → `commands/` 新建文件写 `cmd_<名字>()`，在 `bin/gitctl` 的 `main()` 加一行分发；
git 查询逻辑 → 只动 `lib/git.sh`。

## 安装

```bash
# 安装到 PATH（软链接到 /opt/homebrew/bin）
make install
```

## 使用

在任意 git 仓库目录下：

```bash
gitctl            # 等价于 gitctl clean
gitctl done       # 在某个功能分支上收工时用
```

### clean

按键：

| 按键 | 作用 |
|---|---|
| ↑/↓ 或 k/j | 移动光标 |
| 空格 | 选中 / 取消当前分支 |
| a | 全选 / 全不选 |
| Enter | 删除选中的分支（会先列出并要求 y 确认） |
| q / ESC | 取消退出 |

说明：

- 当前分支不可删除，已自动从列表排除
- 删除用 `git branch -D`（强制），所以「未合并」的分支也能删——确认前看清标记
- 只读本地状态，不访问网络；「上游已删」来自本地已知的跟踪信息，`git fetch --prune` 后更准确

### done

在非主分支上执行，依次完成：切到主分支 → `git pull --ff-only` → 删除原来所在的分支。

说明：

- 主分支取 `origin/HEAD` 的指向；没有设置时回退到本地的 `main`，再回退到 `master`
- 下列情况会直接报错退出，不做任何改动：已经在主分支上、detached HEAD、工作区有未提交改动（未跟踪文件不算）
- `pull` 用 `--ff-only`，避免在主分支上凭空产生一个合并提交；`pull` 失败时停在主分支，不删分支
- 是否安全删除用 `git merge-base --is-ancestor <分支> <主分支>` 判断，而不是 `git branch -d`（后者比对的是上游分支，
  已 push 但未合入的分支会被直接删掉）。提交不在主分支上时会先提示，确认后才强制删除
- squash / rebase 合入的分支同样会命中上面的提示，看清楚再按 y
- 非交互环境（管道、脚本）下那个提示读到空输入，等于回答 n：分支会保留，但切分支和 `pull` 已经做完了

## 开发

```bash
make test    # 冒烟测试：语法检查、bash 3.2 兼容扫描、shellcheck（如已装）、功能冒烟
```

约定（与 dbctl 一致）：

- 兼容 macOS 自带 bash 3.2 —— 不用关联数组、`${var,,}` 等 4.x 特性
- **变量后紧跟中文字符必须写 `${VAR}`**（bash 3.2 会把多字节字符首字节吞进变量名），`make test` 会自动扫描
- `lib/` 与 `commands/` 文件只定义函数，不产生副作用；副作用只发生在 `bin/gitctl` 的 `main()`
