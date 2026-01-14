# ===========================
# 构建阶段
# ===========================
FROM docker.m.daocloud.io/library/node:20-alpine AS builder

WORKDIR /app

# 使用国内 NPM 镜像源并安装 pnpm
RUN npm config set registry https://registry.npmmirror.com && \
    npm install -g pnpm@latest && \
    rm -rf /root/.npm

# 复制工作区配置文件
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json tsconfig.base.json ./
COPY scripts ./scripts

# 复制所有 packages
COPY packages ./packages

# 安装依赖（使用国内镜像）
RUN pnpm install --frozen-lockfile

# 构建所有包
RUN pnpm build

# ===========================
# 生产阶段
# ===========================
FROM docker.m.daocloud.io/library/node:20-alpine AS production

# 更换 Alpine 软件源为清华大学镜像，并安装 PM2
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && \
    apk add --no-cache curl && \
    npm config set registry https://registry.npmmirror.com && \
    npm install -g pm2 pm2-logrotate --no-scripts

WORKDIR /app

# 复制编译产物
COPY --from=builder /app/packages/server/dist ./packages/server/dist
COPY --from=builder /app/packages/server/node_modules ./packages/server/node_modules
COPY --from=builder /app/packages/core ./packages/core
COPY --from=builder /app/packages/ui/dist ./packages/server/dist

# 复制 PM2 配置
COPY packages/server/ecosystem.config.cjs ./

# 创建日志目录和Claude项目目录
RUN mkdir -p /root/.claude-code-router/logs && \
    mkdir -p /root/.claude/projects

EXPOSE 3456

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://127.0.0.1:3456/health || exit 1

CMD ["pm2-runtime", "start", "/app/ecosystem.config.cjs"]
