#!/usr/bin/env bash
# 移除指向本仓库的 skill 软链。只删指向本仓库的链接, 不动真实文件或别处的链接。
# 用法:
#   ./scripts/uninstall.sh --all --target ~/.claude/skills
#   ./scripts/uninstall.sh some-skill --target ~/.claude/skills
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

for name in "${skills[@]}"; do
  src="$REPO/skills/$name"
  dst="$TARGET/$name"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    rm "$dst"
    echo "已卸载: $name"
  else
    echo "跳过(非本仓库软链): $name" >&2
  fi
done
