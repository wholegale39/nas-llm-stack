#!/usr/bin/env bash
# 套件测试：语法检查 + 逻辑验证（不实际部署容器）
set -e
cd "$(dirname "$0")/.."

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "✅ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "❌ $1"; }

echo "=== 1. shell 语法检查 ==="
for f in scripts/*.sh; do
  if bash -n "$f" 2>/dev/null; then
    ok "$f 语法正确"
  else
    bad "$f 语法错误"
  fi
done

echo ""
echo "=== 2. 文件完整性 ==="
for f in docker-compose.yml scripts/install.sh scripts/status.sh \
         scripts/model.sh scripts/stop.sh scripts/uninstall.sh; do
  [ -f "$f" ] && ok "$f 存在" || bad "$f 缺失"
done

echo ""
echo "=== 3. docker-compose 语法（如可用）==="
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  if docker compose config -q 2>/dev/null; then
    ok "docker-compose.yml 语法正确"
  else
    bad "docker-compose.yml 语法错误"
  fi
else
  # 无 compose：用 python 的 yaml 做基础校验
  if python3 -c "
import sys
try:
    import yaml
    yaml.safe_load(open('docker-compose.yml'))
    print('ok')
except Exception as e:
    print('bad', e)
    sys.exit(1)
" >/dev/null 2>&1; then
    ok "docker-compose.yml YAML 语法正确（python yaml 校验）"
  else
    bad "docker-compose.yml 解析失败"
  fi
fi

echo ""
echo "=== 4. 关键逻辑抽查 ==="
grep -q "nas-ollama" docker-compose.yml && ok "compose 包含 ollama" || bad "compose 缺 ollama"
grep -q "nas-open-webui" docker-compose.yml && ok "compose 包含 open-webui" || bad "compose 缺 open-webui"
grep -q "11434" scripts/install.sh && ok "install.sh 使用 11434 端口" || bad "install.sh 缺 11434"
grep -q "pick_model\|推荐" scripts/model.sh && ok "model.sh 有推荐功能" || bad "model.sh 缺推荐"
grep -q "hostname -I" scripts/status.sh && ok "status.sh 显示 IP" || bad "status.sh 缺 IP 显示"

echo ""
echo "=== 5. 脚本可执行权限 ==="
for f in scripts/*.sh; do
  [ -x "$f" ] && ok "$f 可执行" || { chmod +x "$f" 2>/dev/null && ok "$f 已加可执行" || bad "$f 不可执行"; }
done

echo ""
echo "================================"
echo "  通过: $PASS  失败: $FAIL"
echo "================================"
[ "$FAIL" -eq 0 ]
