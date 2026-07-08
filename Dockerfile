# ============================================
# SimAdmin 多架构 Docker 镜像
# 支持: linux/amd64, linux/arm64
# ============================================

# --- Stage 1: 前端构建 ---
FROM node:22-bookworm AS frontend-builder
WORKDIR /app
COPY frontend/pnpm-workspace.yaml ./
COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY frontend/ .
# Docker 内跳过 lint，直接用 vite 构建
RUN pnpm exec vite build

# --- Stage 2: 后端构建 ---
FROM rust:1-bookworm AS backend-builder
WORKDIR /app
COPY backend/ .
RUN cargo build --release && \
    cp target/release/simadmin /app/simadmin && \
    cp target/release/simadmin /tmp/simadmin.debug && \
    strip /app/simadmin

# --- Stage 3: 运行时 ---
FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 二进制 + 前端静态文件
COPY --from=backend-builder /app/simadmin /opt/simadmin/simadmin
COPY --from=frontend-builder /app/dist /opt/simadmin/www

WORKDIR /opt/simadmin
EXPOSE 3000

ENTRYPOINT ["./simadmin"]
CMD ["--host", "::", "--port", "3000"]
