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

# 生成随机密码（32位hex，用于 PG/Redis 等）
gen_password() {
    openssl rand -hex 16 2>/dev/null || head -c 32 /dev/urandom | xxd -p | tr -d '\n' | head -c 32
}

# 首次部署：从模板生成 .env 并自动填充密码
if [ ! -f .env ]; then
    echo "=========================================="
    echo "  首次部署：自动生成配置"
    echo "=========================================="
    cp .env.example .env

    # 自动生成所有密码和密钥
    PG_PASS=$(gen_password)
    REDIS_PASS=$(gen_password)
    JWT_SEC=$(gen_secret)
    TOTP_KEY=$(gen_secret)

    sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${PG_PASS}|" .env
    sed -i "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=${REDIS_PASS}|" .env
    sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${JWT_SEC}|" .env
    sed -i "s|^TOTP_ENCRYPTION_KEY=.*|TOTP_ENCRYPTION_KEY=${TOTP_KEY}|" .env

    echo ""
    echo "  已自动生成以下密码/密钥（保存在 .env 中）:"
    echo "    POSTGRES_PASSWORD = ${PG_PASS}"
    echo "    REDIS_PASSWORD    = ${REDIS_PASS}"
    echo "    JWT_SECRET        = ${JWT_SEC}"
    echo "    TOTP_ENCRYPTION_KEY = ${TOTP_KEY}"
    echo ""
    echo "  管理员账号: admin@sub2api.local"
    echo "  管理员密码: 首次启动后查看日志获取"
    echo "    docker compose logs sub2api | grep -i password"
    echo ""
    echo "  如需自定义管理员密码，编辑 .env 中的 ADMIN_PASSWORD"
    echo "    nano $SCRIPT_DIR/.env"
    echo ""
fi

echo "=========================================="
echo "  Sub2API 部署"
echo "=========================================="
echo ""
echo "  构建并启动所有服务..."
echo "  （首次构建需要下载依赖，可能需要几分钟）"
echo ""

docker compose up -d --build

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo ""
echo "  访问地址: http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):${SERVER_PORT:-8080}"
echo "  查看日志: cd $SCRIPT_DIR && docker compose logs -f sub2api"
echo "  停止服务: cd $SCRIPT_DIR && docker compose down"
echo ""
