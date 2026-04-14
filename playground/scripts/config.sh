#!/bin/bash
# 数据同步配置
# 用途: 集中管理数据同步的参数

# ========== 基础配置 ==========

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 数据存放目录
DATA_DIR="/home/bmc/sd1/CODE/AI_Data/playground/src/assets/data-display"

# ========== Artifactory 配置 ==========

# Artifactory 服务器地址
ARTIFACTORY_URL="http://10.32.129.210:8081/artifactory/rdemp-ai-analysis"

# 认证信息
AUTH_USER="fw-reader"
AUTH_PASS="Fr@20250122"

# ========== 数据文件配置 ==========

# 数据文件类型列表
DATA_FILES=(
    "gpu_daily_stats"
    "openapi_users"
    "usagerate"
    "vllm_daily_stats"
)

# 数据保留天数
BACKUP_DAYS=7

# ========== 日期配置 ==========

# 日期范围（天）
DATE_RANGE_DAYS=90

# 备份目录
BACKUP_DIR="$DATA_DIR/backup"

# 日志文件
LOG_FILE="$DATA_DIR/sync.log"

# 元数据文件
LATEST_FILE="$DATA_DIR/latest.json"

# ========== 定时任务配置 ==========

# 执行时间: 每天 08:30
CRON_TIME="30 8 * * *"

# 获取昨日日期码 (格式: YYMMDD)
get_yesterday_date_code() {
    date -d "yesterday" +%y%m%d
}

# 获取今日日期码 (格式: YYMMDD)
get_today_date_code() {
    date +%y%m%d
}

# 辅助函数：记录日志
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}