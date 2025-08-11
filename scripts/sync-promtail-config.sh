#!/bin/bash

# Promtail 配置同步脚本
# 从 Nacos 配置中心获取日志采集规则并更新到本地

set -e

NACOS_HOST="${NACOS_HOST:-nacos:8848}"
NACOS_NAMESPACE="${NACOS_NAMESPACE:-public}"
NACOS_GROUP="${NACOS_GROUP:-DEFAULT_GROUP}"
NACOS_DATA_ID="${NACOS_DATA_ID:-promtail-selectors}"
NACOS_USERNAME="${NACOS_USERNAME:-nacos}"
NACOS_PASSWORD="${NACOS_PASSWORD:-nacos}"

TARGET_FILE="/sd/selectors.yml"
TEMP_FILE="/tmp/selectors.yml.tmp"

echo "Starting Promtail config sync from Nacos..."

while true; do
    echo "$(date): Fetching config from Nacos..."
    
    # 先获取访问令牌
    TOKEN_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${NACOS_USERNAME}&password=${NACOS_PASSWORD}" \
        "http://${NACOS_HOST}/nacos/v1/auth/login" 2>/dev/null || echo "")
    
    if [ -n "${TOKEN_RESPONSE}" ]; then
        ACCESS_TOKEN=$(echo "${TOKEN_RESPONSE}" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "${ACCESS_TOKEN}" ]; then
            echo "$(date): Successfully obtained access token"
            # 使用 accessToken 获取配置
            CONFIG_URL="http://${NACOS_HOST}/nacos/v1/cs/configs?dataId=${NACOS_DATA_ID}&group=${NACOS_GROUP}&tenant=${NACOS_NAMESPACE}&accessToken=${ACCESS_TOKEN}"
            echo "$(date): Requesting config from: ${CONFIG_URL}"
            
            if curl -s -f "${CONFIG_URL}" -o "${TEMP_FILE}"; then
                echo "$(date): Successfully fetched config from Nacos"
                # 检查配置内容是否有效
                if [ -s "${TEMP_FILE}" ] && grep -q "targets:" "${TEMP_FILE}" 2>/dev/null; then
                    # 比较文件内容，只有变化时才更新
                    if ! cmp -s "${TEMP_FILE}" "${TARGET_FILE}" 2>/dev/null; then
                        echo "$(date): Config changed, updating ${TARGET_FILE}"
                        mv "${TEMP_FILE}" "${TARGET_FILE}"
                        echo "$(date): Config updated successfully"
                    else
                        echo "$(date): Config unchanged"
                        rm -f "${TEMP_FILE}"
                    fi
                else
                    echo "$(date): Config not found or empty, creating default config"
                    # 创建默认的空配置
                    cat > "${TARGET_FILE}" << EOF
# Auto-generated service discovery targets from Nacos
# This file is managed by promtail-config-sync service
targets: []
EOF
                    rm -f "${TEMP_FILE}"
                fi
            else
                echo "$(date): Failed to fetch config from Nacos API"
                # 显示详细错误信息
                curl -v "${CONFIG_URL}" 2>&1 || true
                rm -f "${TEMP_FILE}"
            fi
        else
            echo "$(date): Failed to extract access token from response: ${TOKEN_RESPONSE}"
        fi
    else
        echo "$(date): Failed to authenticate with Nacos - no response"
    fi
    
    # 等待 30 秒后再次检查
    sleep 30
done
