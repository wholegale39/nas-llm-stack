# 群晖 NAS LLM 一键部署套件

![License](https://img.shields.io/badge/license-MIT-green) ![Platform](https://img.shields.io/badge/DSM-7.x-blue) ![Arch](https://img.shields.io/badge/arch-x86__64%20%7C%20arm64-lightgrey)

**在群晖 NAS 上跑本地大模型，一条命令搞定。** 开箱即用：Ollama（模型引擎）+ Open WebUI（聊天界面），含低配 NAS 优化参数、模型推荐、状态监控和卸载脚本。

市面上群晖跑 LLM 全是"保姆教程"——这篇帖子告诉你装这个装那个，那篇教程参数写得不对。本套件是**开箱即用的产品**：下载 → 跑一个脚本 → 浏览器打开聊天界面。

## 适用机型

| 机型系列 | 内存 | 推荐模型 |
|---------|------|---------|
| DS220+/DS223+ | 4-8GB | qwen2.5:1.5b / llama3.2:1b |
| DS920+/DS1522+ | 8-16GB | qwen2.5:7b / gemma3:4b |
| DS1821+/RS 系列 | 16GB+ | qwen2.5:14b / llama3.3:8b |

> 架构要求：x86_64（Intel/AMD）或 arm64（部分新款）。DSM 7.x + Docker（Container Manager）。

## 快速开始

### 方式 A：Container Manager（推荐，无需 SSH 知识）

1. 下载本仓库 zip 并解压到 NAS（如 `/volume1/docker/nas-llm-stack`）
2. 打开 **Container Manager** → **项目** → **新建**
3. 项目名称填 `nas-llm`，路径选解压目录
4. 来源选「使用现有 docker-compose.yml」，点击「下一步」→ 创建
5. 首次启动后进容器 `nas-ollama` 的「终端机」执行 `ollama pull qwen2.5:7b` 下载模型
6. 浏览器打开 `http://<NAS-IP>:3000`，注册管理员，开聊

### 方式 B：SSH 一条命令

```bash
# 在 NAS 上（需已启用 SSH）
cd /volume1/docker
git clone https://github.com/wholegale39/nas-llm-stack.git
cd nas-llm-stack
bash scripts/install.sh        # 自动检测环境 → 选模型 → 启动 → 下载 → 健康检查
```

脚本会引导你：
1. 检测架构 / 内存 / 磁盘，按配置给出模型建议
2. 选择要下载的模型（qwen2.5 系列等，自动匹配内存）
3. 启动容器（自动识别 compose 或逐容器启动）
4. 下载模型 + 健康检查，最后打印访问地址

## 常用命令

```bash
bash scripts/status.sh                  # 容器状态 + 模型列表 + 资源占用
bash scripts/model.sh list              # 已安装模型
bash scripts/model.sh pull qwen2.5:7b   # 下载新模型
bash scripts/model.sh rm qwen2.5:7b     # 删除模型
bash scripts/model.sh recommend         # 按内存推荐模型
bash scripts/stop.sh                    # 停止（保留数据）
bash scripts/uninstall.sh               # 卸载（可选删数据）
```

## 目录结构

```
nas-llm-stack/
├── docker-compose.yml     # Ollama + Open WebUI 编排
├── scripts/
│   ├── install.sh         # 一键部署（环境检测/模型选择/启动/健康检查）
│   ├── status.sh          # 状态查看
│   ├── model.sh           # 模型管理（list/pull/rm/recommend）
│   ├── stop.sh            # 停止
│   └── uninstall.sh       # 卸载
├── data/                  # 运行数据（模型/配置，备份此目录即可）
└── tests/test_stack.sh    # 套件自检（22 项）
```

## 为什么专门做低配优化

NAS 不是 GPU 服务器，跑 LLM 最大的坑是 **OOM 和卡死**。套件内置：

- `OLLAMA_NUM_PARALLEL=1` — 串行处理，避免并发把内存打爆
- `OLLAMA_KEEP_ALIVE=30m` — 模型驻留 30 分钟，避免反复加载
- `deploy.resources.limits` — 容器内存上限，OOM 时只崩容器不崩 NAS
- 安装时按内存自动推荐模型档位，8GB 机子不会让你去拉 70B

## 常见问题

**Q: 首次打开 3000 端口很慢？**
Open WebUI 首次启动要初始化数据库和模型列表，等 1-2 分钟再刷。

**Q: 想从局域网外访问？**
不要在路由器上直接映射端口。用群晖 QuickConnect 反向代理，或套件中心装 Tailscale 走 VPN。

**Q: 模型下载太慢？**
Ollama 默认走官方 registry，国内网络可设置镜像：在 Container Manager 里给 ollama 容器加环境变量 `OLLAMA_HOST` 保持默认，模型改用国内可访问的镜像源（如 modelscope 导出的 GGUF，`ollama create` 本地导入）。

**Q: 跑起来很卡？**
降级模型（7B → 3B → 1.5B）。低配 NAS 跑 1.5B 日常问答完全够用。

## 路线图

- [x] 一键部署脚本（环境检测/模型选择/健康检查）
- [x] compose + 无 compose 双模式（兼容群晖 Container Manager 和原生 Docker）
- [x] 模型管理 + 状态监控脚本
- [x] 低配 NAS 优化（并发/内存/模型档位推荐）
- [ ] Container Manager 项目模板（GUI 双击导入）
- [ ] 离线翻译网关（NAS 本地翻译 API）
- [ ] 模型按需下载回收（闲置自动卸载）

## 测试

```bash
bash tests/test_stack.sh    # 22 项：语法/文件/逻辑/权限
```

## 许可证

MIT
