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

# 清理过期数据文件（保留昨天和今天的数据）
# 参数1: 保留的最新数据日期码（8位，如20260415）
cleanup_old_files() {
    local keep_date=$1
    local keep_date_formatted="${keep_date:0:4}-${keep_date:4:2}-${keep_date:6:2}"

    log "开始清理过期数据文件..."

    # 转换为时间戳进行比较
    local keep_timestamp=$(date -d "$keep_date_formatted" +%s)
    local deleted_count=0

    # 遍历数据目录中的所有带日期的json文件（包括merged文件和普通数据文件）
    for file in "$DATA_DIR"/*-2026*.json "$DATA_DIR"/merged-*.json; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")

            # 处理8位日期码的数据文件（如 gpu_daily_stats-20260415.json）
            if [[ "$filename" =~ -([0-9]{8})\.json$ ]]; then
                date_code="${BASH_REMATCH[1]}"
                file_date="${date_code:0:4}-${date_code:4:2}-${date_code:6:2}"
                file_timestamp=$(date -d "$file_date" +%s 2>/dev/null)

                if [ -n "$file_timestamp" ] && [ "$file_timestamp" -lt "$keep_timestamp" ]; then
                    rm -f "$file"
                    log "已清理过期文件: $filename"
                    ((deleted_count++))
                fi
            fi

            # 处理6位日期码的merged文件（如 merged-260413.json）
            if [[ "$filename" =~ ^merged-([0-9]{6})\.json$ ]]; then
                date_code_6="${BASH_REMATCH[1]}"
                # 转换6位日期码为标准日期 (260413 -> 2026-04-13)
                file_date="20${date_code_6:0:2}-${date_code_6:2:2}-${date_code_6:4:2}"
                file_timestamp=$(date -d "$file_date" +%s 2>/dev/null)

                if [ -n "$file_timestamp" ] && [ "$file_timestamp" -lt "$keep_timestamp" ]; then
                    rm -f "$file"
                    log "已清理过期文件: $filename"
                    ((deleted_count++))
                fi
            fi
        fi
    done

    log "清理完成: 已删除 $deleted_count 个过期文件"
}

# 下载并分割合并的JSON文件
# 参数1: 下载的merged文件日期码 (6位，如260416)
# 参数2: 输出的数据文件日期码 (8位，如20260415)
download_and_split() {
    local download_code=$1
    local output_code=$2
    local merged_file="merged-${download_code}.json"
    local url="$ARTIFACTORY_URL/$merged_file"
    local temp_output="$DATA_DIR/${merged_file}.tmp"

    log "开始下载: $merged_file"
    log "URL: $url"

    # 清理可能存在的残留临时文件
    rm -f "$temp_output" "$DATA_DIR/$merged_file"

    # 下载合并文件
    if curl -s -o "$temp_output" -u "${AUTH_USER}:${AUTH_PASS}" "$url" 2>&1; then
        # 检查文件是否为空
        if [ -s "$temp_output" ]; then
            # 验证 JSON 格式
            if jq empty "$temp_output" 2>/dev/null; then
                mv "$temp_output" "$DATA_DIR/$merged_file"
                log "✓ 下载成功: $merged_file"

                # 分割JSON文件，使用输出日期码
                split_json_file "$DATA_DIR/$merged_file" "$output_code"
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
# 参数1: 输入文件路径
# 参数2: 输出的8位日期码 (如 20260415)
split_json_file() {
    local input_file=$1
    local date_code_8digit=$2
    local temp_dir="/tmp/split_json_${date_code_8digit}"

    log "开始分割JSON文件..."

    # 创建临时目录
    mkdir -p "$temp_dir"

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
# 参数1: 可选的日期码（8位，如20260415），如果不提供则从文件扫描
generate_latest_json() {
    local provided_date_code=$1

    # 如果提供了日期码，直接使用；否则从文件扫描
    if [[ -n "$provided_date_code" ]]; then
        local date_code=$provided_date_code
        local latest_date="${date_code:0:4}-${date_code:4:2}-${date_code:6:2}"
    else
        local latest_date=$(find_latest_data_date)
        if [[ -z "$latest_date" ]]; then
            log "警告: 无法找到最新数据日期"
            return 1
        fi
        local date_code=$(date -d "$latest_date" +%Y%m%d)
    fi

    # 计算90天前的日期
    local earliest_date=$(date -d "$latest_date - $DATE_RANGE_DAYS days" +%Y-%m-%d)

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

# 获取日期码
TODAY_CODE=$(get_today_date_code)      # 今天日期码 (260416)
YESTERDAY_CODE_6=$(get_yesterday_date_code)  # 昨天日期码6位 (260415)
YESTERDAY_CODE_8=$(date -d "yesterday" +%Y%m%d)  # 昨天日期码8位 (20260415)

# 优先下载今天的合并文件（包含昨天的完整数据）
log "尝试下载今天的最新数据 (日期码: $TODAY_CODE)"
if download_and_split "$TODAY_CODE" "$YESTERDAY_CODE_8"; then
    DATE_CODE=$YESTERDAY_CODE_8
    log "今天数据下载成功"
else
    # 如果今天的文件下载失败，尝试昨天的合并文件
    log "今天的文件下载失败，尝试昨天的数据 (日期码: $YESTERDAY_CODE_6)"
    # 昨天合并文件对应的输出日期也是昨天
    YESTERDAY_CODE_8_FALLBACK=$(date -d "yesterday" +%Y%m%d)
    if download_and_split "$YESTERDAY_CODE_6" "$YESTERDAY_CODE_8_FALLBACK"; then
        DATE_CODE=$YESTERDAY_CODE_8_FALLBACK
        log "昨天数据下载成功"
    else
        log "========== 数据下载失败 =========="
        exit 1
    fi
fi

# 生成元数据
generate_latest_json "$DATE_CODE"

# 清理过期数据文件（保留昨天和今天的数据）
cleanup_old_files "$DATE_CODE"

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