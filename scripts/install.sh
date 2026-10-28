#!/usr/bin/env bash
# 将本仓库的 skill 软链挂载进目标 agent 的 skills 目录。
# 用法:
#   ./scripts/install.sh --all --target ~/.claude/skills
#   ./scripts/install.sh some-skill another-skill --target ~/.claude/skills
# 也可用环境变量 SKILLS_TARGET 指定 target。
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${SKILLS_TARGET:-}"
ALL=false
skills=()

while [ $# -gt 0 ]; do
  case "$1" in
    --all) ALL=true; shift ;;
    --target) TARGET="$2"; shift 2 ;;
    -*) echo "未知参数: $1" >&2; exit 1 ;;
    *) skills+=("$1"); shift ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "错误: 未指定 target。用 --target <dir> 或环境变量 SKILLS_TARGET。" >&2
  exit 1
fi

if $ALL; then
  skills=()
  for d in "$REPO"/skills/*/; do
    [ -d "$d" ] && skills+=("$(basename "$d")")
  done
fi

if [ ${#skills[@]} -eq 0 ]; then
  echo "没有要挂载的 skill。用 --all 或指定 skill 名。" >&2
  exit 1
fi

mkdir -p "$TARGET"

for name in "${skills[@]}"; do
  src="$REPO/skills/$name"
  dst="$TARGET/$name"
  if [ ! -d "$src" ]; then
    echo "跳过: skill 不存在: $name" >&2
    continue
  fi
  if [ ! -f "$src/SKILL.md" ]; then
    echo "告警: $name 目录内缺 SKILL.md, 跳过。" >&2
    continue
  fi
  if [ -L "$dst" ]; then
    cur="$(readlink "$dst")"
    if [ "$cur" = "$src" ]; then
      echo "已存在(指向本仓库), 跳过: $name"
      continue
    fi
    echo "告警: $dst 已是软链但指向 $cur, 跳过。如需覆盖请先手动删除。" >&2
    continue
  elif [ -e "$dst" ]; then
    echo "告警: $dst 已存在且非软链, 跳过。" >&2
    continue
  fi
  ln -sfn "$src" "$dst"
  echo "已挂载: $name -> $dst"
done
