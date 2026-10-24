# Claude Code Docker: 完全自动模式

在容器内以 `bypassPermissions` 模式运行 Claude Code，挂载宿主机工作区，
不出现权限确认或 read-block 提示。适合在隔离环境里无人值守地跑任务。

## 前置条件

- Docker 与 `docker-compose`
- 宿主机上有可用的 Claude Code 配置（`~/.claude/settings.json` 或环境变量）
- 可选：`jq`，用于自动导出宿主机配置

## 快速开始

```bash
cd docker/claude
WORKSPACE_HOST_DIR="$HOME/workspace" ./run.sh
```

不要用 `sudo ./run.sh`：脚本会把 `uid/gid` 当作构建参数，root 会导致
`GID '0' already exists`，且 Claude Code 拒绝以 root 运行 bypass 模式。

如果当前用户不能直接访问 Docker：

```bash
# 把当前用户加入 docker 组（需重新登录或 newgrp）
sudo usermod -aG docker "$USER" && newgrp docker
```

首次运行会自动完成：

1. 创建 `~/.claude-docker/`（可用 `CLAUDE_DOCKER_CONFIG_DIR` 覆盖）；
2. 写入开启完全自动模式的 `settings.json`；
3. 从 `~/.claude/settings.json` 的 `env` 段导出模型/网关配置到 `claude.env`；
4. 复制 `~/.claude.json`，复用引导状态和项目信任记录；
5. 构建镜像并启动容器。

也可以分步执行：

```bash
./init-host.sh
docker-compose build
docker-compose run --rm claude
```

`run.sh` 的参数会透传给 `claude`，例如 `./run.sh --resume`。

## 配置项

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `WORKSPACE_HOST_DIR` | `$HOME/workspace` | 挂载到容器内同一绝对路径的工作区 |
| `CLAUDE_DOCKER_CONFIG_DIR` | `$HOME/.claude-docker` | 容器专用配置目录，挂载为 `/config` |
| `CONTAINER_USER` | `claude` | 容器内用户名 |
| `HOST_UID` / `HOST_GID` | 当前用户 | 构建参数，默认由 `run.sh` 注入 |
| `NPM_REGISTRY` | `https://registry.npmjs.org` | 构建时的 npm 源 |
| `TZ` | `UTC` | 容器时区 |

`claude.env` 支持两种认证方式，二选一：

```dotenv
ANTHROPIC_API_KEY=sk-ant-...
```

或兼容 Anthropic 协议的第三方网关：

```dotenv
ANTHROPIC_BASE_URL=https://your-gateway.example.com
ANTHROPIC_AUTH_TOKEN=...
ANTHROPIC_MODEL=your-model
```

修改后重新运行即可，`claude.env` 不会被写入镜像。

## 工作原理

- 容器以非 root 用户运行；`--dangerously-skip-permissions` 不允许 root。
- 系统依赖层位于 `ARG` 之前，修改 UID/GID 或 npm 源不会导致 apt 层重跑。
- 工作区在容器内保持与宿主机相同的绝对路径，项目信任记录可直接复用。
- `CLAUDE_CONFIG_DIR=/config` 指向挂载的独立目录，不修改宿主机 `~/.claude`。
- `settings.json` 中不包含 `blockReadsOutsideWorkingDirectories`，因此不会出现
  “变量/引号无法静态分析”一类确认。

## 安全提示

- `bypassPermissions` 等同于关闭所有权限确认，只在可信工作区和隔离容器中使用。
- 不要挂载 `/var/run/docker.sock`，否则容器内进程可获得宿主机 root 权限。
- `claude.env` 含密钥，已在 `.gitignore` 中排除，请勿提交。
