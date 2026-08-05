#!/usr/bin/env bash
# 查看 NAS LLM 套件运行状态
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "=== 容器状态 ==="
docker ps -a --filter "name=nas-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
  echo "未检测到 Docker"

echo ""
echo "=== Ollama 健康 ==="
if curl -s -m 3 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  echo "✅ Ollama API 正常"
else
  echo "❌ Ollama API 不可达"
fi

echo ""
echo "=== 已安装模型 ==="
if docker ps --format '{{.Names}}' | grep -q '^nas-ollama$'; then
  docker exec nas-ollama ollama list 2>/dev/null || echo "（Ollama 启动中或未安装模型）"
else
  echo "（容器未运行）"
fi

echo ""
echo "=== 资源占用 ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" nas-ollama nas-open-webui 2>/dev/null || true

echo ""
echo "=== 访问地址 ==="
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "$IP" ] && IP="<NAS-IP>"
echo "  Open WebUI: http://${IP}:3000"
echo "  Ollama API: http://${IP}:11434"
