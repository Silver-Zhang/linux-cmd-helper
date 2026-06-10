# cmd-helper：终端 AI 命令行助手（Linux + macOS）

`cmd-helper` 是面向 Linux 多用户科研服务器、同时兼容 macOS（Apple Silicon 与 Intel）的终端 AI 辅助工具。它基于 GitHub Copilot CLI 封装，默认接入 DeepSeek API，用于辅助命令生成、错误日志分析、服务器排错、命令解释、上下文记录和人工审批式命令执行。

> 跨平台说明：工具本体是一组纯 Bash 脚本，安装到当前用户目录（`~/.local/bin`、`~/.local/lib` 等），不需要 root，也不会写入 `/usr/local/bin` 等系统目录。安装脚本会自动识别 Linux（`uname -s` = `Linux`）和 macOS（`uname -s` = `Darwin`），并自动选择正确的 PATH 启动文件。除 GitHub Copilot CLI / Node / npm 外，不引入 Python、Go、Rust 等新运行时依赖。

本工具的设计目标是：

1. **不替用户直接越权执行命令**；
2. **默认不使用 sudo**；
3. **默认使用 DeepSeek Flash，兼顾速度和成本**；
4. **支持 DeepSeek Pro 和 GitHub Copilot native 模型切换**；
5. **支持连续上下文，`cmd`、`cmdx`、`cmd-chat` 共用同一个 cmd 专用 chat session**；
6. **支持命令日志、终端上下文、问题记录、回收站和定时清理**；
7. **适合在课题组服务器中由普通用户独立安装使用**。

---

## 1. 功能概览

安装后会提供以下命令：

| 命令                      | 作用                                                   |
| ----------------------- | ---------------------------------------------------- |
| `cmd`                   | 非执行型 AI 问答助手，继续当前任务上下文，回答完返回普通 shell               |
| `cmdx`                  | 审批执行型助手，AI 可提出命令，但必须用户确认后才执行                        |
| `cmd-chat`              | 进入 cmd 专用 Copilot CLI 连续对话界面                         |
| `cmd-git`               | Git 专家助手，自动读取当前仓库只读状态并给出安全的 Git 命令建议          |
| `cmd-new`               | 新开一个任务上下文（不删除旧对话）                                    |
| `cmd-resume`            | 从历史 cmd session 中选择旧任务并恢复                             |
| `cmd-context`           | 生成当前终端上下文快照                                          |
| `cmd-run`               | 执行单条命令并保存日志                                          |
| `cmd-record`            | 开启一个被记录的 shell 会话，保存后续输出                             |
| `cmd-suggest`           | 根据当前上下文和日志推荐可继续提问的问题                                 |
| `cmd-clean`             | 清理 cmd session/cache，但移动到回收站                         |
| `cmd-trash-list`        | 查看回收站内容                                              |
| `cmd-trash-empty`       | 手动永久清空回收站                                            |
| `cmd-trash-prune`       | 删除 N 天以前的回收站内容                                       |
| `cmd-trash-auto-on`     | 开启定时清理回收站                                            |
| `cmd-trash-auto-off`    | 关闭定时清理回收站                                            |
| `cmd-trash-auto-status` | 查看定时清理状态                                             |
| `cmd-model`             | 进入 GitHub Copilot native 登录/模型选择流程，并同步记录显示模型名         |
| `cmd-model-set`         | 手动记录当前 Copilot native 显示模型名                           |
| `cmd-model-current`     | 查看当前记录的模型信息                                          |
| `cmd-question`          | 查看最近一次通过 `cmd` 或 `cmdx` 提交的问题                        |
| `copilot-cmd-send`      | 内部辅助命令，用于向同一 cmd session 发送 prompt                   |

---

## 2. 安装方式

### 方式一：从 GitHub clone 安装（推荐）

```bash
git clone https://github.com/Silver-Zhang/linux-cmd-helper.git
cd linux-cmd-helper
bash install.sh
```

### 方式二：从共享服务器公共目录安装

如果所在服务器已由管理员部署了公共包（路径因服务器而异，以下为示例）：

```bash
bash /data/public/tools/linux-cmd-helper/install.sh
```

> 注意：`/data/public/tools/linux-cmd-helper` 是共享服务器的示例部署路径，不是通用 Linux 环境中必然存在的路径。请向服务器管理员确认实际路径。

安装脚本会将工具安装到当前用户自己的目录：

```bash
~/.local/bin
~/.local/lib
~/.config/copilot-deepseek
~/.config/copilot-cmd
~/.cache/copilot-cmd
~/.copilot-cmd
```

如果安装后当前 shell 找不到 `cmd`，执行：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

重新登录 SSH 后，通常会自动从 `~/.profile` 生效。

---

## 3. 前置依赖

### 3.1 GitHub Copilot CLI

本工具依赖 `copilot` 命令。检查：

```bash
which copilot
copilot --version
```

如果没有安装 GitHub Copilot CLI，需要先安装 Node.js/npm，然后安装 Copilot CLI。

如果已经安装 nvm，可执行：

```bash
npm install -g @github/copilot
```

如果没有 Node.js/npm，可先安装 nvm 和 Node.js：

```bash
cd ~

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install 22
nvm use 22
nvm alias default 22

node -v
npm -v

npm install -g @github/copilot
```

#### macOS：通过 Homebrew 安装 Node（推荐方式之一）

macOS 上最简单的方式是用 Homebrew 安装 Node，再安装 Copilot CLI：

```bash
brew install node
npm install -g @github/copilot
```

也可以使用上面的 nvm 方案（与 Linux 相同）。安装脚本只会**检测并提示**，不会自动安装 Homebrew / Node / npm / Copilot CLI。

### 3.2 其他系统命令

- `script`：`cmd-record` 依赖它。Linux 通常来自 util-linux；macOS 系统自带。缺失时 `cmd-record` 不可用，但不影响其它命令。
- `crontab`：`cmd-trash-auto-on/off/status` 依赖它。Linux 一般自带；macOS 也有，但首次使用可能需要在「系统设置 → 隐私与安全性 → 完全磁盘访问」授权 `cron`。缺失时定时清理不可用，可改用手动 `cmd-trash-prune`。

---

## 4. DeepSeek API Key 配置

`cmd-helper` 默认使用 DeepSeek API。安装脚本会提示输入 DeepSeek API Key，并保存到用户自己的私有配置文件：

```bash
~/.config/copilot-deepseek/env
```

文件内容形式为：

```bash
export COPILOT_PROVIDER_API_KEY='你的 DeepSeek API Key'
```

权限应为：

```bash
chmod 700 ~/.config/copilot-deepseek
chmod 600 ~/.config/copilot-deepseek/env
```

检查 key 是否已设置：

```bash
source ~/.config/copilot-deepseek/env
test -n "$COPILOT_PROVIDER_API_KEY" && echo "DeepSeek key is set"
```

不要执行：

```bash
echo "$COPILOT_PROVIDER_API_KEY"
```

不要把 API Key 放入：

```text
/data/public
Git 仓库
README
共享脚本
截图
聊天记录
```

如果 API Key 曾经被粘贴到聊天窗口、截图、共享文件或公共目录，应视为已经泄露，需要到 DeepSeek 控制台重置。

---

## 5. 上下文模式

`cmd` 和 `cmdx` 默认使用**最小上下文**发送给模型，节省 token 并避免信息泄露。如需更多上下文，使用以下选项显式加载：

| 选项               | 说明                                           |
| ---------------- | -------------------------------------------- |
| （默认）             | 最小上下文：pwd、user/host、backend、短安全规则摘要          |
| `-c` / `--context` | 精简上下文：pwd、git branch/status、df、last-run/last-record meta |
| `--last-run[=N]` | 精简上下文 + last-run 日志尾部（默认 200 行，可显式指定行数如 `--last-run=500`） |
| `--last-record[=N]` | 精简上下文 + last-record 日志尾部（默认 300 行，可显式指定行数如 `--last-record=500`） |
| `--full-context` | 完整上下文（调用 cmd-context，包括目录列表、终端输出日志尾部、最近 50 行 bash 历史） |

示例：

```bash
cmd "帮我解释这条命令"              # 最小上下文，省 token
cmd -c "当前 Git 有什么变更？"       # 精简上下文
cmd --last-run "分析最近运行的命令输出"  # 含 last-run 日志（默认 200 行）
cmd --last-run=500 "分析完整输出"    # 含 last-run 日志（显式 500 行）
cmd --last-record=100 "快速看日志"   # 含 last-record 日志（显式 100 行）
cmd --full-context "需要完整环境信息"   # 完整上下文
```

重要说明：

- **Recent Bash History 不会默认发送给模型**。`--full-context` 模式下发送最近 50 行（可通过 `CMD_HISTORY_LINES` 环境变量调整）。
- `--full-context` 包含：目录列表（`ls -la`）、git status、磁盘使用、bash 历史（50 行）、last-run/last-record 日志尾部。
- `cmd-context` 命令只是生成 context 文件，不代表每次 `cmd` 都会发送完整 context。
- 可通过环境变量调整日志尾部行数：`CMD_LAST_RUN_TAIL=200`、`CMD_LAST_RECORD_TAIL=300`、`CMD_HISTORY_LINES=50`。
- 也可以在命令行直接指定行数：`--last-run=500`、`--last-record=100`。

---

## 6. 基本使用

### 6.1 默认问答：DeepSeek Flash

```bash
cmd "只回答 OK"
```

默认后端：

```text
DeepSeek BYOK
deepseek-v4-flash
```

适合日常命令解释、简单排错、生成只读检查命令。

---

### 6.2 使用 DeepSeek Pro

```bash
cmd -m pro "请深入分析最近 cmd-record 的编译错误"
```

后端：

```text
DeepSeek BYOK
deepseek-v4-pro
```

适合复杂日志、编译链分析、依赖冲突分析、多步骤服务器排错。

---

### 6.3 多行输入

如果问题较长，不适合放在引号中：

```bash
cmd -
```

然后粘贴多行内容，最后按：

```text
Ctrl+D
```

示例：

```text
我刚才编译程序出现如下错误：

fatal error: hdf5.h: No such file or directory
compilation terminated.

请判断可能原因，并给出只读检查命令。
```

---

### 6.4 heredoc 输入

```bash
cmd <<'EOF'
我现在测试 heredoc。

报错如下：
/usr/bin/ld: cannot find -lTKDESTEP
collect2: error: ld returned 1 exit status

请判断这通常是什么问题，并给出只读检查命令。
EOF
```

---

### 6.5 从文件输入

```bash
cmd -f /tmp/error.log
```

也可以组合使用：

```bash
{
  echo "请分析下面这段日志，找第一个关键错误："
  echo
  tail -300 /tmp/error.log
} | cmd -
```

---

### 6.6 使用编辑器输入

```bash
cmd -e
```

默认会打开 `$EDITOR`，若未设置则使用 `nano`。编辑完成保存退出后，问题会发送给 AI。

`cmd -e` 提交的问题会保存到：

```bash
~/.cache/copilot-cmd/questions/
```

最近一次问题可查看：

```bash
cmd-question
```

---

## 7. 会话机制：`cmd`、`cmdx`、`cmd-chat`、`cmd-new` 的关系

`cmd-helper` 使用一个 cmd 专用 Copilot session 目录：

```bash
~/.copilot-cmd
```

默认设计为：

```text
cmd、cmdx、cmd-chat 会尽量共用同一个 cmd 专用 chat session。
```

也就是说，如果你连续执行：

```bash
cmd "这是第一个问题，请记住标记 ABC。"
cmdx "不需要运行命令，请回答刚才的标记是什么。"
cmd "继续刚才的问题。"
cmd-chat
```

它们会尽量进入同一条上下文链。这样可以让 AI 记住前面的问题、分析过程和你已经提供过的信息。

---

### 7.1 一直使用 `cmd` 会发生什么？

如果你一直使用：

```bash
cmd "问题1"
cmd "问题2"
cmdx "问题3"
cmd "问题4"
```

这些问题默认会进入当前最新的 cmd chat session。

这适合处理同一个连续任务，例如：

```text
排查一次编译错误
分析一次服务器权限问题
配置一个软件环境
调试一个 Slurm 作业
检查一个 Git 仓库状态
```

在这种情况下，连续上下文是有益的，因为 AI 可以利用前面已经讨论过的信息。

---

### 7.2 什么时候应该使用 `cmd-new`？

当你要切换到一个新的、无关的任务时，建议使用：

```bash
cmd-new "新任务说明"
```

例如，你刚刚完成了 RMC 编译报错排查，现在要开始处理另一个完全无关的问题：

```bash
cmd-new "现在开始一个新任务：帮我排查当前用户下 Copilot CLI 登录问题。"
```

或者：

```bash
cmd-new "现在开始一个新任务：帮我检查公共工具包的安装权限。"
```

`cmd-new` 的作用是：**新建一个新的 cmd chat session，并把后续 `cmd` / `cmdx` / `cmd-chat` 切换到这条新的上下文链上。**

---

### 7.3 `cmd-new` 会删除以前的对话吗？

不会。

`cmd-new` 只是新开一个对话和新的上下文记忆，不代表以前的对话被删除。

旧对话仍然保存在：

```bash
~/.copilot-cmd
```

如果以后想找回旧对话，可以使用：

```bash
cmd-resume
```

从历史 session 中选择恢复。

因此：

```text
cmd-new = 新开一个任务上下文
cmd-clean sessions = 清理 cmd session
```

这两个命令不是一回事。

---

### 7.4 `cmd-new`、`cmd`、`cmdx`、`cmd-chat` 的推荐用法

开始一个新任务：

```bash
cmd-new "现在开始一个新任务：我要排查 RMC 编译失败。"
```

在这个任务中继续提问：

```bash
cmd "请根据当前上下文，给我第一步只读检查命令。"
```

如果需要 AI 提出命令并由你确认执行：

```bash
cmdx "请判断是否需要检查 HDF5、MPI 或 CMake 路径，必要时提出只读命令。"
```

如果你想进入连续交互式聊天界面：

```bash
cmd-chat
```

如果这个任务结束，开始另一个任务：

```bash
cmd-new "现在开始一个新任务：我要检查 public 工具包权限问题。"
```

如果想恢复旧任务：

```bash
cmd-resume
```

---

### 7.5 `cmd-clean sessions` 与 `cmd-new` 的区别

不要把 `cmd-clean sessions` 当作“新开任务”使用。

`cmd-clean sessions` 的作用是清理当前 cmd session 数据，并移动到回收站：

```bash
cmd-clean sessions
```

它适合在你确认不需要当前 session 历史时使用。

而如果只是想换一个新任务，同时保留旧任务历史，应使用：

```bash
cmd-new "新任务说明"
```

两者区别如下：

| 命令                   | 作用                        | 是否保留旧对话     |
| -------------------- | ------------------------- | ----------- |
| `cmd "问题"`           | 继续当前最新对话                  | 保留          |
| `cmdx "问题"`          | 继续当前最新对话，并可人工审批执行命令       | 保留          |
| `cmd-chat`           | 进入当前最新对话的交互界面             | 保留          |
| `cmd-new "新任务说明"`    | 新开一个对话上下文                 | 保留旧对话       |
| `cmd-resume`         | 从历史对话中选择恢复                | 保留          |
| `cmd-clean sessions` | 清理 session，移动到回收站         | 不再作为当前可继续对话 |
| `cmd-clean all`      | 清理 session 和 cache，移动到回收站 | 不再作为当前可继续对话 |

---

### 7.6 推荐工作流

对于每个独立任务，建议这样使用：

```bash
cmd-new "任务说明"
```

然后围绕这个任务连续使用：

```bash
cmd "问题"
cmdx "需要检查时的问题"
cmd "继续分析"
```

任务完成后，如果只是切换任务：

```bash
cmd-new "下一个任务说明"
```

如果确认历史 session 已经不需要了，再清理：

```bash
cmd-clean sessions
```

如果需要恢复旧任务：

```bash
cmd-resume
```

---

### 7.7 典型示例

#### 示例 1：RMC 编译错误排查

```bash
cmd-new "新任务：排查 RMC 编译失败问题。"
cmd "请根据当前目录和最近日志，判断第一步该检查什么。"
cmdx "必要时提出只读命令，检查 HDF5、MPI 和 CMake 路径。"
cmd "我已经执行了检查命令，结果如下：..."
```

#### 示例 2：切换到公共工具包权限问题

```bash
cmd-new "新任务：排查共享服务器公共工具包普通用户安装权限问题。"
cmd "某用户安装时报 Permission denied，帮我判断原因。"
cmdx "必要时提出只读命令检查文件 owner、group、mode 和 ACL。"
```

#### 示例 3：恢复旧任务

```bash
cmd-resume
```

在列表中选择旧的 RMC 编译问题 session 后，可以继续：

```bash
cmd "继续刚才的 RMC 编译问题。"
```

---

## 8. `cmdx`：人工审批式命令执行

`cmdx` 用于处理“AI 需要运行终端命令才能判断”的问题。

示例：

```bash
cmdx "请判断当前目录是否是 Git 仓库，必要时提出只读命令"
```

流程：

```text
1. AI 判断是否需要运行命令；
2. 如果需要，会在特殊标记中提出命令；
3. 脚本展示命令；
4. 用户输入 yes 才执行；
5. 命令输出保存到日志；
6. 用户可选择是否把输出发回 AI 继续分析。
```

`cmdx` 不会自动执行 AI 建议的命令。

---

### 8.1 `cmdx` 使用 DeepSeek Pro

```bash
cmdx -m pro "请分析这个复杂编译问题，必要时提出只读检查命令"
```

---

### 8.2 `cmdx` 多行输入

```bash
cmdx -
```

粘贴多行内容后按 `Ctrl+D`。

---

### 8.3 `cmdx` 文件输入

```bash
cmdx -f /tmp/error.log
```

---

### 8.4 `cmdx` 编辑器输入

```bash
cmdx -e
```

---

### 8.5 `cmdx` 安全策略

普通命令需要输入：

```text
yes
```

才会执行。

如果检测到高风险命令，例如：

```text
sudo
rm -rf
mkfs
dd
chmod -R
chown -R
iptables
ufw
docker rm
docker system prune
shutdown
reboot
systemctl stop/restart/disable
```

则必须输入：

```text
YES I UNDERSTAND
```

才会执行。

执行记录保存到：

```bash
~/.cache/copilot-cmd/approved-runs/
```

最近一次记录：

```bash
~/.cache/copilot-cmd/last-approved-run
```

查看：

```bash
cat ~/.cache/copilot-cmd/last-approved-run/commands.sh
cat ~/.cache/copilot-cmd/last-approved-run/meta.txt
tail -200 ~/.cache/copilot-cmd/last-approved-run/output.log
```

---

### 8.6 `cmdx --loop`：多轮审批式诊断

默认 `cmdx` 是单轮审批：AI 提出命令 → 用户确认 → 执行 → 可选 follow-up 分析 → 结束。

`cmdx --loop` 是多轮审批式诊断模式：

```text
AI 分析 → 申请命令 → 用户审批 → 执行 → AI 再分析 → 再申请 → 再审批 → ...
```

每一轮仍然需要用户手动确认，不是自动执行 agent。

用法：

```bash
cmdx --loop "请帮我排查当前 Git 仓库的问题"
cmdx -L "请诊断编译错误"
cmdx --loop --max-rounds 10 "复杂问题诊断"
cmdx --loop -m pro "使用 DeepSeek Pro 多轮诊断"
cmdx --loop --copilot "使用 Copilot native 多轮诊断"
```

参数：

| 参数              | 说明                                 |
| --------------- | ---------------------------------- |
| `-L` / `--loop` | 启用多轮审批模式                           |
| `--max-rounds N`| 最大轮数（默认 5）                         |

行为说明：

1. AI 判断是否需要运行命令；
2. 如果不需要，直接输出答案并结束；
3. 如果需要，提出命令并等待用户审批；
4. 用户输入 `yes` 执行，`edit` 编辑后确认，其他输入取消并结束；
5. 执行后将结果回传 AI；
6. AI 根据结果判断是否需要下一轮；
7. 如果不需要，输出最终分析并结束；
8. 达到最大轮数后停止。

Loop 模式适合需要"运行命令 → 分析输出 → 再运行命令"的问题，例如：

- 多步骤服务器排错
- 编译依赖逐步检查
- Git 仓库状态诊断
- 权限问题逐层排查

注意：`cmdx --loop` 不是自动执行 agent。每一轮命令都必须由用户审批后才会执行。

日志结构：

```text
~/.cache/copilot-cmd/approved-runs/<timestamp>-loop/
├── loop-meta.txt
├── round-01/
│   ├── commands.sh
│   ├── meta.txt
│   └── output.log
├── round-02/
│   ├── commands.sh
│   ├── meta.txt
│   └── output.log
└── ...
```

---

## 9. `cmd-chat`：进入连续交互模式

默认进入 DeepSeek Flash：

```bash
cmd-chat
```

使用 DeepSeek Pro：

```bash
cmd-chat -m pro
```

使用 GitHub Copilot native 当前模型：

```bash
cmd-chat --copilot
```

退出：

```text
/exit
```

或按：

```text
Ctrl+C
```

注意：`cmd-chat` 会进入 Copilot CLI 交互式界面，和普通 shell 不同。如果只想问一句并回到 shell，应使用：

```bash
cmd "问题"
```

---

## 10. GitHub Copilot native 模型

默认情况下，`cmd` 和 `cmdx` 使用 DeepSeek。若要使用 GitHub Copilot 原生模型，需要先完成 native 认证。

### 10.1 进入 cmd 专用 native Copilot 环境并选择模型

```bash
cmd-model
```

进入后执行：

```text
/login
```

完成 GitHub 登录。

然后可以执行：

```text
/model
```

使用 Copilot CLI 自带菜单选择模型。

退出：

```text
/exit
```

---

### 10.2 使用 Copilot native 后端

```bash
cmd --copilot "只回答 OK"
```

```bash
cmdx --copilot "请判断当前目录是否是 Git 仓库，必要时提出只读命令"
```

```bash
cmd-chat --copilot
```

---

### 10.3 显示当前 native 模型名

Copilot CLI 的 `/model` 菜单显示名不一定能作为 `--model` 参数使用。因此 `cmd-helper` 不强行把显示名传给 `--model`。

推荐流程：

```bash
cmd-model
```

进入后：

```text
/model
```

选择模型，退出后按提示同步记录显示模型名。

也可以手动设置显示名：

```bash
cmd-model-set "GPT-5.4 mini"
```

查看当前记录：

```bash
cmd-model-current
```

之后：

```bash
cmd --copilot "问题"
```

会显示类似：

```text
[cmd] backend: GitHub Copilot native
[cmd] model:   GPT-5.4 mini
[cmd] note:    display label recorded by cmd-model; actual model is controlled by Copilot CLI /model
```

说明：这里显示的是 `cmd-helper` 记录的显示标签。实际模型选择仍由 Copilot CLI 的 `/model` 状态控制。

---

## 11. Copilot native 模型列表维护

每个用户的 Copilot native 模型列表位于：

```bash
~/.config/copilot-cmd/copilot-models
```

该文件只用于 `cmd-model` 的显示和同步记录，不决定 Copilot 实际可用模型。

如果 GitHub Copilot CLI 后续新增、删除或重命名模型，请用户自行编辑：

```bash
nano ~/.config/copilot-cmd/copilot-models
```

示例：

```text
Auto
Claude Sonnet 4.6
Claude Sonnet 4.5
Claude Haiku 4.5
Claude Opus 4.8
Claude Opus 4.7
Claude Opus 4.6
Claude Opus 4.5
GPT-5.5
GPT-5.4
GPT-5.3-Codex
GPT-5.2-Codex
GPT-5.2
GPT-5.4 mini
GPT-5 mini
GPT-4.1
```

公共安装包不会覆盖用户已有的：

```bash
~/.config/copilot-cmd/copilot-models
```

因此模型列表更新由每个用户手动维护。

---

## 12. `cmd-context`：上下文快照

```bash
cmd-context
```

会生成当前终端上下文快照，包括：

```text
当前时间
当前用户
当前主机
当前路径
当前 shell
当前目录文件列表
Git 状态
Git remote
当前目录磁盘占用
最近 Bash history
最近 cmd-run 信息
最近 cmd-record 信息
```

生成路径类似：

```bash
~/.cache/copilot-cmd/contexts/20260530-190000/context.md
```

同时更新软链接：

```bash
~/.cache/copilot-cmd/latest-context
```

`cmd-context` 每次生成新的 timestamp 目录，不覆盖旧 context。

---

## 13. `cmd-run`：记录单条命令

```bash
cmd-run make -j32
```

作用：

```text
1. 正常执行命令；
2. 实时显示输出；
3. 同时保存 stdout/stderr；
4. 记录退出码、时间、当前目录、主机和用户；
5. 更新 last-run。
```

日志目录示例：

```bash
~/.cache/copilot-cmd/runs/20260530-190000-make/
├── command.txt
├── meta.txt
└── output.log
```

最近一次：

```bash
~/.cache/copilot-cmd/last-run
```

之后可以问：

```bash
cmd "请分析最近 cmd-run 的 output.log，找第一个关键错误"
```

---

## 14. `cmd-record`：记录一段 shell 会话

当你不知道哪条命令会报错，不想事后重跑长命令，可以先进入记录模式：

```bash
cmd-record
```

进入后正常使用 shell：

```bash
make -j32
ctest
python test.py
```

退出记录 shell：

```bash
exit
```

日志保存到：

```bash
~/.cache/copilot-cmd/records/
```

最近一次：

```bash
~/.cache/copilot-cmd/last-record
```

之后：

```bash
cmd "请分析最近 cmd-record 日志中的第一个关键错误"
```

注意：如果没有使用 `cmd-record`、`cmd-run`、`tee` 或手动粘贴报错，普通脚本无法事后读取已经滚过屏幕的终端输出。

### 14.1 平台差异（Linux vs macOS）

`cmd-record` 在不同平台调用的 `script` 实现不同，已自动处理：

- **Linux**：使用 util-linux 版 `script`，调用 `script -q -f <log> -c "$SHELL -i"`，可指定要运行的命令。
- **macOS**：使用系统自带的 BSD 版 `script`（不支持 `-f` / `-c`），调用 `script -q <log>`。它会启动一个交互式 shell（你的 `$SHELL`，默认 zsh）并记录整个会话，输入 `exit` 结束。

两个平台保存的日志位置一致（`~/.cache/copilot-cmd/records/`），后续 `cmd "..."` 的分析方式也一致。

---

## 15. `cmd-suggest`：推荐可继续提问的问题

```bash
cmd-suggest
```

它会读取当前 context、最近 run/record 日志，并推荐 5 个可继续提问的问题。

操作：

```text
1-5  发送对应问题到当前 cmd session
r    换一批问题
q    退出
回车 退出
```

示例输出：

```text
[1] 请分析最近 cmd-record 日志中的第一个关键错误
[2] 请判断当前错误是否与 HDF5、MPI 或 CMake 路径有关
[3] 请给出只读命令检查依赖库路径
[4] 请解释最近一次命令的退出码
[5] 请根据当前 Git 状态判断是否有未提交修改影响构建
```

`cmd-suggest` 默认使用 DeepSeek Flash。它只负责推荐问题，不执行命令。

---

## 16. 清理机制

### 16.1 清理 cmd session

```bash
cmd-clean sessions
```

或：

```bash
cmd-clean
```

清理：

```bash
~/.copilot-cmd/session-state
```

不会移动整个：

```bash
~/.copilot-cmd
```

因此不会主动清除 GitHub Copilot native 登录认证。

清理内容会移动到：

```bash
~/.copilot-cmd-trash
```

---

### 16.2 清理 cache

```bash
cmd-clean cache
```

清理：

```bash
~/.cache/copilot-cmd
```

包括：

```text
contexts
runs
records
questions
suggestions
approved-runs
last-run
last-record
last-question
latest-context
```

会移动到：

```bash
~/.cache/copilot-cmd-trash
```

---

### 16.3 全部清理

```bash
cmd-clean all
```

等价于：

```bash
cmd-clean sessions
cmd-clean cache
```

不会主动删除 DeepSeek API Key 配置：

```bash
~/.config/copilot-deepseek/env
```

不会主动删除 Copilot native 显示模型配置：

```bash
~/.config/copilot-cmd
```

---

## 17. 回收站管理

查看回收站：

```bash
cmd-trash-list
```

永久清空全部回收站：

```bash
cmd-trash-empty
```

只清空 session 回收站：

```bash
cmd-trash-empty sessions
```

只清空 cache 回收站：

```bash
cmd-trash-empty cache
```

执行永久清空时，需要输入：

```text
yes
```

才会删除。

---

### 17.1 按天数清理回收站

默认清理 30 天以前内容：

```bash
cmd-trash-prune
```

清理 7 天以前内容：

```bash
cmd-trash-prune 7
```

清理 90 天以前内容：

```bash
cmd-trash-prune 90
```

---

### 17.2 定时清理回收站

默认每天 3:30 清理 30 天以前的回收站内容：

```bash
cmd-trash-auto-on
```

保留 7 天：

```bash
cmd-trash-auto-on 7
```

查看状态：

```bash
cmd-trash-auto-status
```

关闭：

```bash
cmd-trash-auto-off
```

> 平台说明：定时清理依赖 `crontab`。
> - Linux 一般自带 `crontab`。
> - macOS 也有 `crontab`，但 `cron` 首次运行可能需要在「系统设置 → 隐私与安全性 → 完全磁盘访问」中授权。
> - 如果系统没有 `crontab`，`cmd-trash-auto-on/off` 会给出清晰错误并退出，`cmd-trash-auto-status` 会提示不可用。此时请改用手动清理：
>
> ```bash
> cmd-trash-prune 30 all
> ```

---

## 18. 推荐使用场景

### 18.1 解释命令

```bash
cmd "解释这条命令：find /data/users -maxdepth 3 -type d -writable 2>/dev/null"
```

---

### 18.2 生成只读检查命令

```bash
cmd "我想检查当前用户是否能写入其他用户 workspace，给我只读命令"
```

---

### 18.3 编译报错分析

如果已经有日志：

```bash
cmd -f /tmp/build.log
```

如果预期接下来可能报错：

```bash
cmd-record
make -j32
exit

cmd "请分析最近 cmd-record 日志中的第一个关键错误"
```

---

### 18.4 需要执行检查命令

```bash
cmdx "请判断当前目录是否是 Git 仓库，必要时提出只读检查命令"
```

如果 AI 提出命令，审查后输入：

```text
yes
```

---

### 18.5 连续对话

```bash
cmd "这是第一条问题，请记住标记 CMDCTX_ALPHA"
cmdx -m pro "请回答上一条问题里的标记是什么，不需要运行命令"
cmd-chat
```

进入后可以继续追问。

---

## 19. 文件与目录说明

用户安装后主要涉及：

```text
~/.local/bin/
  cmd-helper 命令脚本

~/.local/lib/
  copilot-cmd-env.sh

~/.config/copilot-deepseek/env
  用户自己的 DeepSeek API Key

~/.config/copilot-cmd/
  Copilot native 模型显示列表、当前显示模型记录

~/.copilot-cmd/
  cmd 专用 Copilot session 和 native 登录状态

~/.cache/copilot-cmd/
  context、run 日志、record 日志、问题记录、suggestion、approved-runs

~/.copilot-cmd-trash/
  session 回收站

~/.cache/copilot-cmd-trash/
  cache 回收站
```

公共安装包目录（示例，实际路径因服务器而异）：

```bash
/data/public/tools/linux-cmd-helper
```

公共目录不应存放任何用户密钥或用户 session。

---

## 20. 更新方式

如果从 GitHub clone 安装，拉取最新代码后重新执行：

```bash
git pull
bash install.sh
```

如果从共享服务器公共目录安装，公共包更新后重新执行（路径以实际部署为准）：

```bash
bash /data/public/tools/linux-cmd-helper/install.sh
```

安装脚本会覆盖：

```text
~/.local/bin 中的工具脚本
~/.local/lib/copilot-cmd-env.sh
```

但会保留用户已有的：

```text
~/.config/copilot-deepseek/env
~/.config/copilot-cmd/copilot-models
```

也就是说，用户自己的 API Key 和模型列表不会被公共包覆盖。

---

## 21. 卸载方式

如果从 GitHub clone 安装，在仓库目录执行：

```bash
bash uninstall.sh
```

如果从共享服务器公共目录安装（路径以实际部署为准）：

```bash
bash /data/public/tools/linux-cmd-helper/uninstall.sh
```

卸载脚本会删除安装到：

```bash
~/.local/bin
~/.local/lib
```

中的工具脚本。

卸载时会询问是否删除用户配置、session 和 cache。若选择保留，则 API Key、日志、session 不会删除。

---

## 22. 安全注意事项

1. 不要使用 `sudo cmd`、`sudo cmdx`、`sudo cmd-chat`。
2. 不要在 `/`、`/etc`、`/usr`、`/data/public` 或其他用户目录中随意运行 AI agent。
3. `cmdx` 中 AI 提出的命令必须人工审查后再确认执行。
4. DeepSeek API Key 只应保存在用户自己的 `~/.config/copilot-deepseek/env`。
5. 公共安装包中不得包含任何真实 API Key。
6. `cmd-clean` 默认只移动到回收站，不直接永久删除。
7. `cmd-trash-empty` 才会永久删除回收站内容。
8. Copilot native 模型列表由用户自行维护，公共包不会强制更新。

---

## 23. 终端输出美化

`cmd` 和 `cmdx` 在交互式终端中默认启用轻量美化输出，包括：

- 模型信息、问题预览、AI 回答、命令审批和执行输出之间有清晰分界；
- 等待模型响应时显示 spinner 动画；
- `cmdx --loop` 每轮显示清晰的 round header。

### 环境变量控制

| 环境变量 | 效果 |
| --- | --- |
| `CMD_PLAIN=1` | 关闭所有美化（颜色、spinner、box 样式），使用纯文本输出 |
| `CMD_NO_SPINNER=1` | 只关闭 spinner，保留轻量分隔线和样式 |
| `NO_COLOR=1` | 关闭颜色输出（兼容 [no-color.org](https://no-color.org) 标准） |

示例：

```bash
CMD_PLAIN=1 cmd "问题"
CMD_NO_SPINNER=1 cmdx "问题"
NO_COLOR=1 cmd "问题"
```

### 管道 / 重定向自动退化

当 stdout 不是交互式终端时（管道或重定向），美化自动关闭，输出为纯文本：

```bash
cmd "问题" > out.txt       # 纯文本，无 ANSI 控制符
cmd "问题" | tee out.txt   # 纯文本
cmd "问题" | glow -        # 可配合 glow 渲染 Markdown
```

`glow` 不是本项目依赖，但用户可自行安装使用。

---

## 24. 常见问题

### 24.1 `cmd: command not found`

当前 shell 临时执行：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

确认：

```bash
which cmd
```

重新登录 SSH 后通常自动生效。

---

### 24.2 `copilot: command not found`

说明 GitHub Copilot CLI 未安装。安装：

```bash
npm install -g @github/copilot
```

如果没有 npm，先安装 nvm 和 Node.js。

---

### 24.3 DeepSeek 认证失败

检查：

```bash
ls -l ~/.config/copilot-deepseek/env
source ~/.config/copilot-deepseek/env
test -n "$COPILOT_PROVIDER_API_KEY" && echo "DeepSeek key is set"
```

不要打印 key 本体。

---

### 24.4 GitHub Copilot native 报 `No authentication information found`

进入 cmd 专用 native Copilot 环境：

```bash
cmd-model
```

`cmd-model` 会进入 GitHub Copilot CLI 原生界面。进入后可以执行 `/login` 完成认证，也可以执行 `/model` 选择模型。退出后，脚本会提示你同步记录一个“显示用模型名”，用于之后在 `cmd --copilot`、`cmdx --copilot`、`cmd-chat --copilot` 中显示当前模型。

输入：

```text
/login
```

完成登录后测试：

```bash
cmd --copilot "只回答 OK"
```

---

### 24.5 `cmd --copilot -m "GPT-5 mini"` 报模型不可用

Copilot `/model` 菜单显示名不一定能作为 `--model` 参数使用。推荐做法：

```bash
cmd-model
```

在里面使用：

```text
/model
```

选择模型后退出，并同步显示模型名。

之后使用：

```bash
cmd --copilot "问题"
```

而不是强行传：

```bash
cmd --copilot -m "GPT-5 mini" "问题"
```

---

### 24.6 `cmd-new` 或 `cmd-chat` 进入了交互界面

当前推荐使用：

```bash
cmd "问题"
```

进行非交互式问答。
只有明确想进入连续聊天界面时才使用：

```bash
cmd-chat
```

---

## 25. 维护者说明

以下说明适用于在共享服务器上维护公共部署包的管理员。公共包路径因服务器而异，以下以 `/data/public/tools/linux-cmd-helper` 为示例。

公共包结构建议：

```text
/data/public/tools/linux-cmd-helper/
├── VERSION
├── README.md
├── install.sh
├── uninstall.sh
├── bin/
├── lib/
└── config/
```

发布当前用户已调好的版本到公共目录时，可执行：

```bash
PUB="/data/public/tools/linux-cmd-helper"

mkdir -p "$PUB/bin" "$PUB/lib" "$PUB/config"

for f in \
  cmd cmdx cmd-chat cmd-context cmd-run cmd-record cmd-suggest cmd-clean \
  cmd-trash-list cmd-trash-empty cmd-trash-prune cmd-trash-auto-on cmd-trash-auto-off \
  cmd-trash-auto-status cmd-model cmd-model-set cmd-model-current cmd-question \
  cmd-new cmd-resume cmd-git copilot-cmd-send
do
  if [ -f "$HOME/.local/bin/$f" ]; then
    cp -a "$HOME/.local/bin/$f" "$PUB/bin/"
  else
    echo "WARNING: missing ~/.local/bin/$f"
  fi
done

cp -a "$HOME/.local/lib/copilot-cmd-env.sh" "$PUB/lib/"

date '+cmd-helper-%Y%m%d-%H%M%S' > "$PUB/VERSION"

chmod -R a+rX "$PUB"
find "$PUB/bin" "$PUB/lib" -type f -exec chmod 755 {} \;
chmod 755 "$PUB/install.sh" "$PUB/uninstall.sh"
chmod 644 "$PUB/README.md"
```

不要把任何真实 API Key 放进公共包。

---

## 26. 最小测试流程

安装完成后，建议每个用户测试：

```bash
cmd "只回答 OK"
```

```bash
cmd -m pro "只回答 OK"
```

```bash
cmdx "请判断当前目录是否是 Git 仓库，必要时提出只读命令"
```

```bash
cmd-git status
```

```bash
cmd-suggest
```

如需测试 native Copilot：

```bash
cmd-model
```

进入后：

```text
/login
/model
/exit
```

然后：

```bash
cmd --copilot "只回答 OK"
```

---

## 27. `cmd-git`：Git 专家助手

`cmd-git` 是一个专门的 Git 辅助命令。它不是简单地调用 `cmd "git 问题"`，而是一个能够**自动感知当前 Git 仓库状态**、预测用户下一步意图、提供专业且安全的 Git 命令建议的智能 Git 助手。

它会：

1. 自动读取当前仓库的**只读** Git 状态；
2. 判断用户下一步最可能要做的操作；
3. 给出准确、清晰、可复制的 Git 命令建议；
4. 解释 Git 概念和当前状态；
5. **默认不执行任何会修改仓库或远程状态的 Git 命令**。

### 27.1 自动读取的只读状态

`cmd-git` 只执行只读 Git 命令来收集上下文，例如：

```text
git rev-parse --is-inside-work-tree
git rev-parse --show-toplevel
git status --short --branch
git branch --show-current
git remote -v
git log --oneline --decorate --graph -20
git diff --stat
git diff --cached --stat
git stash list
```

如果存在 upstream，还会收集 ahead/behind 计数。

为避免泄露敏感内容或发送过长内容，`cmd-git` **默认不发送完整 `git diff`**，只发送 `--stat` 概要。

UI 会清晰显示当前仓库、分支、upstream、ahead/behind、是否有暂存/未暂存修改、是否有冲突、当前模型后端，以及你的问题或选择项。

### 27.2 用法

不带参数时进入交互式菜单：

```bash
cmd-git
```

```text
请选择你想做什么：

1) 解释当前 Git 状态
2) 判断我下一步最可能该做什么
3) 我想提交当前修改
4) 我想推送到远程仓库
5) 我想拉取远程更新
6) 我想查看这次改了什么
7) 我想撤销某些修改
8) 我想解决冲突
9) 我想切换或创建分支
10) 我想整理提交历史
q) 退出
```

带自然语言问题时，会自动附带当前 Git 状态：

```bash
cmd-git "我现在为什么 push 失败？"
cmd-git "我应该 git pull 还是 git push？"
cmd-git "如何撤销 README.md 的修改但保留其他文件？"
```

也支持一组明确的子命令：

```bash
cmd-git status     # 解释当前 Git 状态
cmd-git next       # 预测下一步最可能操作
cmd-git diff       # 总结当前修改
cmd-git commit     # 指导如何提交，并可生成 commit message
cmd-git push       # 判断是否适合 push，并说明命令
cmd-git pull       # 判断是否适合 pull，并说明风险
cmd-git undo       # 撤销向导
cmd-git conflict   # 冲突解决助手
cmd-git branch     # 分支管理助手
cmd-git stash      # stash 使用助手
cmd-git remote     # remote / upstream 诊断助手
cmd-git log        # 提交历史解释助手
cmd-git pr         # Pull Request / GitHub 协作建议
```

### 27.3 模型后端

`cmd-git` 复用与 `cmd` / `cmdx` 一致的模型选择语义：

```bash
cmd-git "问题"                    # 默认 DeepSeek Flash
cmd-git -m pro "问题"             # DeepSeek Pro
cmd-git --copilot "问题"          # GitHub Copilot native 当前/default 模型
cmd-git --copilot -m <ID> "问题"  # 显式 Copilot 内部模型 ID
```

### 27.4 非 Git 仓库

如果当前目录不是 Git 仓库，`cmd-git` 会给出友好提示，而不会崩溃：

```text
当前目录不是 Git 仓库。
如果你想初始化仓库，可使用：
git init
如果你想进入已有仓库，请 cd 到包含 .git 的目录。
```

### 27.5 安全说明

1. `cmd-git` 默认只执行只读 Git 命令；
2. 它不会自动执行 `git add`、`git commit`、`git push`、`git pull`、`git reset`、`git clean`、`git rebase` 等修改性命令；
3. 对修改性命令只给出建议和解释；
4. 对高风险命令（如 `git reset --hard`、`git clean -fd`、`git push --force`、`git rebase`、`git checkout -- .`、`git restore .`）会明确警告；
5. 默认不会建议 `--force`，除非你明确要求并已了解风险。

### 27.6 与 `cmdx` 的关系

`cmd-git` 与 `cmd` 一样，只负责**分析和建议**，永远不会自动执行命令。

如果你确认要执行 `cmd-git` 给出的某条命令，可以：

- 手动复制命令到终端执行；或
- 使用 `cmdx` 进行人工审批式执行（`cmdx` 会先展示命令，等你确认后才执行，高风险命令需要强确认）。

---

## 28. 推荐日常用法总结

普通问题：

```bash
cmd "问题"
```

复杂问题：

```bash
cmd -m pro "问题"
```

长文本：

```bash
cmd -
```

编辑器输入：

```bash
cmd -e
```

需要 AI 提出命令并人工审批执行：

```bash
cmdx "问题"
```

记录一段 shell：

```bash
cmd-record
```

进入连续聊天：

```bash
cmd-chat
```

Git 状态分析与命令建议：

```bash
cmd-git
```

清理 session：

```bash
cmd-clean sessions
```

清理全部工作缓存并移动到回收站：

```bash
cmd-clean all
```

查看回收站：

```bash
cmd-trash-list
```
