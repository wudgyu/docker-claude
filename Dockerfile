FROM node:22-bookworm-slim

# 系统依赖放在 ARG 之前：改 UID/GID/NPM_REGISTRY 不会使该层缓存失效
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq less ripgrep procps \
 && rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000
ARG USERNAME=claude
ARG NPM_REGISTRY=https://registry.npmjs.org

# 复用 node 镜像自带的 UID/GID 1000，改名为容器用户名
RUN if [ "${UID}" = "0" ] || [ "${GID}" = "0" ]; then \
      echo "error: UID/GID 0 is not supported (Claude Code refuses bypass mode as root)" >&2; \
      exit 1; \
    fi \
 && groupmod -n "${USERNAME}" -g "${GID}" node \
 && usermod -l "${USERNAME}" -u "${UID}" -d "/home/${USERNAME}" -m -g "${GID}" node

RUN npm config set registry "${NPM_REGISTRY}" \
 && npm install -g @anthropic-ai/claude-code \
 && npm cache clean --force

USER ${USERNAME}
ENV HOME=/home/${USERNAME}
ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"
ENV DISABLE_AUTOUPDATER=1

ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
