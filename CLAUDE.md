# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 这个仓库是什么

一个通用的 **Skills 集中仓库**。它不是任何 agent 的全量 skills 目录，而是一个用 Git 版本控制的 skill 源，通过**软链接**按需挂载进目标 agent 的 skills 目录。核心心智模型：这里改一次，所有软链指向这里的 agent 都跟着更新（`git pull` 即可）。

## 常用命令

```bash
# 挂载 skill（写入本仓库绝对路径的软链）
./scripts/install.sh --all --target ~/.claude/skills
./scripts/install.sh some-skill --target ~/.claude/skills       # 指定 skill
SKILLS_TARGET=~/.claude/skills ./scripts/install.sh --all        # 用环境变量代替 --target

# 卸载（只删指向本仓库的软链，不碰别处）
./scripts/uninstall.sh --all --target ~/.claude/skills

# 校验 README 清单表是否和 skills/ 同步（提交前跑）
./scripts/check-registry.sh                       # 未登记 → 纯脚本补全 → exit 1 要人复核
CHECK_REGISTRY_AI=1 ./scripts/check-registry.sh    # 改用 claude + registry-sync skill 精简 description
CHECK_REGISTRY_NO_FIX=1 ./scripts/check-registry.sh  # 只校验不改文件（供 pre-commit hook）
```

没有编译/构建步骤。skill 脚本若为 Python，直接 `python3 skills/<name>/scripts/xxx.py <subcommand>` 运行。

## 目录约定（关键区分）

- `skills/<name>/` — **可分发** skill，一个 skill 一个自包含子目录，必须含 `SKILL.md`；大段资料放 `references/`，脚本放 `scripts/`。`install.sh` 只挂载这里的目录。
- `.claude/skills/<name>/` — 仓库**自用** skill（如 `registry-sync`），**不分发**、不被 install.sh 挂载。
- `.claude/agents/<name>.md` — 仓库自用的 subagent 定义（如 `code-reviewer`），供本仓库自身开发时调用，与 `skills/` 下可分发的 skill 无关。
- `templates/SKILL.md.tmpl` — 新建 skill 的脚手架。
- `scripts/` — 仓库工具脚本（install / uninstall / check-registry），不是 skill。

## SKILL.md frontmatter 契约

`name`（小写 kebab-case，须与目录名一致）和 `description` 是硬约束。`description` 决定 agent 是否加载该 skill，必须写清「做什么 + 何时触发」并包含触发关键词。`check-registry.sh` 和 `registry-sync` 都靠解析 frontmatter 的这两个字段生成 README 清单表。

## README 清单表是自动维护的

README「## Skills 清单」表格不要手写维护。新增 skill 后跑 `check-registry.sh`：它对比 `skills/*/` 目录集与表格首列，对未登记项从 SKILL.md frontmatter 生成行。**幂等，且保留已存在行的「状态」「维护人」列**（不会覆盖人工设成的 `stable`）。「状态」列枚举：`draft`（未充分验证）/ `stable`（已验证可挂载）/ `deprecated`（将废弃）。

## 分支模型

- `master`：可用最新稳定版。
- `main`：日常开发合入点，周期性评审后再合入 `master`。
- 修改已有 skill 的行为/接口属于破坏性变更，需在 commit 说明中标注，让已挂载该 skill 的使用者感知。

## 迁移注意

软链写的是本仓库**绝对路径**。仓库目录一旦搬动，所有已挂载软链会断裂——迁移后必须重新跑 `install.sh`。把仓库放在稳定、长期不变的路径下。
