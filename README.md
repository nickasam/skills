# Skills

一个通用的 **Skills 集中仓库**，用 Git 做版本控制。经验、操作流程、排障手册以 Skill 形式沉淀，并通过**软链接**按需挂载进目标 agent 的 skills 目录——本仓库不是任何 agent 的全量 skills。

## Skills 清单

| 名称 | 用途 | 状态 | 维护人 |
|------|------|------|--------|
| job-for-you | 求职助手：简历-职位匹配度分析、模拟面试与面经整理、职位搜索与推荐（拉钩/BOSS直聘等） | draft | zhenghongfei6 |

> 新增 skill 后同步更新此表（或跑 `CHECK_REGISTRY_AI=1 ./scripts/check-registry.sh` 自动补全）。

## 安装

把 skill 软链进 agent 的 skills 目录（如 `~/.claude/skills`）：

```bash
# 挂载全部
./scripts/install.sh --all --target ~/.claude/skills

# 挂载指定 skill
./scripts/install.sh some-skill --target ~/.claude/skills
```

也可用环境变量 `SKILLS_TARGET` 代替 `--target`。安装脚本是幂等的：已指向本仓库的链接会跳过，指向别处或已存在的真实文件会告警而不覆盖；目录内缺 `SKILL.md` 的会告警跳过。

验证：`ls -l ~/.claude/skills`（应看到指向本仓库的软链）。
更新：`git pull` 即可，软链自动跟随。
卸载：`./scripts/uninstall.sh --all --target ~/.claude/skills`（只删指向本仓库的链接）。

> **注意**：软链写入的是本仓库的**绝对路径**。仓库目录一旦搬动，已挂载的软链会全部断裂——迁移后请重新跑一次 `install.sh`。请把仓库放在一个稳定、长期不变的路径下。

## 目录结构

```
skills/
├── README.md            # 本文件：总览 + 清单 + 安装
├── skills/              # 可分发 skill，一个 skill 一个自包含子目录
│   └── <skill-name>/
│       ├── SKILL.md
│       ├── references/  # 文档、配置模板
│       └── scripts/     # 该 skill 的脚本
├── .claude/skills/      # 仓库自用 skill（如 registry-sync），不分发
├── scripts/             # install.sh / uninstall.sh / check-registry.sh
└── templates/           # 新建 skill 的脚手架 (SKILL.md.tmpl)
```

## 新增一个 Skill

1. `mkdir skills/<skill-name>`，把 `templates/SKILL.md.tmpl` 拷成 `skills/<skill-name>/SKILL.md`。
2. 填写 frontmatter：`name` 用小写 kebab-case（与目录名一致），按「动作-主体-名词」结构命名；`description` 写清"做什么 + 何时触发"，含关键词——它决定 agent 是否加载本 skill。
3. 大段参考资料/脚本/模板放进子目录 `references/`、`scripts/`，正文按需引用，保持 SKILL.md 精简。
4. 涉及有副作用的操作（写操作、不可逆操作）务必标注**权限要求、影响面、危险/不可逆操作**。
5. 更新上面的 Skills 清单表——直接跑 `./scripts/check-registry.sh`：检测到未登记会自动补全（默认纯脚本生成，无需 `claude`；设 `CHECK_REGISTRY_AI=1` 则用 AI 精简 description）。

> 提交前执行 `./scripts/check-registry.sh` 校验清单是否同步：
> - **默认**：检测到未登记 → 纯脚本生成清单表（无外部依赖）→ 退出并要人复核。
> - **`CHECK_REGISTRY_AI=1`**：改用 `claude` + `registry-sync` skill 补全（可把过长 description 精简为一句）；无 `claude` 时自动回退纯脚本。
> - **`CHECK_REGISTRY_NO_FIX=1`**：只校验不改文件（供 pre-commit hook）。
>
> 无论哪种，补全后都不放行，请复核改动再提交。

## 提交与版本

- **分支**：`master` 为可用最新版本。日常开发在其他分支，评审合入 `main`，周期性评审合入 `master`。
- **skill 成熟度**：清单表「状态」列取以下枚举之一：
  - `draft`：开发中/未充分验证，谨慎使用。
  - `stable`：已验证，可放心挂载。
  - `deprecated`：将废弃，勿在新场景使用。
- **拉取稳定版**：`git pull` 更新后软链自动跟随最新内容。若担心拉到 `draft`/broken 的 skill，可只挂载 `stable` 的 skill，或按需要的 tag/commit checkout 后再 install。
- **破坏性变更**：修改已有 skill 的行为/接口时，在 commit 说明和 `CHANGELOG.md`（见下）中标注，便于已挂载该 skill 的 agent 使用者感知。

### 提交前门禁（可选硬约束）

`check-registry.sh` 默认靠"记得手动跑"。若想把它变成 pre-commit 硬门禁，接入仓库内托管的 hook：

```bash
git config core.hooksPath scripts/hooks   # 一次性设置
```

（前提：仓库提供 `scripts/hooks/pre-commit` 调用 `check-registry.sh`。未提供时忽略本节。）

## 兼容性

安装脚本只做「把 `skills/<name>/` 目录软链到 `--target` 指定目录」，不绑定特定 agent。示例用的是 Claude Code 的 `~/.claude/skills`；其他遵循「一个 skill 一个目录 + SKILL.md」约定的 agent，把 `--target` 指向其 skills 目录即可。

## 授权与免责

- skill 常含生产操作步骤，**执行前务必确认权限要求、影响面与可逆性**（见各 SKILL.md）。因误用造成的后果由执行者负责。
