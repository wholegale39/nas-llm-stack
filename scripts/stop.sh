#!/usr/bin/env bash
# 停止 NAS LLM 套件（保留数据）
set -e
echo "停止容器（数据保留在 data/ 目录）..."

if docker compose version >/dev/null 2>&1 && [ -f "$(dirname "$(readlink -f "$0")")/../docker-compose.yml" ]; then
  cd "$(dirname "$(readlink -f "$0")")/.."
  docker compose down
else
  docker stop nas-ollama nas-open-webui 2>/dev/null || true
fi

echo "✅ 已停止。数据在 data/ 目录，下次用 scripts/install.sh 或 docker start 恢复。"
