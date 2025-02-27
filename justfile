# DevDocs 项目 Justfile
# 用于简化项目的设置和启动流程

# 项目目录
root_dir := justfile_directory()
storage_dir := root_dir / "storage" / "markdown"
mcp_dir := root_dir / "fast-markdown-mcp"
backend_dir := root_dir / "backend"
logs_dir := root_dir / "logs"

# 配置服务端口
frontend_port := "3001"
backend_port := "24125"

# 默认目标
default:
    @just --list

# 检查端口是否被占用并杀死进程
check-ports:
    #!/usr/bin/env bash
    echo "检查端口占用情况..."
    if lsof -ti:{{frontend_port}} > /dev/null; then
        echo "端口 {{frontend_port}} 被占用，正在终止进程..."
        lsof -ti:{{frontend_port}} | xargs kill -9
    fi
    if lsof -ti:{{backend_port}} > /dev/null; then
        echo "端口 {{backend_port}} 被占用，正在终止进程..."
        lsof -ti:{{backend_port}} | xargs kill -9
    fi
    echo "Done"

# 创建必要的目录
create-dirs:
    #!/usr/bin/env bash
    echo "检查/创建必要的目录..."
    mkdir -p {{logs_dir}}
    mkdir -p {{storage_dir}}

# 安装前端依赖
install-frontend:
    #!/usr/bin/env bash
    echo "安装前端依赖..."
    pnpm install
    echo "Done"

# 安装后端依赖
install-backend:
    #!/usr/bin/env bash
    echo "安装后端依赖..."
    cd {{backend_dir}} && \
    uv sync
    echo "Done"

# 安装 MCP 服务依赖
install-mcp:
    #!/usr/bin/env bash
    echo "安装 MCP 服务依赖..."
    cd {{mcp_dir}} && \
    uv sync
    echo "Done"

# 设置环境
setup: create-dirs install-frontend install-backend install-mcp
    #!/usr/bin/env bash
    echo "设置完成!"
    echo "已安装:"
    echo "- npm 依赖"
    echo "- Python 后端依赖"
    echo "- MCP 服务依赖"
    echo "已配置:"
    echo "- Markdown 存储目录: {{storage_dir}}"
    echo "下一步:"
    echo "- 使用 just start 启动所有服务"
    echo "您的 DevDocs 环境已准备就绪!"

# 启动前端
run-frontend:
    #!/usr/bin/env bash
    echo "启动前端服务 (端口 {{frontend_port}})..."
    PORT={{frontend_port}} npm run dev > {{logs_dir}}/frontend.log 2>&1 &
    echo $! > {{logs_dir}}/frontend.pid
    echo "前端服务已启动! 访问 http://localhost:{{frontend_port}}"

# 启动后端
run-backend:
    #!/usr/bin/env bash
    echo "启动后端服务 (端口 {{backend_port}})..."
    cd {{backend_dir}} && \
    uv sync && \
    uvicorn app.main:app --host 0.0.0.0 --port {{backend_port}} --reload > {{root_dir}}/{{logs_dir}}/backend.log 2>&1 &
    echo $! > {{logs_dir}}/backend.pid
    echo "后端服务已启动! 访问 http://localhost:{{backend_port}}"

# 启动 MCP 服务
run-mcp:
    #!/usr/bin/env bash
    echo "启动 MCP 服务..."
    cd {{mcp_dir}} && \
    source venv/bin/activate && \
    PYTHONPATH="{{mcp_dir}}/src" \
    {{mcp_dir}}/venv/bin/python -m fast_markdown_mcp.server \
    "{{storage_dir}}" > {{root_dir}}/{{logs_dir}}/mcp.log 2>&1 &
    echo $! > {{logs_dir}}/mcp.pid
    echo "MCP 服务已启动!"

# 等待服务就绪
wait-services:
    #!/usr/bin/env bash
    echo "等待服务就绪..."
    for i in {1..30}; do
        if nc -z localhost {{frontend_port}} && nc -z localhost {{backend_port}}; then
            echo "所有服务已就绪!"
            break
        fi
        echo "等待服务启动中... ($i/30)"
        sleep 1
    done

# 启动所有服务
start: check-ports create-dirs run-frontend run-backend run-mcp wait-services
    #!/usr/bin/env bash
    echo "所有服务已启动!"
    echo "前端: http://localhost:{{frontend_port}}"
    echo "后端: http://localhost:{{backend_port}}"
    echo "日志: ./logs/"
    echo "使用 just stop 停止所有服务"
    if [ "$(uname)" = "Darwin" ]; then
        open http://localhost:{{frontend_port}}
    elif [ "$(uname)" = "Linux" ]; then
        xdg-open http://localhost:{{frontend_port}}
    fi

# 停止所有服务
stop:
    #!/usr/bin/env bash
    echo "停止所有服务..."
    if [ -f {{logs_dir}}/frontend.pid ]; then
        kill -9 `cat {{logs_dir}}/frontend.pid` 2>/dev/null || true
        rm {{logs_dir}}/frontend.pid
    fi
    if [ -f {{logs_dir}}/backend.pid ]; then
        kill -9 `cat {{logs_dir}}/backend.pid` 2>/dev/null || true
        rm {{logs_dir}}/backend.pid
    fi
    if [ -f {{logs_dir}}/mcp.pid ]; then
        kill -9 `cat {{logs_dir}}/mcp.pid` 2>/dev/null || true
        rm {{logs_dir}}/mcp.pid
    fi
    echo "所有服务已停止"

# 清理临时文件和日志
clean: stop
    #!/usr/bin/env bash
    echo "清理临时文件和日志..."
    rm -rf {{logs_dir}}/*
    echo "清理完成"
