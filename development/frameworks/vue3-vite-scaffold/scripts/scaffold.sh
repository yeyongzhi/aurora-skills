#!/usr/bin/env bash
# 搭建 Vue 3 + TypeScript + Vite 项目，装齐 Tailwind CSS v4、shadcn-vue、
# vue-router、pinia，按清单批量添加组件，最后输出依赖版本、安装数量与耗时。
#
# 用法:
#   bash scaffold.sh <项目名> [父目录]
#
# 环境变量:
#   PM=pnpm|npm|yarn   包管理器（默认 pnpm）
#   COMPONENTS="..."   覆盖组件清单，空格分隔
#   BASE_COLOR=neutral shadcn-vue 基础色（neutral / gray / zinc / stone / slate）
#
# 参考文档（大版本更新时务必回来核对）:
#   https://tailwindcss.com/docs/installation/using-vite
#   https://www.shadcn-vue.com/docs/installation/vite
set -euo pipefail

PM="${PM:-pnpm}"
BASE_COLOR="${BASE_COLOR:-neutral}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_LIST="$SCRIPT_DIR/../components.txt"

NAME="${1:-}"
PARENT="${2:-.}"

if [ -z "$NAME" ]; then
  echo "用法: bash scaffold.sh <项目名> [父目录]" >&2
  exit 2
fi

START=$(date +%s)
step() { printf '\n==> %s\n' "$1"; }

dlx() {
  case "$PM" in
    npm) npx "$@" ;;
    yarn) yarn dlx "$@" ;;
    *) "$PM" dlx "$@" ;;
  esac
}

# ---------- 1. 创建项目 ----------
step "创建 Vite 项目（vue-ts 模板）：$NAME"
mkdir -p "$PARENT"
cd "$PARENT"
if [ -e "$NAME" ]; then
  echo "目录 $NAME 已存在，拒绝覆盖" >&2
  exit 1
fi
"$PM" create vite@latest "$NAME" --template vue-ts
cd "$NAME"
PROJECT_DIR="$(pwd)"

# ---------- 2. 基础依赖 ----------
step "安装基础依赖"
"$PM" install

step "安装 vue-router、pinia"
"$PM" add vue-router pinia

# ---------- 3. Tailwind CSS v4 ----------
step "安装 Tailwind CSS v4（@tailwindcss/vite 插件方式）"
"$PM" add tailwindcss @tailwindcss/vite
"$PM" add -D @types/node

step "写入 vite.config.ts"
cat > vite.config.ts <<'EOF'
import path from 'node:path'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [vue(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
EOF

step "写入 src/style.css"
cat > src/style.css <<'EOF'
@import "tailwindcss";
EOF

step "配置 tsconfig 路径别名 @/* -> ./src/*"
node -e '
const fs = require("fs");
for (const f of ["tsconfig.json", "tsconfig.app.json"]) {
  if (!fs.existsSync(f)) { console.warn("跳过，未找到 " + f); continue; }
  try {
    const j = JSON.parse(fs.readFileSync(f, "utf8"));
    j.compilerOptions = j.compilerOptions || {};
    j.compilerOptions.baseUrl = ".";
    j.compilerOptions.paths = Object.assign({ "@/*": ["./src/*"] }, j.compilerOptions.paths || {});
    fs.writeFileSync(f, JSON.stringify(j, null, 2) + "\n");
    console.log("  已更新 " + f);
  } catch (e) {
    console.warn("  解析 " + f + " 失败（可能含注释），请手动添加 baseUrl 与 paths：" + e.message);
  }
}
'

# ---------- 4. shadcn-vue 初始化 ----------
step "初始化 shadcn-vue（-t vite -b $BASE_COLOR）"
dlx shadcn-vue@latest init -t vite -b "$BASE_COLOR" -y -d

# ---------- 5. 批量添加组件 ----------
if [ -n "${COMPONENTS:-}" ]; then
  read -r -a LIST <<< "$COMPONENTS"
else
  mapfile -t LIST < <(grep -vE '^\s*(#|$)' "$DEFAULT_LIST")
fi

step "添加 ${#LIST[@]} 个 shadcn-vue 组件"
OK=0
FAILED=()
for c in "${LIST[@]}"; do
  if dlx shadcn-vue@latest add "$c" -y -o -s >/dev/null 2>&1; then
    OK=$((OK + 1))
    printf '  ok   %s\n' "$c"
  else
    FAILED+=("$c")
    printf '  FAIL %s\n' "$c"
  fi
done

# ---------- 6. 报告 ----------
END=$(date +%s)
DUR=$((END - START))
MINS=$((DUR / 60))
SECS=$((DUR % 60))

FAILED_LIST=$(printf '%s' "${FAILED[*]:-}")
FAILED_COUNT=${#FAILED[@]}

{
  echo "# 脚手架交付报告"
  echo
  echo "- 项目：$PROJECT_DIR"
  echo "- 包管理器：$PM"
  echo "- 完成时间：$(date '+%Y-%m-%d %H:%M:%S')"
  echo
  echo "## 核心依赖"
  echo
  echo "| 包 | 版本 |"
  echo "| --- | --- |"
  node -e '
const fs = require("fs");
const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
const all = Object.assign({}, p.dependencies, p.devDependencies);
const keys = ["vue", "vite", "vue-router", "pinia", "tailwindcss",
  "@tailwindcss/vite", "typescript", "vue-tsc", "@vitejs/plugin-vue"];
for (const k of keys) {
  if (all[k]) console.log("| " + k + " | " + all[k] + " |");
}
'
  echo
  echo "## 组件安装结果"
  echo
  echo "- shadcn-vue 组件：成功 $OK / ${#LIST[@]}"
  if [ "$FAILED_COUNT" -gt 0 ]; then
    echo "- 失败 $FAILED_COUNT 个：$FAILED_LIST"
  else
    echo "- 无失败项"
  fi
  echo
  echo "## 耗时"
  echo
  echo "${MINS} 分 ${SECS} 秒（共 $DUR 秒）"
} | tee SCAFFOLD_REPORT.md

printf '\n完成：%s\n' "$PROJECT_DIR"
