#!/bin/bash

# Cron 定时任务配置脚本
# 用途: 设置每日 08:30 自动执行数据下载脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_SCRIPT="$SCRIPT_DIR/download-data.sh"
CRON_JOB="30 8 * * * $DOWNLOAD_SCRIPT >> /home/bmc/sd1/CODE/AI_Data/playground/src/assets/data-display/sync.log 2>&1"

echo "========== Cron 定时任务配置 =========="
echo ""

# 检查脚本是否存在
if [ ! -f "$DOWNLOAD_SCRIPT" ]; then
    echo "✗ 错误: 下载脚本不存在: $DOWNLOAD_SCRIPT"
    exit 1
fi

# 检查脚本是否有执行权限
if [ ! -x "$DOWNLOAD_SCRIPT" ]; then
    echo "✗ 错误: 下载脚本没有执行权限"
    echo "请执行: chmod +x $DOWNLOAD_SCRIPT"
    exit 1
fi

echo "✓ 下载脚本已就绪: $DOWNLOAD_SCRIPT"
echo ""

# 显示当前 crontab
echo "当前 Crontab:"
crontab -l 2>/dev/null || echo "(无定时任务)"
echo ""

# 添加定时任务
echo "添加定时任务..."
echo "$CRON_JOB" | crontab -

echo "✓ 定时任务已添加"
echo ""
echo "定时任务内容:"
echo "$CRON_JOB"
echo ""
echo "执行时间: 每天 08:30"
echo ""

# 验证
echo "验证 Crontab:"
crontab -l
echo ""
echo "========== 配置完成 =========="
echo ""
echo "提示: 可以使用以下命令查看同步日志"
echo "  tail -f /home/bmc/sd1/CODE/AI_Data/playground/src/assets/data-display/sync.log"
echo ""
echo "提示: 立即执行一次同步命令"
echo "  $DOWNLOAD_SCRIPT"