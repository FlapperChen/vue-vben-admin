#!/usr/bin/env python3
"""
Coredump 分析脚本（打桩版本）
用法: python analyze_coredump.py <filepath>
"""
import json
import os
import sys
from datetime import datetime


def analyze_coredump(filepath: str) -> dict:
    """分析 coredump 文件（打桩版本）"""
    filename = os.path.basename(filepath)
    file_ext = os.path.splitext(filename)[1].lower()

    # 根据文件扩展名返回不同的打桩报告
    if file_ext == '.core':
        report = f"""# Coredump 分析报告

## 文件信息
- **文件名**: {filename}
- **路径**: {filepath}
- **分析时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## 分析结果

### 基本信息
| 项目 | 值 |
|------|-----|
| 进程名称 | example_process |
| 崩溃时间 | {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} |
| 信号 | SIGSEGV (11) |
| 崩溃地址 | 0x0000000000000000 |

### 堆栈信息
```
#0  0x00007f8a3c4d5a37 in __GI_raise (sig=signo=11) at ../sysdeps/unix/sysv/linux/raise.c:51
#1  0x00007f8a3c4d7028 in __GI_abort () at abort.c:79
#2  0x0000562e5a4c8f3a in process_request (conn=0x7fff12345678) at src/processor.c:123
#3  0x0000562e5a4c9a1b in main (argc=1, argv=0x7fff12345690) at src/main.c:45
```

### 可能的根因
1. **空指针解引用** - 堆栈显示在 `process_request` 中发生崩溃
2. **内存越界访问** - `conn` 指针可能已释放或未初始化
3. **线程安全问题** - 多线程环境下的竞态条件

### 建议
- 检查 `src/processor.c:123` 行的 `conn` 指针使用
- 增加边界检查和空指针验证
- 考虑使用 AddressSanitizer 进行调试
- 审查线程同步机制

### 相关代码位置
- `src/processor.c:123` - process_request 函数
- `src/main.c:45` - main 函数入口
- `include/connection.h` - 连接结构体定义

---
*此为自动生成的分析报告，仅供参考*
"""
    else:
        report = f"""# 文件分析报告

## 文件信息
- **文件名**: {filename}
- **路径**: {filepath}
- **文件类型**: {file_ext or '未知'}
- **分析时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## 分析结果

### 警告
不支持的文件类型: `{file_ext}`

此脚本主要用于分析 `.core` 格式的 coredump 文件。

### 建议
请上传标准格式的 coredump 文件进行分析。

---
*此为自动生成的分析报告*
"""

    return {
        "success": True,
        "filename": filename,
        "filepath": filepath,
        "report": report,
        "analyzed_at": datetime.now().isoformat()
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"success": False, "error": "请提供文件路径"}))
        sys.exit(1)

    filepath = sys.argv[1]

    if not os.path.exists(filepath):
        print(json.dumps({"success": False, "error": f"文件不存在: {filepath}"}))
        sys.exit(1)

    result = analyze_coredump(filepath)
    print(json.dumps(result, ensure_ascii=False, indent=2))