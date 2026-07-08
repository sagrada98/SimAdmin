# ============================================
# SimAdmin 多架构 Docker 镜像
# 支持: linux/amd64, linux/arm64
# ============================================

# --- Stage 1: 前端构建 ---
FROM node:22-bookworm AS frontend-builder
# 重建 repo 目录结构，让相对路径引用正确解析
WORKDIR /build
COPY VERSION ./
COPY static/ static/
COPY frontend/ frontend/

WORKDIR /build/frontend
RUN corepack enable && pnpm install --frozen-lockfile
# Docker 内跳过 lint，直接用 vite 构建
RUN npx vite build --logLevel info

# --- Stage 2: 后端构建 ---
FROM rust:1-bookworm AS backend-builder
WORKDIR /app
COPY backend/ .
RUN cargo build --release && \
    cp target/release/simadmin /app/simadmin && \
    strip /app/simadmin

# --- Stage 3: 运行时 ---
FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY --from=backend-builder /app/simadmin /opt/simadmin/simadmin
COPY --from=frontend-builder /build/frontend/dist /opt/simadmin/www

WORKDIR /opt/simadmin
EXPOSE 3000

ENTRYPOINT ["./simadmin"]
CMD ["--host", "::", "--port", "3000"]
