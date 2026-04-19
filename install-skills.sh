#!/bin/bash
# 安装 Claude Code skills 到工作区
# 用法: bash install-skills.sh [工作区根目录]
# 默认工作区为脚本所在目录的上级目录 (Weixing-LocalPC)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${1:-$(dirname "$SCRIPT_DIR")}"
SKILLS_SRC="$SCRIPT_DIR/claude-skills"
SKILLS_DST="$WORKSPACE/.claude/skills"

if [ ! -d "$SKILLS_SRC" ]; then
  echo "错误: 找不到 skills 源目录 $SKILLS_SRC"
  exit 1
fi

mkdir -p "$SKILLS_DST"

for skill_dir in "$SKILLS_SRC"/*/; do
  skill_name=$(basename "$skill_dir")
  echo "安装 skill: $skill_name"
  rm -rf "$SKILLS_DST/$skill_name"
  cp -r "$skill_dir" "$SKILLS_DST/$skill_name"
done

# 安装 AGENTS.md 到工作区根目录
if [ -f "$SCRIPT_DIR/AGENTS.md" ]; then
  cp "$SCRIPT_DIR/AGENTS.md" "$WORKSPACE/AGENTS.md"
  echo "安装 AGENTS.md → $WORKSPACE/AGENTS.md"
fi

echo ""
echo "已安装到 $SKILLS_DST:"
ls -1 "$SKILLS_DST"
