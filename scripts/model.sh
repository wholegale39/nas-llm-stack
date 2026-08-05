#!/usr/bin/env bash
# 模型管理：列表 / 下载 / 删除
# 用法：bash scripts/model.sh list | pull <model> | rm <model> | recommend
set -e

CMD="${1:-list}"

case "$CMD" in
  list)
    echo "=== 已安装模型 ==="
    docker exec nas-ollama ollama list 2>/dev/null || echo "（Ollama 未运行或未安装模型）"
    ;;
  pull)
    MODEL="$2"
    if [ -z "$MODEL" ]; then
      echo "用法: bash scripts/model.sh pull <模型名>，如 qwen2.5:7b"
      exit 1
    fi
    echo "下载模型 $MODEL ..."
    docker exec nas-ollama ollama pull "$MODEL"
    echo "✅ 完成"
    ;;
  rm)
    MODEL="$2"
    if [ -z "$MODEL" ]; then
      echo "用法: bash scripts/model.sh rm <模型名>"
      exit 1
    fi
    docker exec nas-ollama ollama rm "$MODEL"
    echo "✅ 已删除 $MODEL"
    ;;
  recommend)
    echo "=== 群晖常见机型推荐模型 ==="
    echo "内存 4-8GB  （DS220+/DS223j）: qwen2.5:1.5b / llama3.2:1b"
    echo "内存 8-16GB （DS920+/DS1522+）: qwen2.5:7b / gemma3:4b"
    echo "内存 16GB+  （DS1821+/RS系列）: qwen2.5:14b / llama3.3:8b"
    echo ""
    echo "说明：Ollama 模型会占用内存，低配机型建议一次只装 1-2 个模型"
    ;;
  *)
    echo "用法: bash scripts/model.sh [list|pull|rm|recommend]"
    exit 1
    ;;
esac
