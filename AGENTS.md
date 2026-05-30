# AGENTS.md

# linux-cmd-helper 项目维护说明

本文档面向 GitHub Copilot Agent、Copilot Coding Agent、Codex、Claude Code 或其他参与本仓库维护的 AI 编程代理。
所有代理在修改本项目之前，应优先阅读并遵守本文件、`README.md`、`SECURITY.md`、`CONTRIBUTING.md` 和 `CHANGELOG.md`。

---

## 1. 项目定位

`linux-cmd-helper` 是一个面向 Linux 多用户服务器终端的轻量级 AI 命令行助手封装工具。

本项目基于 GitHub Copilot CLI 进行封装，支持：

1. DeepSeek BYOK 后端；
2. GitHub Copilot native 后端；
3. 非侵入式终端问答；
4. 人工审批式命令执行；
5. 终端上下文快照；
6. 单条命令日志记录；
7. shell 会话记录；
8. AI 推荐后续问题；
9. cmd 专用 chat session；
10. session/cache/trash 清理机制；
11. 多用户服务器上的 per-user 安全隔离。

项目的核心目标不是让 AI 自动控制服务器，而是让 AI 在用户可审查、可确认、可回滚的边界内辅助 Linux 命令行工作。

---

## 2. 核心设计原则

所有修改必须遵守以下原则。

### 2.1 安全优先

本项目运行在多用户 Linux 服务器环境中。任何功能设计都必须默认安全。

必须遵守：

1. 不要默认使用 `sudo`；
2. 不要默认访问其他用户目录；
3. 不要自动执行破坏性命令；
4. 不要绕过用户确认执行命令；
5. 不要将 API Key、GitHub token、SSH 私钥或任何凭据写入仓库；
6. 不要把用户 prompt、命令输出、运行日志或 Copilot session 提交到仓库；
7. 不要在公共目录中保存用户私有配置；
8. 不要把服务器特定路径硬编码到核心脚本中。

高风险命令包括但不限于：

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
docker rmi
docker system prune
shutdown
reboot
systemctl stop
systemctl restart
systemctl disable
```

如果功能需要支持高风险操作，必须明确要求用户输入强确认，例如：

```text
YES I UNDERSTAND
```

### 2.2 用户审批式执行

`cmdx` 是本项目中唯一允许执行 AI 建议命令的入口。

`cmdx` 必须保持以下语义：

1. AI 只能提出建议命令；
2. 脚本必须先展示命令；
3. 用户输入 `yes` 后才执行普通命令；
4. 用户输入 `YES I UNDERSTAND` 后才执行高风险命令；
5. 执行记录必须保存到 `~/.cache/copilot-cmd/approved-runs/`；
6. 执行结果应可选择是否回传给 AI 继续分析。

严禁把 `cmd`、`cmd-chat`、`cmd-suggest` 改成自动执行命令。

### 2.3 非侵入式优先

`cmd` 的定位是：

```text
问一句，回答完，回到普通 shell。
```

不要让 `cmd` 默认进入 Copilot CLI 交互界面。
需要进入交互界面时，应使用：

```bash
cmd-chat
```

### 2.4 同一任务上下文

`cmd`、`cmdx`、`cmd-chat` 应尽量共享同一个 cmd 专用 chat session。

当前设计目标是：

```text
cmd       非执行型问答，继续当前 cmd session
cmdx      审批执行型问答，继续当前 cmd session
cmd-chat  进入当前 cmd session 的交互界面
cmd-new   新开一个 cmd session，用于开始新任务
cmd-resume 恢复历史 cmd session
```

不要将 `cmd-new` 设计为删除旧会话。
`cmd-new` 的含义是“新开任务上下文”，不是“清理历史”。

清理历史应使用：

```bash
cmd-clean sessions
```

---

## 3. 目录结构

当前项目推荐结构如下：

```text
linux-cmd-helper/
├── README.md
├── LICENSE
├── SECURITY.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── VERSION
├── install.sh
├── uninstall.sh
├── bin/
│   ├── cmd
│   ├── cmdx
│   ├── cmd-chat
│   ├── cmd-new
│   ├── cmd-resume
│   ├── cmd-context
│   ├── cmd-run
│   ├── cmd-record
│   ├── cmd-suggest
│   ├── cmd-clean
│   ├── cmd-trash-list
│   ├── cmd-trash-empty
│   ├── cmd-trash-prune
│   ├── cmd-trash-auto-on
│   ├── cmd-trash-auto-off
│   ├── cmd-trash-auto-status
│   ├── cmd-model
│   ├── cmd-model-set
│   ├── cmd-model-current
│   ├── cmd-question
│   └── copilot-cmd-send
├── lib/
│   └── copilot-cmd-env.sh
├── config/
│   └── copilot-models
├── docs/
│   └── server-deployment.md
└── .github/
    └── workflows/
        └── shell-syntax.yml
```

如果仓库中缺少 `cmd-new`、`cmd-resume` 或其他 README 中已经声明的命令，应优先补齐或修正文档，不要让文档与实际脚本不一致。

---

## 4. 关键命令语义

### 4.1 `cmd`

用途：非执行型 AI 问答。

典型用法：

```bash
cmd "解释这条命令"
cmd -m pro "分析复杂日志"
cmd --copilot "使用 GitHub Copilot native 当前模型回答"
cmd -
cmd -e
cmd -f /tmp/error.log
```

要求：

1. 默认使用 DeepSeek Flash；
2. `-m pro` 使用 DeepSeek Pro；
3. `--copilot` 使用 GitHub Copilot native 当前/default 模型；
4. 不自动执行命令；
5. 回答完返回普通 shell；
6. 每次应显示当前调用后端和模型；
7. 应保存用户问题到 `~/.cache/copilot-cmd/questions/`；
8. 应支持短文本、多行 stdin、文件输入和编辑器输入。

### 4.2 `cmdx`

用途：审批执行型 AI 助手。

典型用法：

```bash
cmdx "必要时提出只读检查命令"
cmdx -m pro "分析复杂问题，必要时提出检查命令"
cmdx --copilot "使用 Copilot native 分析并提出命令"
cmdx -
cmdx -e
cmdx -f /tmp/error.log
```

要求：

1. AI 通过特殊标记提出命令；
2. 用户确认后才执行；
3. 支持 `yes`、`edit`、取消；
4. 高风险命令必须强确认；
5. 执行命令和输出保存到 `approved-runs`；
6. 执行结果可回传给 AI 继续分析；
7. 必须与 `cmd` 使用同一个 cmd session。

### 4.3 `cmd-chat`

用途：进入 cmd 专用交互式 Copilot CLI。

典型用法：

```bash
cmd-chat
cmd-chat -m pro
cmd-chat --copilot
```

要求：

1. 默认 DeepSeek Flash；
2. 支持 DeepSeek Pro；
3. 支持 GitHub Copilot native；
4. 优先进入当前 cmd session；
5. 不应误清理 session；
6. 退出方式通常为 `/exit` 或 `Ctrl+C`。

### 4.4 `cmd-new`

用途：新开一个 cmd chat session，用于开始新任务。

典型用法：

```bash
cmd-new "新任务：排查 RMC 编译失败"
cmd-new "新任务：检查 public 工具包权限"
```

要求：

1. 新建新的任务上下文；
2. 不删除旧对话；
3. 后续 `cmd`、`cmdx`、`cmd-chat` 应进入新的 session；
4. 旧 session 应可通过 `cmd-resume` 恢复。

### 4.5 `cmd-resume`

用途：从历史 cmd session 中选择旧任务并恢复。

要求：

1. 不删除当前或旧 session；
2. 调用 Copilot CLI 的 resume 能力；
3. 应使用 cmd 专用 `COPILOT_HOME`。

### 4.6 `cmd-context`

用途：生成当前终端上下文快照。

应包括：

1. 当前用户；
2. 当前主机；
3. 当前路径；
4. shell；
5. 当前目录列表；
6. Git 状态；
7. Git remote；
8. 磁盘信息；
9. 最近 bash history；
10. 最近 cmd-run；
11. 最近 cmd-record。

输出应保存到：

```text
~/.cache/copilot-cmd/contexts/<timestamp>/context.md
```

同时更新：

```text
~/.cache/copilot-cmd/latest-context
```

### 4.7 `cmd-run`

用途：执行单条命令并保存日志。

要求：

1. 每条命令生成独立目录；
2. 不覆盖旧日志；
3. 更新 `last-run`；
4. 保存命令、meta、stdout/stderr；
5. 返回原命令退出码。

### 4.8 `cmd-record`

用途：进入记录型 shell，会保存后续终端输出。

要求：

1. 使用 `script` 或等价方式记录 shell；
2. 每次记录生成独立目录；
3. 更新 `last-record`；
4. 用户输入 `exit` 后结束记录；
5. 适合处理“用户事先不知道命令会不会报错”的场景。

### 4.9 `cmd-suggest`

用途：根据当前 context、last-run、last-record 推荐后续可问的问题。

要求：

1. 默认使用 DeepSeek Flash；
2. 只推荐问题，不执行命令；
3. 支持输入 `r` 换一批问题；
4. 支持选择编号发送给 `cmd`；
5. 保存 latest/previous suggestions 到 cache；
6. 问题应具体、可操作。

### 4.10 `cmd-model`

用途：进入 GitHub Copilot native 登录/模型选择流程，并同步记录显示模型名。

要求：

1. 进入 Copilot native 环境；
2. 用户可执行 `/login`；
3. 用户可执行 `/model`；
4. 退出后提示同步显示模型名；
5. 不应强行把显示名作为 `--model` 参数传入；
6. 真实模型选择仍由 Copilot CLI 内部状态控制。

---

## 5. 模型后端规则

本项目支持两个后端。

### 5.1 DeepSeek BYOK

默认后端。

相关变量：

```bash
COPILOT_PROVIDER_TYPE='anthropic'
COPILOT_PROVIDER_BASE_URL='https://api.deepseek.com/anthropic'
COPILOT_PROVIDER_API_KEY
COPILOT_MODEL
```

默认模型：

```text
deepseek-v4-flash
```

Pro 模型：

```text
deepseek-v4-pro
```

用户密钥位置：

```text
~/.config/copilot-deepseek/env
```

严禁将任何真实 key 写入仓库。

### 5.2 GitHub Copilot native

通过：

```bash
cmd --copilot
cmdx --copilot
cmd-chat --copilot
cmd-model
```

使用。

注意：

1. `cmd --copilot` 默认不传 `--model`；
2. 它使用 Copilot CLI 当前/default 模型；
3. `/model` 菜单中的显示名不一定能作为 `--model` 参数；
4. 显示模型名由 `cmd-model` 或 `cmd-model-set` 记录；
5. 记录文件为：

```text
~/.config/copilot-cmd/current-native-model
```

不要设计自动解析 Copilot 内部模型状态，除非有稳定公开接口。

---

## 6. 用户数据与安装边界

安装后的用户数据应保持 per-user 隔离。

### 6.1 用户本地安装目录

```text
~/.local/bin
~/.local/lib
```

### 6.2 用户配置目录

```text
~/.config/copilot-deepseek
~/.config/copilot-cmd
```

### 6.3 用户 session 目录

```text
~/.copilot-cmd
```

### 6.4 用户 cache 目录

```text
~/.cache/copilot-cmd
```

### 6.5 回收站

```text
~/.copilot-cmd-trash
~/.cache/copilot-cmd-trash
```

不要把这些用户目录提交到仓库。

---

## 7. 安装脚本规则

`install.sh` 必须满足：

1. 可从任意目录执行；
2. 通过脚本自身位置确定 `PKG_DIR`；
3. 不硬编码 `/data/public/tools`；
4. 安装到当前用户 home；
5. 不需要 sudo；
6. 不覆盖已有 DeepSeek key；
7. 不覆盖已有 Copilot 模型列表；
8. 确保脚本权限正确；
9. 提示用户如何测试；
10. 如果 `copilot` 命令不存在，应给出清晰提示。

`install.sh` 不应把用户输入的 API Key 打印到终端。

---

## 8. 卸载脚本规则

`uninstall.sh` 必须满足：

1. 删除安装到 `~/.local/bin` 的工具脚本；
2. 删除安装到 `~/.local/lib` 的项目库脚本；
3. 询问用户是否删除配置、session 和 cache；
4. 不默认删除用户 API Key；
5. 不默认删除 session/cache；
6. 不引用已经废弃的命令，例如 `copilot-native-cmd`。

---

## 9. 文档维护规则

任何功能变更必须同步更新文档。

至少检查：

```text
README.md
CHANGELOG.md
CONTRIBUTING.md
SECURITY.md
docs/server-deployment.md
```

如果新增命令，必须更新：

1. README 功能总览表；
2. README 详细使用说明；
3. README 推荐工作流；
4. uninstall.sh 的卸载列表；
5. install.sh 的安装提示；
6. CHANGELOG.md；
7. 如有必要，更新 `AGENTS.md`。

---

## 10. 测试要求

任何 PR 或 agent 修改后，至少运行：

```bash
bash -n install.sh
bash -n uninstall.sh
find ./bin ./lib -type f -print0 | xargs -0 -I{} bash -n {}
```

建议同时运行：

```bash
grep -RInE 'sk-[A-Za-z0-9_-]{10,}|COPILOT_PROVIDER_API_KEY=.*sk-|ANTHROPIC_AUTH_TOKEN=.*sk-|OPENAI_API_KEY|DEEPSEEK_API_KEY|GITHUB_TOKEN|GH_TOKEN' . || echo "No obvious secrets found."

grep -RInE '/home/zhangjunxiao|/home/silver|server29|zhangjunxiao|silver' . || echo "No obvious personal/server-specific references found."
```

如果安装脚本或用户路径相关逻辑发生变化，应至少在临时用户目录中测试：

```bash
TMP_HOME="$(mktemp -d)"
HOME="$TMP_HOME" bash install.sh
```

注意该测试可能受 `copilot` 是否安装影响。

---

## 11. 严禁事项

AI agent 严禁执行以下行为：

1. 提交真实 API Key；
2. 提交 GitHub token；
3. 提交 SSH 私钥；
4. 提交用户日志；
5. 提交 `~/.cache/copilot-cmd` 内容；
6. 提交 `~/.copilot-cmd` 内容；
7. 把 `/data/public/tools` 写死进核心脚本；
8. 把 `server29` 写死进核心脚本；
9. 默认使用 sudo；
10. 默认自动执行 AI 建议命令；
11. 删除用户配置文件；
12. 在没有说明的情况下改变已有命令语义；
13. 修改 README 后不检查命令是否真实存在；
14. 删除安全确认逻辑。

---

## 12. 当前优先开发任务

后续维护建议按优先级推进。

### 12.1 近期修复任务

优先级最高。

1. 检查 README 中是否仍有过期命令，例如 `copilot-native-cmd`；
2. 确认 README 中包含 `cmd-new` 和 `cmd-resume` 的说明；
3. 确认 `cmd`、`cmdx`、`cmd-chat` 的模型选择说明一致；
4. 确认 `cmd-clean all` 不会删除 GitHub native 认证；
5. 确认安装脚本不覆盖用户自己的 DeepSeek key 和 Copilot 模型列表；
6. 确认卸载脚本不引用不存在的命令；
7. 确认 GitHub Actions 能通过。

### 12.2 v0.1.x 稳定性任务

1. 修复文档和脚本不一致问题；
2. 增强安装失败提示；
3. 改善 Copilot native 未登录时的错误输出；
4. 减少重复认证错误重试；
5. 补充更多 README 示例；
6. 保持向后兼容。

### 12.3 v0.2.0 计划功能

建议新增：

```text
cmd-version
cmd-doctor
cmd-session-list
cmd-session-switch
cmd-history
```

其中：

#### cmd-version

输出：

```text
cmd-helper version
install path
copilot version
node version
shell
current backend config
DeepSeek config exists or not
Copilot native display model
```

#### cmd-doctor

检查：

```text
~/.local/bin 是否在 PATH
copilot 是否存在
DeepSeek env 是否存在
API key 是否非空但不打印
cmd scripts 是否可执行
Copilot native session 是否存在
cache/session 目录权限是否正常
```

#### cmd-session-list / cmd-session-switch

用于管理多个任务 session，减少对 Copilot 内部 resume UI 的依赖。

#### cmd-history

查看历史问题：

```text
~/.cache/copilot-cmd/questions/
```

### 12.4 v0.3.0 体验增强任务

1. 优化 `cmd-suggest` 菜单；
2. 支持更清晰的问题分类；
3. 支持命令风险分级；
4. 支持 `cmdx --dry-run`；
5. 支持命令执行前自动解释命令；
6. 支持用户在审批前编辑命令并保存 diff。

### 12.5 v1.0.0 稳定版目标

达到以下条件后可考虑 v1.0.0：

1. 安装流程稳定；
2. 卸载流程稳定；
3. DeepSeek 后端稳定；
4. Copilot native 后端稳定；
5. 多用户服务器部署验证充分；
6. 文档完整；
7. 安全策略清晰；
8. 所有命令有基本测试；
9. 常见错误有清晰提示；
10. 不再频繁改变命令语义。

---

## 13. 提交规范

建议 commit message 使用简洁英文：

```text
Fix README command overview
Add cmd-doctor command
Improve cmdx approval prompt
Update install script path handling
Fix native model display message
```

每个 PR 应包含：

1. 修改目的；
2. 修改文件；
3. 测试方式；
4. 安全影响；
5. 是否影响已有用户配置；
6. 是否需要更新 README。

---

## 14. 维护者期望

AI agent 在处理 issue 或任务时，应优先采用最小修改原则。

除非用户明确要求重构，否则：

1. 不要大规模重写所有脚本；
2. 不要改变命令名；
3. 不要改变默认模型；
4. 不要改变默认安装目录；
5. 不要改变安全确认策略；
6. 不要把多个无关修改合并到一个 PR；
7. 不要删除已有功能；
8. 不要引入复杂依赖。

本项目应尽量保持 Bash 脚本轻量、可读、可审计。

---

## 15. Agent 工作流程建议

当 AI agent 被分配一个任务时，应按以下流程工作：

1. 阅读 `README.md`、`AGENTS.md`、`SECURITY.md`；
2. 确认任务影响哪些命令；
3. 搜索相关脚本；
4. 做最小必要修改；
5. 更新 README/CHANGELOG；
6. 运行 Bash 语法检查；
7. 运行密钥扫描；
8. 给出清晰 PR 总结；
9. 明确说明未测试项；
10. 不隐瞒不确定性。

---
