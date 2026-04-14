#!/bin/bash

# 数据自动下载脚本（合并文件版）
# 用途: 每日自动从 Artifactory 服务器下载并分割数据文件
# 定时任务: 30 8 * * * /home/bmc/sd1/CODE/AI_Data/playground/scripts/download-data.sh

# 加载配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# ========== 辅助函数 ==========

# 记录日志
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 备份现有数据文件
backup_files() {
    local backup_dir="$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    for type in "${DATA_FILES[@]}"; do
        # 找到最新的文件
        latest_file=$(ls -t "$DATA_DIR"/${type}-*.json 2>/dev/null | head -1)
        if [ -n "$latest_file" ] && [ -f "$latest_file" ]; then
            cp "$latest_file" "$backup_dir/"
            log "已备份: $(basename $latest_file) -> $backup_dir/"
        fi
    done

    # 清理超过7天的备份
    find "$BACKUP_DIR" -type d -mtime +$BACKUP_DAYS -exec rm -rf {} \; 2>/dev/null
}

# 下载并分割合并的JSON文件
download_and_split() {
    local date_code=$1
    local merged_file="merged-${date_code}.json"
    local url="$ARTIFACTORY_URL/$merged_file"
    local temp_output="$DATA_DIR/${merged_file}.tmp"

    log "开始下载: $merged_file"
    log "URL: $url"

    # 下载合并文件
    if curl -s -o "$temp_output" -u "${AUTH_USER}:${AUTH_PASS}" "$url" 2>&1; then
        # 检查文件是否为空
        if [ -s "$temp_output" ]; then
            # 验证 JSON 格式
            if jq empty "$temp_output" 2>/dev/null; then
                mv "$temp_output" "$DATA_DIR/$merged_file"
                log "✓ 下载成功: $merged_file"

                # 分割JSON文件
                split_json_file "$DATA_DIR/$merged_file" "$date_code"
                return $?
            else
                log "✗ JSON 格式无效: $merged_file"
                rm -f "$temp_output"
                return 1
            fi
        else
            log "✗ 文件为空: $merged_file"
            rm -f "$temp_output"
            return 1
        fi
    else
        log "✗ 下载失败: $merged_file"
        rm -f "$temp_output"
        return 1
    fi
}

# 分割JSON文件（按顶层键）
# 注意: 输入是6位日期码 (260413)，输出使用8位日期码 (20260413)
split_json_file() {
    local input_file=$1
    local date_code_6digit=$2
    local date_code_8digit=$(convert_to_8digit "$date_code_6digit")
    local temp_dir="/tmp/split_json_${date_code_6digit}"

    log "开始分割JSON文件..."

    # 创建临时目录
    mkdir -p "$temp_dir"

    # 备份旧文件
    backup_files

    # 获取所有顶层键 - 自动识别所有数据文件
    local keys=$(jq -r 'keys[]' "$input_file")

    local success_count=0
    local fail_count=0

    # 分割并保存文件 - 使用8位日期码命名
    for key in $keys; do
        # 自动分割所有键，不限制文件类型
        local output_file="${DATA_DIR}/${key}-${date_code_8digit}.json"

        # 直接提取对应键的value并保存（不包含键名）
        jq ".[\"${key}\"]" "$input_file" > "$output_file"

        # 验证输出文件
        if [ -s "$output_file" ] && jq empty "$output_file" 2>/dev/null; then
            log "✓ 已创建: $output_file"
            ((success_count++))
        else
            log "✗ 创建失败: $output_file"
            ((fail_count++))
        fi
    done

    # 清理临时目录
    rm -rf "$temp_dir"

    log "分割完成: 成功 $success_count, 失败 $fail_count"

    if [ $success_count -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# 查找最新数据的日期
find_latest_data_date() {
    local latest_date=""

    # 查找所有数据文件，获取最新日期
    for file in "$DATA_DIR"/*-*.json; do
        if [ -f "$file" ]; then
            # 提取日期码 (如 20260414 或 260414)
            local filename=$(basename "$file")
            local date_code=$(echo "$filename" | sed 's/.*-\([0-9]*\)\.json/\1/')

            # 8位格式: 20260414 -> 2026-04-14
            if [ ${#date_code} -eq 8 ]; then
                local full_date="${date_code:0:4}-${date_code:4:2}-${date_code:6:2}"
            else
                # 兼容6位格式: 260414 -> 2026-04-14
                local full_date="20${date_code:0:2}-${date_code:2:2}-${date_code:4:2}"
            fi

            if [[ -z "$latest_date" ]] || [[ "$full_date" > "$latest_date" ]]; then
                latest_date="$full_date"
            fi
        fi
    done

    echo "$latest_date"
}

# 生成 latest.json 元数据
generate_latest_json() {
    local latest_date=$(find_latest_data_date)

    if [[ -z "$latest_date" ]]; then
        log "警告: 无法找到最新数据日期"
        return 1
    fi

    # 计算90天前的日期
    local earliest_date=$(date -d "$latest_date - $DATE_RANGE_DAYS days" +%Y-%m-%d)

    # 转换为8位日期码 (YYYYMMDD), 如 2026-04-13 -> 20260413
    local date_code=$(date -d "$latest_date" +%Y%m%d)

    # 获取文件列表信息 - 获取所有8位日期码的数据文件
    local files_json="["
    local first=true
    for file in "$DATA_DIR"/*-${date_code}.json; do
        if [ -f "$file" ]; then
            size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            name=$(basename "$file")

            if [ "$first" = true ]; then
                first=false
            else
                files_json+=","
            fi

            files_json+="{\"name\":\"$name\",\"size\":$size}"
        fi
    done
    files_json+="]"

    # 生成 JSON 文件
    cat > "$LATEST_FILE" <<EOF
{
  "updateTime": "$(date '+%Y-%m-%d %H:%M:%S')",
  "dataDate": "$date_code",
  "dateRange": {
    "latest": "$latest_date",
    "earliest": "$earliest_date"
  },
  "files": $files_json
}
EOF

    log "✓ 元数据已更新: latest.json"
    log "  数据日期码: $date_code (${latest_date})"
    log "  日期范围: $earliest_date ~ $latest_date"
}

# ========== 主流程 ==========

log "========== 开始数据同步 =========="

# 获取日期码（优先昨天，如果没有则今天）
DATE_CODE=$(get_yesterday_date_code)
TODAY_CODE=$(get_today_date_code)

# 首先尝试昨天的合并文件
log "尝试下载昨天的数据 (日期码: $DATE_CODE)"
if download_and_split "$DATE_CODE"; then
    log "昨天数据下载成功"
else
    # 如果昨天的文件下载失败，尝试今天的文件
    log "昨天的文件下载失败，尝试今天的文件 (日期码: $TODAY_CODE)"
    if download_and_split "$TODAY_CODE"; then
        DATE_CODE=$TODAY_CODE
        log "今天数据下载成功"
    else
        log "========== 数据下载失败 =========="
        exit 1
    fi
fi

# 生成元数据
generate_latest_json

log "========== 数据同步完成 =========="

# 记录数据版本信息
log "数据版本信息:"
for type in "${DATA_FILES[@]}"; do
    latest_file=$(ls -t "$DATA_DIR"/${type}-*.json 2>/dev/null | head -1)
    if [ -n "$latest_file" ]; then
        size=$(stat -c%s "$latest_file" 2>/dev/null || echo 0)
        log "  - $(basename $latest_file): $size bytes"
    fi
done

exit 0