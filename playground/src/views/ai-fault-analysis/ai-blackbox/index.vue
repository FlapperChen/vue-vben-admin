<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { VbenIcon } from '@vben-core/shadcn-ui';

import {
  Button,
  Card,
  Col,
  message,
  Row,
  Space,
  Spin,
  Tag,
  Upload,
} from 'ant-design-vue';
import { marked } from 'marked';

marked.setOptions({
  breaks: true,
  gfm: true,
});

interface UploadedFile {
  id: string;
  name: string;
  path: string;
  project: string;
  size: number;
  uploadedAt: string;
}

interface AnalysisRecord {
  analyzed_at: string;
  filename: string;
  filepath: string;
  id: string;
  report: string;
  stats?: {
    debug_count: number;
    error_count: number;
    info_count: number;
    total_lines: number;
    warning_count: number;
  };
  success: boolean;
}

// 状态
const loading = ref(false);
const analyzing = ref(false);
const uploadedFiles = ref<UploadedFile[]>([]);
const analysisRecords = ref<AnalysisRecord[]>([]);
const selectedFileId = ref<null | string>(null);
const currentReport = ref('');
const isDragging = ref(false);

// 统计数据
const stats = computed(() => {
  const today = new Date().toDateString();
  let errorCount = 0;
  let warningCount = 0;
  for (const r of analysisRecords.value) {
    errorCount += r.stats?.error_count || 0;
    warningCount += r.stats?.warning_count || 0;
  }

  return {
    totalFiles: uploadedFiles.value.length,
    successCount: analysisRecords.value.filter((r) => r.success).length,
    failCount: analysisRecords.value.filter((r) => !r.success).length,
    todayCount: analysisRecords.value.filter((r) => {
      return new Date(r.analyzed_at).toDateString() === today;
    }).length,
    totalErrors: errorCount,
    totalWarnings: warningCount,
  };
});

// 统计卡片配置
const overviewItems = computed(() => [
  {
    title: '上传文件数',
    value: stats.value.totalFiles,
    subtitle: '已上传文件',
    icon: 'mdi:file-multiple',
    gradient: 'linear-gradient(135deg, #409eff 0%, #67c23a 100%)',
    textColor: '#409eff',
  },
  {
    title: '分析成功',
    value: stats.value.successCount,
    subtitle: '成功分析',
    icon: 'mdi:check-circle',
    gradient: 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)',
    textColor: '#11998e',
  },
  {
    title: '检测错误',
    value: stats.value.totalErrors,
    subtitle: '错误总数',
    icon: 'mdi:alert-circle',
    gradient: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
    textColor: '#f5576c',
  },
  {
    title: '检测警告',
    value: stats.value.totalWarnings,
    subtitle: '警告总数',
    icon: 'mdi:alert',
    gradient: 'linear-gradient(135deg, #e6a23c 0%, #f56c6c 100%)',
    textColor: '#e6a23c',
  },
]);

// 渲染 Markdown 为 HTML
const renderedReport = computed(() => {
  if (!currentReport.value) return '';
  return marked(currentReport.value);
});

const loadData = async () => {
  loading.value = true;
  try {
    // 加载分析记录
    const recordsRes = await fetch(
      '/assets/data-display/blackbox_analysis_records.json',
    );
    const records = await recordsRes.json();
    analysisRecords.value = records;

    // 从 analysisRecords 重建 uploadedFiles
    const filesMap = new Map<string, UploadedFile>();
    for (const record of records) {
      if (!filesMap.has(record.filename)) {
        filesMap.set(record.filename, {
          id: record.filename,
          name: record.filename,
          path: record.filepath,
          project: extractProjectFromPath(record.filepath),
          uploadedAt: record.analyzed_at,
          size: 0,
        });
      }
    }
    uploadedFiles.value = [...filesMap.values()];
  } catch {
    console.warn('无法加载数据');
  } finally {
    loading.value = false;
  }
};

// 从路径提取项目名
const extractProjectFromPath = (path: string): string => {
  const parts = path.split('/');
  return parts.length > 1 ? parts[parts.length - 2] : 'unknown';
};

// 保存分析记录
const saveRecords = async () => {
  try {
    const response = await fetch(
      '/assets/data-display/blackbox_analysis_records.json',
      {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(analysisRecords.value),
      },
    );
    if (!response.ok) {
      throw new Error('保存失败');
    }
  } catch {
    message.error('保存记录失败');
  }
};

// 文件上传
const handleUpload = async (file: File) => {
  try {
    const response = await fetch('/api/upload/blackbox', {
      method: 'POST',
      body: file,
    });

    if (response.ok) {
      const result = await response.json();
      const uploadedFile: UploadedFile = {
        id: result.filename,
        name: result.filename,
        path: result.path,
        project: extractProjectFromPath(result.path),
        uploadedAt: new Date().toISOString(),
        size: file.size,
      };
      uploadedFiles.value.push(uploadedFile);
      message.success(`文件 ${file.name} 上传成功`);
    } else {
      // 模拟上传成功（开发环境）
      const filename = file.name.replaceAll(/[^a-zA-Z0-9.-]/g, '_');
      const uploadedFile: UploadedFile = {
        id: filename,
        name: filename,
        path: `/assets/data-display/blackbox/${filename}`,
        project: 'demo-project',
        uploadedAt: new Date().toISOString(),
        size: file.size,
      };
      uploadedFiles.value.push(uploadedFile);
      message.warning(`文件 ${file.name} 上传成功（模拟模式）`);
    }
  } catch {
    // 模拟上传成功
    const filename = file.name.replaceAll(/[^a-zA-Z0-9.-]/g, '_');
    const uploadedFile: UploadedFile = {
      id: filename,
      name: filename,
      path: `/assets/data-display/blackbox/${filename}`,
      project: 'demo-project',
      uploadedAt: new Date().toISOString(),
      size: file.size,
    };
    uploadedFiles.value.push(uploadedFile);
    message.warning(`文件 ${file.name} 上传成功（模拟模式）`);
  }

  return false;
};

// 分析选中的文件
const analyzeSelected = async () => {
  if (!selectedFileId.value) {
    message.warning('请先选择要分析的文件');
    return;
  }

  const file = uploadedFiles.value.find((f) => f.id === selectedFileId.value);
  if (!file) {
    message.error('文件不存在');
    return;
  }

  analyzing.value = true;

  try {
    // 调用 API 分析
    const response = await fetch('/api/analyze/blackbox', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        filepath: file.path,
        filename: file.name,
      }),
    });

    if (response.ok) {
      const result = await response.json();
      handleAnalysisResult(file, result);
    } else {
      // 模拟分析结果
      const mockResult = generateMockReport(file.name, file.path);
      handleAnalysisResult(file, mockResult);
    }
  } catch {
    // 模拟分析结果
    const mockResult = generateMockReport(file.name, file.path);
    handleAnalysisResult(file, mockResult);
  } finally {
    analyzing.value = false;
  }
};

// 处理分析结果
const handleAnalysisResult = (file: UploadedFile, result: any) => {
  const record: AnalysisRecord = {
    id: `record_${Date.now()}`,
    filename: file.name,
    filepath: file.path,
    success: result.success,
    report: result.report || result.error || '分析失败',
    stats: result.stats,
    analyzed_at: new Date().toISOString(),
  };

  analysisRecords.value.unshift(record);
  currentReport.value = record.report;

  saveRecords();
  message.success('分析完成');
};

// 生成模拟报告
const generateMockReport = (filename: string, filepath: string) => {
  const now = new Date().toISOString();
  return {
    success: true,
    filename,
    filepath,
    stats: {
      total_lines: 290,
      error_count: 15,
      warning_count: 42,
      info_count: 180,
      debug_count: 53,
    },
    report: `# 黑盒日志分析报告

## 文件信息
- **文件名**: ${filename}
- **路径**: ${filepath}
- **文件大小**: 128 KB
- **分析时间**: ${now}

## 统计分析

### 日志级别分布
| 级别 | 数量 | 占比 |
|------|------|------|
| ERROR | 15 | 5.2% |
| WARN | 42 | 14.5% |
| INFO | 180 | 62.1% |
| DEBUG | 53 | 18.2% |

### 错误类型统计
| 错误类型 | 出现次数 | 影响范围 |
|----------|----------|----------|
| ConnectionTimeout | 8 | 高 |
| DatabaseError | 5 | 中 |
| AuthenticationFailed | 3 | 高 |
| ResourceNotFound | 12 | 低 |

## 问题分析

### 严重问题 (高优先级)
1. **数据库连接超时**
   - 影响范围: 多个业务模块
   - 可能原因: 数据库负载过高或网络问题
   - 建议: 检查数据库连接池配置

2. **认证失败频发**
   - 影响范围: 用户登录模块
   - 可能原因: Token 过期策略
   - 建议: 检查认证服务可用性

### 中等问题 (中优先级)
1. **资源未找到错误**
   - 影响范围: API 请求
   - 可能原因: 客户端请求了不存在的资源

## 建议措施

### 短期
1. 监控数据库连接池状态
2. 检查外部认证服务可用性
3. 优化慢查询

### 长期
1. 建立日志聚合和分析平台
2. 实现实时告警机制

---
*此为模拟分析报告，仅供参考*`,
  };
};

// 删除文件
const removeFile = (id: string) => {
  uploadedFiles.value = uploadedFiles.value.filter((f) => f.id !== id);
  if (selectedFileId.value === id) {
    selectedFileId.value = null;
  }
};

// 选择文件查看报告
const viewReport = (record: AnalysisRecord) => {
  currentReport.value = record.report;
  selectedFileId.value = record.filename;
};

// 拖拽相关
const onDragEnter = () => {
  isDragging.value = true;
};

const onDragLeave = () => {
  isDragging.value = false;
};

const onDrop = (e: DragEvent) => {
  isDragging.value = false;
  const files = e.dataTransfer?.files;
  if (files && files.length > 0) {
    handleUpload(files[0]);
  }
};

onMounted(() => {
  loadData();
});
</script>

<template>
  <Page
    description="上传并分析黑盒日志文件，发现错误模式和潜在问题"
    title="AI 黑盒日志分析"
  >
    <Spin :spinning="loading" tip="加载数据中...">
      <!-- 统计卡片 -->
      <Row :gutter="[16, 16]" class="mb-5">
        <Col :span="6" v-for="item in overviewItems" :key="item.title">
          <Card hoverable class="stat-card">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-gray-500 text-sm font-medium">
                  {{ item.title }}
                </div>
                <div
                  class="text-3xl font-extrabold tracking-tight"
                  :style="{ color: item.textColor }"
                >
                  {{ item.value }}
                </div>
                <div class="text-gray-400 text-xs mt-1">
                  {{ item.subtitle }}
                </div>
              </div>
              <div
                class="w-14 h-14 rounded-2xl flex items-center justify-center"
                :style="{ background: item.gradient }"
              >
                <VbenIcon :icon="item.icon" class="text-2xl text-white" />
              </div>
            </div>
          </Card>
        </Col>
      </Row>

      <!-- 上传和文件列表 -->
      <Row :gutter="[16, 16]" class="mb-4">
        <!-- 上传区 -->
        <Col :span="8">
          <Card title="上传日志文件">
            <Upload.Dragger
              :before-upload="handleUpload"
              :show-upload-list="false"
              accept=".log,.txt,.json"
              multiple
            >
              <div
                class="p-8 border-2 border-dashed rounded-lg transition-colors"
                :class="
                  isDragging ? 'border-blue-500 bg-blue-50' : 'border-gray-300'
                "
                @dragenter="onDragEnter"
                @dragleave="onDragLeave"
                @drop.prevent="onDrop"
              >
                <div class="text-center">
                  <VbenIcon
                    icon="mdi:cloud-upload"
                    class="text-4xl text-gray-400 mb-3"
                  />
                  <p class="text-gray-600 mb-2">拖拽日志文件到此处</p>
                  <p class="text-gray-400 text-sm">
                    或点击选择文件（支持 .log, .txt, .json）
                  </p>
                </div>
              </div>
            </Upload.Dragger>
          </Card>
        </Col>

        <!-- 文件列表 -->
        <Col :span="16">
          <Card title="已上传文件">
            <Space direction="vertical" style="width: 100%">
              <div
                v-if="uploadedFiles.length === 0"
                class="text-center text-gray-400 py-8"
              >
                暂无上传文件
              </div>
              <div
                v-for="file in uploadedFiles"
                :key="file.id"
                class="flex items-center justify-between p-3 rounded-lg hover:bg-gray-50 transition-colors"
                :class="
                  selectedFileId === file.id
                    ? 'bg-blue-50 border border-blue-200'
                    : 'border border-transparent'
                "
              >
                <div class="flex items-center gap-3">
                  <input
                    :id="file.id"
                    v-model="selectedFileId"
                    type="radio"
                    :value="file.id"
                  />
                  <label
                    :for="file.id"
                    class="cursor-pointer flex items-center gap-2"
                  >
                    <VbenIcon icon="mdi:file-document" class="text-gray-400" />
                    <div>
                      <div class="font-medium">{{ file.name }}</div>
                      <div class="text-xs text-gray-400">
                        {{ file.project }} ·
                        {{ new Date(file.uploadedAt).toLocaleString() }}
                      </div>
                    </div>
                  </label>
                </div>
                <Space>
                  <Button size="small" type="link" @click="removeFile(file.id)">
                    删除
                  </Button>
                </Space>
              </div>
            </Space>
            <div class="mt-4">
              <Button
                :loading="analyzing"
                :disabled="!selectedFileId"
                type="primary"
                @click="analyzeSelected"
              >
                {{ analyzing ? '分析中...' : '分析选中的文件' }}
              </Button>
            </div>
          </Card>
        </Col>
      </Row>

      <!-- 分析报告 -->
      <Row :gutter="[16, 16]">
        <!-- 报告内容 -->
        <Col :span="16">
          <Card title="分析报告">
            <div
              v-if="currentReport"
              class="prose max-w-none p-4 bg-gray-50 rounded-lg overflow-auto max-h-[600px]"
              v-html="renderedReport"
            ></div>
            <div v-else class="text-center text-gray-400 py-12">
              <VbenIcon
                icon="mdi:file-document-outline"
                class="text-4xl mb-3"
              />
              <p>请选择文件并点击分析按钮生成报告</p>
            </div>
          </Card>
        </Col>

        <!-- 历史记录 -->
        <Col :span="8">
          <Card title="历史记录">
            <div
              v-if="analysisRecords.length === 0"
              class="text-center text-gray-400 py-8"
            >
              暂无分析记录
            </div>
            <div v-else class="space-y-2 max-h-[500px] overflow-auto">
              <div
                v-for="record in analysisRecords.slice(0, 20)"
                :key="record.id"
                class="p-3 rounded-lg hover:bg-gray-50 cursor-pointer transition-colors"
                @click="viewReport(record)"
              >
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <VbenIcon
                      :icon="
                        record.success ? 'mdi:check-circle' : 'mdi:close-circle'
                      "
                      :class="
                        record.success ? 'text-green-500' : 'text-red-500'
                      "
                    />
                    <span class="text-sm font-medium truncate max-w-[150px]">
                      {{ record.filename }}
                    </span>
                  </div>
                  <Tag :color="record.success ? 'success' : 'error'">
                    {{ record.success ? '成功' : '失败' }}
                  </Tag>
                </div>
                <div v-if="record.stats" class="text-xs text-gray-400 mt-1">
                  错误: {{ record.stats.error_count }} | 警告:
                  {{ record.stats.warning_count }}
                </div>
              </div>
            </div>
          </Card>
        </Col>
      </Row>
    </Spin>
  </Page>
</template>

<style scoped>
.mb-4 {
  margin-bottom: 16px;
}

.mb-5 {
  margin-bottom: 20px;
}

.stat-card {
  overflow: hidden;
  border-radius: 12px;
}

.text-3xl {
  font-size: 1.875rem;
  line-height: 2.25rem;
}

.font-extrabold {
  font-weight: 800;
}

.tracking-tight {
  letter-spacing: -0.025em;
}

/* Markdown 样式 */
:deep(.prose) {
  font-size: 14px;
  line-height: 1.6;
}

:deep(.prose h1) {
  padding-bottom: 0.5rem;
  margin-bottom: 1rem;
  font-size: 1.5rem;
  font-weight: 700;
  border-bottom: 1px solid #e5e7eb;
}

:deep(.prose h2) {
  margin-top: 1.5rem;
  margin-bottom: 0.75rem;
  font-size: 1.25rem;
  font-weight: 600;
}

:deep(.prose h3) {
  margin-top: 1rem;
  margin-bottom: 0.5rem;
  font-size: 1.1rem;
  font-weight: 600;
}

:deep(.prose table) {
  width: 100%;
  margin: 1rem 0;
  border-collapse: collapse;
}

:deep(.prose th),
:deep(.prose td) {
  padding: 0.5rem 0.75rem;
  text-align: left;
  border: 1px solid #e5e7eb;
}

:deep(.prose th) {
  font-weight: 600;
  background-color: #f9fafb;
}

:deep(.prose code) {
  padding: 0.125rem 0.375rem;
  font-size: 0.875em;
  background-color: #f1f5f9;
  border-radius: 0.25rem;
}

:deep(.prose pre) {
  padding: 1rem;
  overflow-x: auto;
  color: #f9fafb;
  background-color: #1f2937;
  border-radius: 0.5rem;
}

:deep(.prose pre code) {
  padding: 0;
  background-color: transparent;
}

:deep(.prose ul),
:deep(.prose ol) {
  padding-left: 1.5rem;
  margin: 0.75rem 0;
}

:deep(.prose li) {
  margin: 0.25rem 0;
}
</style>
