#!/usr/bin/env bash
# 把仓库里的 skill 安装到 Agent 的 skills 目录。
#
# 用法:
#   ./install.sh                       # 软链到 ~/.workbuddy/skills
#   ./install.sh -t ~/.claude/skills   # 指定目标目录
#   ./install.sh -c                    # 复制而非软链
#   ./install.sh -f                    # 覆盖已存在的同名 skill
set -euo pipefail

TARGET="$HOME/.workbuddy/skills"
COPY=0
FORCE=0

while getopts "t:cfh" opt; do
  case "$opt" in
    t) TARGET="$OPTARG" ;;
    c) COPY=1 ;;
    f) FORCE=1 ;;
    h) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "用法: $0 [-t 目标目录] [-c] [-f]" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mapfile -t SKILLS < <(
  find "$REPO_ROOT" -name SKILL.md -type f \
    -not -path "*/.git/*" \
    -not -path "*/_archive/*" \
    -not -path "*/_templates/*" \
    -not -path "*/node_modules/*" \
    -not -path "*/scripts/*" \
    | sort
)

if [ ${#SKILLS[@]} -eq 0 ]; then
  echo "未在 $REPO_ROOT 下找到任何 SKILL.md" >&2
  exit 0
fi

mkdir -p "$TARGET"
ok=0; skipped=0

for skill_md in "${SKILLS[@]}"; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  dest="$TARGET/$name"

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$FORCE" -eq 1 ]; then
      rm -rf "$dest"
    else
      echo "  跳过 $name（已存在，用 -f 覆盖）"
      skipped=$((skipped + 1))
      continue
    fi
  fi

  if [ "$COPY" -eq 1 ]; then
    cp -R "$src" "$dest"
  else
    ln -s "$src" "$dest"
  fi
  echo "  + $name"
  ok=$((ok + 1))
done

echo ""
echo "完成：安装 $ok，跳过 $skipped -> $TARGET"
