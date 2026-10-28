#!/usr/bin/env bash
# 校验并（可选）同步 skills/ 到 README「## Skills 清单」表格。
#
# 三档模式（优先级 NO_FIX > AI > 默认）：
#   默认               检测到未登记 → 内置纯脚本生成清单表 → 复核 → exit 1 让人复核
#   CHECK_REGISTRY_AI=1 检测到未登记 → 有 claude 则调 registry-sync skill 补全（可精简 description）；
#                       无 claude 则告警并回退到纯脚本生成 → 复核 → exit 1
#   CHECK_REGISTRY_NO_FIX=1  只校验不改文件（供 pre-commit hook）：有未登记 → 提示手动补 → exit 1
#
# 纯脚本生成逻辑内置于本文件（gen_registry 函数）：从各 SKILL.md frontmatter 生成，
# 幂等；保留已存在行的「状态」「维护人」列（不覆盖人工设成的 stable 等）。
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
README="$REPO/README.md"

# ---- 校验部分：计算未登记集合 ----

# 收集 skills/ 下含 SKILL.md 的目录名
list_skill_dirs() {
  [ -d "$REPO/skills" ] || return 0
  for d in "$REPO"/skills/*/; do
    [ -f "$d/SKILL.md" ] && basename "$d"
  done
}

# 解析 README「## Skills 清单」表格首列已登记名称
list_registered() {
  awk '
    /^## Skills 清单/ { insec=1; next }
    insec && /^## / { insec=0 }
    insec && /^\|/ {
      line=$0
      # 取第一个单元格内容
      sub(/^\|[ \t]*/, "", line)
      sub(/[ \t]*\|.*/, "", line)
      gsub(/^[ \t]+|[ \t]+$/, "", line)
      if (line == "" ) next
      if (line ~ /^-+$/) next          # |---| 分隔行
      if (line == "名称") next          # 表头
      if (line == "_(暂无)_") next      # 占位行
      gsub(/[`]/, "", line)            # 去反引号
      # markdown 链接 [txt](url) 还原为 txt
      while (match(line, /\[[^]]*\]\([^)]*\)/)) {
        pre = substr(line, 1, RSTART-1)
        m   = substr(line, RSTART, RLENGTH)
        post= substr(line, RSTART+RLENGTH)
        txt = m
        sub(/^\[/, "", txt); sub(/\].*$/, "", txt)   # 取 [] 内文本
        line = pre txt post
      }
      gsub(/^[ \t]+|[ \t]+$/, "", line)
      print line
    }
  ' "$README"
}

# 计算未登记集合
compute_missing() {
  local dirs registered
  dirs="$(list_skill_dirs | sort -u)"
  registered="$(list_registered | sort -u)"
  [ -z "$dirs" ] && return 0
  comm -23 <(printf '%s\n' "$dirs") <(printf '%s\n' "$registered")
}

# ---- 纯脚本生成部分：内置 gen_registry ----

# 解析单个 SKILL.md frontmatter 里某个键的值（name / description）。
frontmatter_value() {
  local file="$1" key="$2"
  awk -v k="$key" '
    NR==1 && $0!="---" { exit }        # 无 frontmatter
    NR>1 && $0=="---" { exit }         # frontmatter 结束
    {
      if ($0 ~ "^"k"[ \t]*:") {
        sub("^"k"[ \t]*:[ \t]*", "")
        gsub(/^["'"'"']|["'"'"']$/, "")   # 去首尾引号
        print
        exit
      }
    }
  ' "$file"
}

# 从 skills/*/SKILL.md 重写 README 清单表。幂等；保留已存在行的状态/维护人。
gen_registry() {
  local DEFAULT_MAINTAINER
  DEFAULT_MAINTAINER="$(git -C "$REPO" config user.name 2>/dev/null || true)"
  [ -z "$DEFAULT_MAINTAINER" ] && DEFAULT_MAINTAINER="TBD"

  # 读现有表格，建立 name -> 状态/维护人 映射，保留人工设置。
  declare -A EXISTING_STATUS EXISTING_MAINT
  local name
  while IFS='|' read -r _ c_name c_desc c_status c_maint _; do
    name="$(echo "$c_name" | sed 's/^[ \t`]*//; s/[ \t`]*$//')"
    name="$(echo "$name" | sed -E 's/\[([^]]*)\]\([^)]*\)/\1/')"
    [ -z "$name" ] && continue
    case "$name" in 名称|---*|_*) continue ;; esac
    EXISTING_STATUS["$name"]="$(echo "$c_status" | sed 's/^[ \t]*//; s/[ \t]*$//')"
    EXISTING_MAINT["$name"]="$(echo "$c_maint" | sed 's/^[ \t]*//; s/[ \t]*$//')"
  done < <(awk '/^## Skills 清单/{f=1;next} f&&/^## /{f=0} f&&/^\|/{print}' "$README")

  local rows="" desc status maint d
  local found=false
  for d in "$REPO"/skills/*/; do
    [ -f "$d/SKILL.md" ] || continue
    found=true
    name="$(frontmatter_value "$d/SKILL.md" name)"
    [ -z "$name" ] && name="$(basename "$d")"
    desc="$(frontmatter_value "$d/SKILL.md" description)"
    status="${EXISTING_STATUS[$name]:-draft}"
    [ -z "$status" ] && status="draft"
    maint="${EXISTING_MAINT[$name]:-$DEFAULT_MAINTAINER}"
    [ -z "$maint" ] && maint="$DEFAULT_MAINTAINER"
    rows="${rows}| ${name} | ${desc} | ${status} | ${maint} |"$'\n'
  done

  if ! $found; then
    rows="| _(暂无)_ | | | |"$'\n'
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v rows="$rows" '
    /^## Skills 清单/ {
      print; print ""
      print "| 名称 | 用途 | 状态 | 维护人 |"
      print "|------|------|------|--------|"
      printf "%s", rows
      insec=1; intable=0
      next
    }
    insec && /^\|/ { intable=1; next }        # 跳过旧表格行
    insec && intable && !/^\|/ { insec=0; intable=0; print; next }
    insec && /^$/ { next }                     # 跳过表格前后空行直到表格出现
    { print }
  ' "$README" > "$tmp"

  mv "$tmp" "$README"
  echo "✓ 已生成 Skills 清单表（$README）。"
}

# 用 claude + registry-sync skill 补全（可精简 description）。成功返回 0，失败返回非 0。
fix_with_ai() {
  claude -p "有新增 skill 未登记到 README 的 Skills 清单表，请用 registry-sync skill 把 skills/ 目录同步进 README 的「## Skills 清单」表格。" \
    --add-dir "$REPO" \
    --allowedTools "Read" "Edit" "Bash(git config *)" "Bash(ls *)" \
    --permission-mode acceptEdits
}

# ---- 主流程 ----

missing="$(compute_missing)"

if [ -z "$missing" ]; then
  echo "✓ Skills 清单已同步。"
  exit 0
fi

echo "✗ 以下 skill 未登记到 README 的 Skills 清单表："
printf '  - %s\n' $missing

# 纯校验模式：不改文件
if [ "${CHECK_REGISTRY_NO_FIX:-}" = "1" ]; then
  echo ""
  echo "请手动把上述 skill 补进 README「## Skills 清单」表格（或直接跑 ./scripts/check-registry.sh 自动补全）后再提交。"
  exit 1
fi

echo ""
if [ "${CHECK_REGISTRY_AI:-}" = "1" ]; then
  if command -v claude >/dev/null 2>&1; then
    echo "调用 claude + registry-sync 自动补全 README 清单表 ..."
    fix_with_ai || {
      echo "claude 调用失败，请手动补进 README 清单表。" >&2
      exit 1
    }
  else
    echo "告警: 未找到 claude，回退到纯脚本生成 ..." >&2
    gen_registry
  fi
else
  echo "纯脚本生成 README 清单表 ..."
  gen_registry
fi

# 复核：补全后重新校验
missing="$(compute_missing)"
if [ -n "$missing" ]; then
  echo "自动补全后仍有未登记项，请手动处理：" >&2
  printf '  - %s\n' $missing >&2
  exit 1
fi

echo ""
echo "已自动补全 README 清单表，请复核改动后再提交（本次不放行）。"
exit 1
