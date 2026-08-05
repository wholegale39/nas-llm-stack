#!/usr/bin/env bash
# 卸载 NAS LLM 套件（删除容器 + 可选删除数据）
set -e

echo "⚠️  即将卸载 NAS LLM 套件"
read -r -p "删除模型数据（data/ 目录，含已下载的模型）？[y/N] " DEL_DATA

echo "停止并删除容器..."
if docker compose version >/dev/null 2>&1 && [ -f "$(dirname "$(readlink -f "$0")")/../docker-compose.yml" ]; then
  cd "$(dirname "$(readlink -f "$0")")/.."
  docker compose down -v 2>/dev/null || docker compose down
else
  docker rm -f nas-ollama nas-open-webui 2>/dev/null || true
fi

if [[ "$DEL_DATA" =~ ^[Yy]$ ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  rm -rf "$SCRIPT_DIR/../data"
  echo "✅ 数据已删除"
else
  echo "✅ 数据保留在 data/ 目录"
fi

echo "卸载完成。"
