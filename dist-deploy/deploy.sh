#!/bin/bash
# =============================================================================
# Sub2API 一键部署脚本
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 生成随机密钥（64位hex = 32字节，满足 TOTP/JWT 要求）
gen_secret() {
    openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | xxd -p | tr -d '\n' | head -c 64
}

FIRST_DEPLOY=false

# 首次部署：从模板生成 .env，只生成 JWT/TOTP 密钥
# PG/Redis 密码已固定在 .env.example 中，不重新生成
if [ ! -f .env ]; then
    FIRST_DEPLOY=true
    echo "=========================================="
    echo "  首次部署：自动生成配置"
    echo "=========================================="
    cp .env.example .env

    # 只生成 JWT 和 TOTP 密钥（PG/Redis 密码已固定）
    JWT_SEC=$(gen_secret)
    TOTP_KEY=$(gen_secret)

    sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${JWT_SEC}|" .env
    sed -i "s|^TOTP_ENCRYPTION_KEY=.*|TOTP_ENCRYPTION_KEY=${TOTP_KEY}|" .env

    # 交互式设置管理员密码
    echo ""
    echo "  设置管理员密码（直接回车则自动生成，首次启动后从日志查看）:"
    printf "  ADMIN_PASSWORD> "
    read -r ADMIN_PASS
    if [ -n "$ADMIN_PASS" ]; then
        sed -i "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASS}|" .env
    fi

    echo ""
    echo "  ========== 配置生成完毕 =========="
    echo ""
    echo "  管理员账号: admin@sub2api.local"
    if [ -n "$ADMIN_PASS" ]; then
        echo "  管理员密码: （已设置为你输入的密码）"
    else
        echo "  管理员密码: 首次启动后查看日志获取"
        echo "    docker compose logs sub2api | grep -i password"
    fi
    echo ""
fi

echo "=========================================="
echo "  Sub2API 部署"
echo "=========================================="
echo ""

if [ "$FIRST_DEPLOY" = true ]; then
    echo "  首次构建（无缓存），需要下载依赖，可能需要较长时间..."
    echo ""
    docker compose build --no-cache
    docker compose up -d
else
    echo "  增量构建并启动..."
    echo ""
    docker compose up -d --build
fi

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo ""
echo "  访问地址: http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):${SERVER_PORT:-8080}"
echo "  查看日志: cd $SCRIPT_DIR && docker compose logs -f sub2api"
echo "  停止服务: cd $SCRIPT_DIR && docker compose down"
echo ""
