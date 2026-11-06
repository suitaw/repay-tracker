#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
# deploy_repay.sh —— repay-tracker 专用部署脚本
#
# 用法:
#   ./deploy_repay.sh          自动检测更新的文件并部署
#   ./deploy_repay.sh "自定义说明"   commit message 追加你的说明
#
# 做的事:
#   1. 从 ~/storage/downloads 找出 TARGET_FILES 里列出的文件
#   2. 与仓库版本内容比对，有变化才 cp 进仓库
#   3. git add / commit（自动生成message）/ push
#   4. 全程打印每一步在做什么，出错时不会静默失败
# =====================================================================

set -e  # 任何一步出错立即停下，避免半吊子部署
shopt -s nullglob nocaseglob  # 配置符合大小写不敏感，通配符匹配不到时返回空

# ---------- 配置区：按需修改 ----------
REPO_DIR="$HOME/repay-tracker"
DOWNLOAD_DIR="$HOME/storage/downloads"
# 需要检测部署的文件清单：以后加文件只要在这里加一行
TARGET_FILES=("index.html")
PROXY="http://127.0.0.1:7890"
# ---------------------------------------

echo "==> 检查代理环境变量..."
if [ -z "$https_proxy" ] || [ -z "$http_proxy" ]; then
  export https_proxy="$PROXY"
  export http_proxy="$PROXY"
  echo "    未检测到代理变量，本次会话自动设置为：$PROXY"
else
  echo "    代理变量已存在：$https_proxy"
fi

if [ ! -d "$REPO_DIR" ]; then
  echo "错误：仓库目录不存在 $REPO_DIR"
  exit 1
fi

if [ ! -d "$DOWNLOAD_DIR" ]; then
  echo "错误：下载目录不存在 $DOWNLOAD_DIR（可能 Termux:API 存储权限尚未授予，跑一次 termux-setup-storage）"
  exit 1
fi

cd "$REPO_DIR"

CHANGED=()
TO_CLEANUP=()

echo "==> 检测有更新的文件..."
for f in "${TARGET_FILES[@]}"; do
  SRC="$DOWNLOAD_DIR/$f"
  DST="$REPO_DIR/$f"
  if [ ! -f "$SRC" ]; then
    continue  # 下载目录里没有这个文件（任何版本），跳过，不报错
  fi
  # 用内容对比（而不是时间戳）：避免"文件时间更新但内容没变"导致误判
  if [ -f "$DST" ] && cmp -s "$SRC" "$DST"; then
    echo "    - $f: 内容无变化，跳过"
    continue
  fi
  cp "$SRC" "$DST"
  CHANGED+=("$f")
  echo "    - $f: 已复制到仓库（有变化，源 '$SRC'）"
  TO_CLEANUP+=("$SRC")
done

if [ ${#CHANGED[@]} -eq 0 ]; then
  echo "==> 没有文件需要部署，退出。"
  exit 0
fi

echo "==> git add..."
git add "${CHANGED[@]}"

echo "==> git commit..."
TS=$(date "+%Y-%m-%d %H:%M:%S")
FILELIST=$(IFS=,; echo "${CHANGED[*]}")
if [ -n "$1" ]; then
  MSG="更新 [$FILELIST] $1"
else
  MSG="更新 [$FILELIST] $TS"
fi
git commit -m "$MSG"

echo "==> git push..."
git push

echo ""
echo "==> 部署完成: ${CHANGED[*]}"
echo "    https://suitaw.github.io/repay-tracker/"

# 清理下载目录里已部署的源文件（不留重复版本）
for src in "${TO_CLEANUP[@]}"; do
  rm -f "$src"
  echo "    - 已删除下载目录中的 $(basename "$src")"
done
