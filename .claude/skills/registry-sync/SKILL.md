---
name: registry-sync
description: 在本 Skills 仓库中，把 skills/ 目录下的 skill 同步登记到 README 的「Skills 清单」表格。当有新增 skill 未登记、提交前校验（check-registry.sh）触发、或用户要求同步 skills 清单/README 登记时使用。
---

# Skills 清单同步

把 `skills/` 目录下实际存在的 skill 同步登记进根 `README.md` 的「## Skills 清单」表格。

## 何时使用
- `scripts/check-registry.sh` 检测到有未登记 skill 时，以 headless 方式调用本 skill。
- 用户手动要求"同步 skills 清单""补全 README 登记"。

## 操作步骤
1. 列出 `skills/*/` 的目录名，即应登记的 skill 全集（每个子目录一个 skill）。
2. 读 `README.md`「## Skills 清单」表格，取首列已登记名称。跳过占位行 `_(暂无)_`、表头行、`|---|` 分隔行。
3. 求差集：目录里有、表格里没有的即未登记 skill。
4. 对每个未登记项：
   - 读 `skills/<name>/SKILL.md` 的 frontmatter，取 `name`（→「名称」列）和 `description`（→「用途」列，过长可精简为一句）。
   - 「状态」列填 `draft`；「维护人」列填 `git config user.name` 的结果，取不到则填 `TBD`。
5. 用 Edit 往表格追加行。若表格当前仅有占位行 `_(暂无)_`，用第一条真实记录替换该占位行，其余追加。

## 影响面与回滚
只修改 `README.md` 的清单表格，可逆。不自动 `git add` / `commit`，改完交由用户复核后再提交。

## 参考资料
- 登记约定见 README.md「新增一个 Skill」小节。
- 校验脚本：`scripts/check-registry.sh`。
