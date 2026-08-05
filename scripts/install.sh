#!/usr/bin/env bash
# ============================================================
# 群晖 NAS LLM 一键部署脚本
# 适用：DS220+/DS420+/DS920+ 等 x86_64 群晖（Docker 已装）
# 用法：bash scripts/install.sh
# ============================================================
set -e

# ── 颜色 ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC} $1"; }

# ── 检测环境 ────────────────────────────────────────────────
detect_env() {
  info "检测 NAS 环境..."

  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64) ARCH_TAG="x86_64" ;;
    aarch64|arm64) ARCH_TAG="arm64" ;;
    *) err "不支持的架构: $ARCH（本套件仅支持 x86_64 / arm64）"; exit 1 ;;
  esac
  ok "架构: $ARCH_TAG"

  # 内存（MB）
  MEM_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
  if [ -z "$MEM_MB" ]; then
    MEM_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
  fi
  ok "内存: $((MEM_MB / 1024)) GB"
  if [ "$MEM_MB" -lt 6144 ]; then
    warn "内存 < 6GB：建议只跑 1.5B~3B 小模型，7B 量化可能卡顿"
  elif [ "$MEM_MB" -lt 16384 ]; then
    warn "内存 6~16GB：可跑 7B 量化模型，建议 OLLAMA_NUM_PARALLEL=1"
  else
    ok "内存充足：可跑 7B~13B 模型"
  fi

  # Docker
  if ! command -v docker >/dev/null 2>&1; then
    err "未检测到 Docker。请先在套件中心安装 Container Manager。"
    exit 1
  fi
  DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
  ok "Docker: $DOCKER_VER"

  # 磁盘
  DISK_GB=$(df -Pk "$(pwd)" | awk 'NR==2{print int($4/1024/1024)}')
  ok "可用磁盘: ${DISK_GB} GB"
  if [ "$DISK_GB" -lt 10 ]; then
    warn "磁盘 < 10GB：模型文件较大（3B≈2GB，7B≈4.5GB），注意空间"
  fi
}

# ── 选择模型 ────────────────────────────────────────────────
pick_model() {
  echo ""
  echo "选择要下载的模型（按内存建议）："
  if [ "$MEM_MB" -lt 6144 ]; then
    MODELS="qwen2.5:1.5b\nqwen2.5:3b\nllama3.2:1b\ngemma3:1b"
  elif [ "$MEM_MB" -lt 16384 ]; then
    MODELS="qwen2.5:3b\nqwen2.5:7b\nllama3.2:3b\ngemma3:4b"
  else
    MODELS="qwen2.5:7b\nqwen2.5:14b\nllama3.2:3b\ngemma3:4b"
  fi
  echo -e "$MODELS" | nl -s ') '
  echo "0) 不下载，稍后手动 pull"
  echo ""
  printf "输入编号 [0-4]："
  read -r CHOICE
  case "$CHOICE" in
    1) MODEL=$(echo -e "$MODELS" | sed -n '1p') ;;
    2) MODEL=$(echo -e "$MODELS" | sed -n '2p') ;;
    3) MODEL=$(echo -e "$MODELS" | sed -n '3p') ;;
    4) MODEL=$(echo -e "$MODELS" | sed -n '4p') ;;
    0|"") MODEL="" ;;
    *) warn "无效输入，跳过模型下载" ;;
  esac
}

# ── 启动容器 ────────────────────────────────────────────────
start_containers() {
  info "启动容器（Ollama + Open WebUI）..."

  # 优先 compose（Container Manager 项目 / docker compose 插件）
  if docker compose version >/dev/null 2>&1; then
    info "检测到 docker compose，使用 compose 启动"
    docker compose up -d
    return 0
  fi

  # 无 compose：逐容器启动（兼容群晖原生 Docker）
  warn "未检测到 docker compose，改用 docker run 逐容器启动"
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  mkdir -p "$SCRIPT_DIR/data/ollama" "$SCRIPT_DIR/data/open-webui"

  if ! docker ps -a --format '{{.Names}}' | grep -q '^nas-ollama$'; then
    docker run -d --name nas-ollama \
      --restart unless-stopped \
      -v "$SCRIPT_DIR/data/ollama:/root/.ollama" \
      -p 11434:11434 \
      -e OLLAMA_KEEP_ALIVE=30m \
      -e OLLAMA_NUM_PARALLEL=1 \
      ollama/ollama:latest
  else
    docker start nas-ollama
  fi

  if ! docker ps -a --format '{{.Names}}' | grep -q '^nas-open-webui$'; then
    docker run -d --name nas-open-webui \
      --restart unless-stopped \
      -v "$SCRIPT_DIR/data/open-webui:/app/backend/data" \
      -p 3000:8080 \
      -e OLLAMA_BASE_URL=http://nas-ollama:11434 \
      ghcr.io/open-webui/open-webui:main
  else
    docker start nas-open-webui
  fi
}

# ── 下载模型 ────────────────────────────────────────────────
pull_model() {
  [ -z "$MODEL" ] && return 0
  info "下载模型 $MODEL（首次下载需几分钟到几十分钟，取决于网络和模型大小）..."
  for i in $(seq 1 30); do
    if docker exec nas-ollama ollama list >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
  docker exec nas-ollama ollama pull "$MODEL"
  ok "模型 $MODEL 下载完成"
}

# ── 健康检查 ────────────────────────────────────────────────
wait_healthy() {
  info "等待服务就绪（最多 90 秒）..."
  for i in $(seq 1 30); do
    OLLAMA_OK=$(curl -s -m 3 http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && echo yes || echo no)
    WEBUI_OK=$(curl -s -m 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:3000 2>/dev/null || echo 000)
    if [ "$OLLAMA_OK" = yes ] && [ "$WEBUI_OK" != 000 ]; then
      ok "服务就绪！"
      return 0
    fi
    sleep 3
  done
  warn "等待超时——Ollama: $OLLAMA_OK, WebUI: $WEBUI_OK（可能仍在启动，稍后访问试试）"
}

# ── 主流程 ──────────────────────────────────────────────────
main() {
  echo "========================================================"
  echo "  群晖 NAS LLM 一键部署套件"
  echo "========================================================"
  detect_env
  pick_model
  start_containers
  pull_model
  wait_healthy

  IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  [ -z "$IP" ] && IP="<NAS-IP>"
  echo ""
  echo "========================================================"
  echo "  🎉 部署完成！"
  echo ""
  echo "  聊天界面 (Open WebUI):  http://${IP}:3000"
  echo "  Ollama API:             http://${IP}:11434"
  echo ""
  echo "  首次访问 Open WebUI 需注册管理员账号"
  echo "  常用命令："
  echo "    bash scripts/status.sh       # 查看状态"
  echo "    bash scripts/model.sh list   # 模型列表"
  echo "    bash scripts/model.sh pull qwen2.5:7b   # 下载新模型"
  echo "    bash scripts/model.sh rm qwen2.5:7b     # 删除模型"
  echo "    bash scripts/stop.sh         # 停止服务"
  echo "========================================================"
}

main "$@"
