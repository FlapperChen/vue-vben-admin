<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { VbenIcon } from '@vben-core/shadcn-ui';

import {
  Button,
  Card,
  Col,
  Input,
  InputSearch,
  message,
  Progress,
  Row,
  Select,
  Space,
  Spin,
  Tag,
  Upload,
} from 'ant-design-vue';
import DOMPurify from 'dompurify';
import { marked } from 'marked';

// 配置 marked
marked.setOptions({
  breaks: true,
  gfm: true,
});

interface UploadedFile {
  branch: string;
  gerritId: string;
  id: string;
  name: string;
  path: string;
  project: string;
  size: number;
  uploadedAt: string;
}

interface AnalysisRecord {
  analyzed_at: string;
  branch: string;
  filename: string;
  filepath: string;
  gerritId: string;
  id: string;
  project: string;
  report: string;
  success: boolean;
  summary: string;
}

// localStorage 持久化
const STORAGE_KEY = 'coredump_analysis_data';

const saveToStorage = () => {
  const data = {
    files: uploadedFiles.value,
    records: analysisRecords.value,
    currentReport: currentReport.value,
    selectedFileId: selectedFileId.value,
    analysisForm: analysisForm.value,
  };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
};

const loadFromStorage = () => {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      const data = JSON.parse(saved);
      uploadedFiles.value = data.files || [];
      analysisRecords.value = data.records || [];
      currentReport.value = data.currentReport || '';
      selectedFileId.value = data.selectedFileId || null;
      analysisForm.value = data.analysisForm || {
        project: '',
        branch: '',
        gerritId: '',
      };
    }
  } catch {
    console.warn('加载本地存储失败');
  }
};

// 状态
const loading = ref(false);
const analyzing = ref(false);
const uploading = ref(false);
const uploadFileList = ref<
  Array<{ id: string; name: string; progress: number }>
>([]);
const uploadedFiles = ref<UploadedFile[]>([]);
const analysisRecords = ref<AnalysisRecord[]>([]);
const selectedFileId = ref<null | string>(null);
const currentReport = ref('');
const isDragging = ref(false);

// 计算总进度
const totalProgress = computed(() => {
  if (uploadFileList.value.length === 0) return 0;
  const total = uploadFileList.value.reduce((sum, f) => sum + f.progress, 0);
  return Math.round(total / uploadFileList.value.length);
});

// 计算已完成数量
const completedCount = computed(() => {
  return uploadFileList.value.filter((f) => f.progress >= 100).length;
});

// 统计数据
const stats = computed(() => {
  const today = new Date().toDateString();
  return {
    totalFiles: uploadedFiles.value.length,
    successCount: analysisRecords.value.filter((r) => r.success).length,
    failCount: analysisRecords.value.filter((r) => !r.success).length,
    todayCount: analysisRecords.value.filter((r) => {
      return new Date(r.analyzed_at).toDateString() === today;
    }).length,
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
    title: '分析失败',
    value: stats.value.failCount,
    subtitle: '失败分析',
    icon: 'mdi:close-circle',
    gradient: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
    textColor: '#f5576c',
  },
  {
    title: '今日分析',
    value: stats.value.todayCount,
    subtitle: '今日统计',
    icon: 'mdi:calendar-today',
    gradient: 'linear-gradient(135deg, #e6a23c 0%, #f56c6c 100%)',
    textColor: '#e6a23c',
  },
]);

// 搜索和筛选状态
const fileSearchQuery = ref('');
const recordSearchQuery = ref('');
const fileProjectFilter = ref<string | undefined>(undefined);
const recordProjectFilter = ref<string | undefined>(undefined);
const recordBranchFilter = ref<string | undefined>(undefined);

// 分析表单
const analysisForm = ref({
  project: '',
  branch: '',
  gerritId: '',
});

// 筛选后的文件列表
const filteredFiles = computed(() => {
  return uploadedFiles.value.filter((f) => {
    const matchSearch =
      !fileSearchQuery.value ||
      f.name.toLowerCase().includes(fileSearchQuery.value.toLowerCase()) ||
      f.project.toLowerCase().includes(fileSearchQuery.value.toLowerCase());
    const matchProject =
      !fileProjectFilter.value || f.project === fileProjectFilter.value;
    return matchSearch && matchProject;
  });
});

// 筛选后的历史记录
const filteredRecords = computed(() => {
  return analysisRecords.value.filter((r) => {
    const matchSearch =
      !recordSearchQuery.value ||
      r.filename
        .toLowerCase()
        .includes(recordSearchQuery.value.toLowerCase()) ||
      r.project.toLowerCase().includes(recordSearchQuery.value.toLowerCase()) ||
      r.branch.toLowerCase().includes(recordSearchQuery.value.toLowerCase()) ||
      r.gerritId.toLowerCase().includes(recordSearchQuery.value.toLowerCase());
    const matchProject =
      !recordProjectFilter.value || r.project === recordProjectFilter.value;
    const matchBranch =
      !recordBranchFilter.value || r.branch === recordBranchFilter.value;
    return matchSearch && matchProject && matchBranch;
  });
});

// 获取所有项目列表（用于下拉筛选）
const allProjects = computed(() => {
  const projects = new Set<string>();
  analysisRecords.value.forEach((r) => {
    if (r.project) projects.add(r.project);
  });
  return [...projects].toSorted();
});

// 获取所有分支列表（用于下拉筛选）
const allBranches = computed(() => {
  const branches = new Set<string>();
  analysisRecords.value.forEach((r) => {
    if (r.branch) branches.add(r.branch);
  });
  return [...branches].toSorted();
});

// 渲染 Markdown 为 HTML（使用 DOMPurify 防止 XSS）
const renderedReport = computed(() => {
  if (!currentReport.value) return '';
  return DOMPurify.sanitize(marked(currentReport.value));
});

// 从路径提取项目名
const extractProjectFromPath = (path: string): string => {
  const parts = path.split('/');
  return parts.length > 1 ? parts[parts.length - 2] || 'unknown' : 'unknown';
};

// 从报告提取摘要（第一条根因）
const extractSummary = (report: string): string => {
  // 匹配 "1. **xxx**" 格式的根因
  const rootCauseMatch = report.match(/\d+\.\s+\*\*(.+?)\*\*/);
  if (rootCauseMatch) {
    return rootCauseMatch[1] || '点击查看详情';
  }
  // 如果没有根因，返回信号信息
  const signalMatch = report.match(/信号\s+\|\s+(\S+)/);
  if (signalMatch) {
    return `信号: ${signalMatch[1] || '未知'}`;
  }
  // 默认返回"查看详情"
  return '点击查看详情';
};

// 文件上传
const handleUpload = async (file: File) => {
  const fileId = `${file.name}_${Date.now()}`;
  const fileInfo = { name: file.name, progress: 0, id: fileId };

  uploading.value = true;
  uploadFileList.value.push(fileInfo);

  // 模拟上传进度
  const progressInterval = setInterval(() => {
    const idx = uploadFileList.value.findIndex((f) => f.id === fileId);
    if (idx === -1) {
      clearInterval(progressInterval);
    } else {
      const currentFile = uploadFileList.value[idx];
      if (currentFile) {
        currentFile.progress += Math.random() * 20;
        if (currentFile.progress >= 90) {
          currentFile.progress = 90;
          clearInterval(progressInterval);
        }
      }
    }
  }, 200);

  const formData = new FormData();
  formData.append('file', file);

  try {
    const response = await fetch('/api/upload/coredump', {
      method: 'POST',
      body: formData,
    });

    clearInterval(progressInterval);
    const idx = uploadFileList.value.findIndex((f) => f.id === fileId);
    if (idx !== -1) {
      const currentFile = uploadFileList.value[idx];
      if (currentFile) currentFile.progress = 100;
    }

    if (response.ok) {
      const result = await response.json();
      const uploadedFile: UploadedFile = {
        id: result.filename,
        name: result.filename,
        path: result.path,
        project: extractProjectFromPath(result.path),
        branch: '',
        gerritId: '',
        uploadedAt: new Date().toISOString(),
        size: file.size,
      };
      uploadedFiles.value.push(uploadedFile);
      saveToStorage();
      message.success(`文件 ${file.name} 上传成功`);
    } else {
      // 模拟上传成功（开发环境）
      await new Promise((resolve) => setTimeout(resolve, 500));
      const filename = file.name.replaceAll(/[^a-zA-Z0-9.-]/g, '_');
      const uploadedFile: UploadedFile = {
        id: filename,
        name: filename,
        path: `/assets/data-display/coredump/${filename}`,
        project: 'demo-project',
        branch: '',
        gerritId: '',
        uploadedAt: new Date().toISOString(),
        size: file.size,
      };
      uploadedFiles.value.push(uploadedFile);
      saveToStorage();
      message.success(`文件 ${file.name} 上传成功（模拟）`);
    }
  } catch {
    clearInterval(progressInterval);
    const idx = uploadFileList.value.findIndex((f) => f.id === fileId);
    if (idx !== -1) {
      const currentFile = uploadFileList.value[idx];
      if (currentFile) currentFile.progress = 100;
    }
    // 模拟上传成功（开发环境）
    await new Promise((resolve) => setTimeout(resolve, 500));
    const filename = file.name.replaceAll(/[^a-zA-Z0-9.-]/g, '_');
    const uploadedFile: UploadedFile = {
      id: filename,
      name: filename,
      path: `/assets/data-display/coredump/${filename}`,
      project: 'demo-project',
      branch: '',
      gerritId: '',
      uploadedAt: new Date().toISOString(),
      size: file.size,
    };
    uploadedFiles.value.push(uploadedFile);
    saveToStorage();
    message.warning(`文件 ${file.name} 上传成功（模拟模式）`);
  } finally {
    // 延迟移除已完成文件，保持进度显示
    setTimeout(() => {
      uploadFileList.value = uploadFileList.value.filter(
        (f) => f.id !== fileId,
      );
      if (uploadFileList.value.length === 0) {
        uploading.value = false;
      }
    }, 500);
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
    const response = await fetch('/api/analyze/coredump', {
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
      const mockResult = generateMockReport(file.name, file.path);
      handleAnalysisResult(file, mockResult);
    }
  } catch {
    const mockResult = generateMockReport(file.name, file.path);
    handleAnalysisResult(file, mockResult);
  } finally {
    analyzing.value = false;
  }
};

// 处理分析结果
const handleAnalysisResult = (file: UploadedFile, result: any) => {
  const report = result.report || result.error || '分析失败';
  const record: AnalysisRecord = {
    id: `record_${Date.now()}`,
    filename: file.name,
    filepath: file.path,
    project: analysisForm.value.project,
    branch: analysisForm.value.branch,
    gerritId: analysisForm.value.gerritId,
    success: result.success,
    report,
    summary: extractSummary(report),
    analyzed_at: new Date().toISOString(),
  };

  // 更新文件的元数据
  file.project = analysisForm.value.project;
  file.branch = analysisForm.value.branch;
  file.gerritId = analysisForm.value.gerritId;

  analysisRecords.value.unshift(record);
  currentReport.value = record.report;

  saveToStorage();
  message.success('分析完成');
};

// 生成模拟报告
const generateMockReport = (filename: string, filepath: string) => {
  const now = new Date().toISOString();
  return {
    success: true,
    filename,
    filepath,
    report: `# Coredump 分析报告

## 文件信息
- **文件名**: ${filename}
- **路径**: ${filepath}
- **分析时间**: ${now}
- **项目**: ${analysisForm.value.project || '未知'}
- **分支**: ${analysisForm.value.branch || '未知'}
- **Gerrit/Commit ID**: ${analysisForm.value.gerritId || '未知'}

## 分析结果

### 基本信息
| 项目 | 值 |
|------|-----|
| 进程名称 | example_process |
| 崩溃时间 | ${now} |
| 信号 | SIGSEGV (11) |
| 崩溃地址 | 0x0000000000000000 |

### 堆栈信息
\`\`\`
#0  0x00007f8a3c4d5a37 in __GI_raise (sig=signo=11)
#1  0x00007f8a3c4d7028 in __GI_abort ()
#2  0x0000562e5a4c8f3a in process_request (conn=0x7fff12345678)
#3  0x0000562e5a4c9a1b in main (argc=1, argv=0x7fff12345690)
\`\`\`

### 可能的根因
1. **空指针解引用** - 堆栈显示在 process_request 中发生崩溃
2. **内存越界访问** - conn 指针可能已释放或未初始化
3. **线程安全问题** - 多线程环境下的竞态条件

### 建议
- 检查相关代码的指针使用
- 增加边界检查和空指针验证
- 考虑使用 AddressSanitizer 进行调试

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
  saveToStorage();
};

// 删除历史记录
const removeRecord = (id: string) => {
  analysisRecords.value = analysisRecords.value.filter((r) => r.id !== id);
  saveToStorage();
};

// 选择文件查看报告
const viewReport = (record: AnalysisRecord) => {
  currentReport.value = record.report;
  selectedFileId.value = record.filename;
  // 填充表单
  analysisForm.value.project = record.project;
  analysisForm.value.branch = record.branch;
  analysisForm.value.gerritId = record.gerritId;
  saveToStorage();
};

// 重置表单
const resetForm = () => {
  analysisForm.value = {
    project: '',
    branch: '',
    gerritId: '',
  };
  selectedFileId.value = null;
  saveToStorage();
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
    // 支持多文件上传
    for (const file of files) {
      if (file) handleUpload(file);
    }
  }
};

// 获取选中文件的显示信息
const selectedFileInfo = computed(() => {
  if (!selectedFileId.value) return null;
  return uploadedFiles.value.find((f) => f.id === selectedFileId.value);
});

onMounted(() => {
  loadFromStorage();
});
</script>

<template>
  <Page
    description="上传并分析 coredump 文件，生成 AI 分析报告"
    title="AI Coredump 分析"
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

      <!-- 上传区 -->
      <Card class="mb-4">
        <Upload
          :before-upload="handleUpload"
          :show-upload-list="false"
          multiple
          drag
        >
          <div
            class="upload-area"
            :class="{ 'upload-area-active': isDragging }"
            @dragenter="onDragEnter"
            @dragleave="onDragLeave"
            @drop.prevent="onDrop"
          >
            <!-- 上传中状态 -->
            <template v-if="uploading">
              <div class="upload-progress-wrapper">
                <div class="upload-progress-header">
                  <VbenIcon
                    icon="mdi:cloud-upload"
                    class="upload-icon uploading-icon"
                  />
                  <span class="upload-progress-title">
                    正在上传 {{ completedCount }}/{{ uploadFileList.length }}
                    个文件
                  </span>
                </div>
                <div class="upload-progress-list">
                  <div
                    v-for="file in uploadFileList"
                    :key="file.id"
                    class="upload-progress-item"
                  >
                    <span class="upload-progress-filename">{{
                      file.name
                    }}</span>
                    <Progress
                      :percent="Math.round(file.progress)"
                      size="small"
                      :status="file.progress >= 100 ? 'success' : 'active'"
                    />
                  </div>
                </div>
                <Progress
                  :percent="totalProgress"
                  :status="totalProgress >= 100 ? 'success' : 'active'"
                  class="upload-progress-total"
                />
              </div>
            </template>
            <!-- 默认状态 -->
            <template v-else>
              <div class="upload-content">
                <VbenIcon
                  icon="mdi:cloud-upload"
                  class="upload-icon upload-icon-large"
                />
                <p class="upload-text-primary mb-1">
                  拖拽文件到此处，或<span class="upload-text-link">点击选择</span>
                </p>
                <p class="upload-text-secondary">支持任意文件类型</p>
              </div>
            </template>
          </div>
        </Upload>
      </Card>

      <!-- 文件和历史记录区域 -->
      <Row :gutter="16" class="mb-4">
        <!-- 左侧: 已上传文件 -->
        <Col :span="12">
          <Card>
            <template #title>
              <div class="flex items-center gap-2">
                <VbenIcon icon="mdi:file-multiple" class="text-lg" />
                <span>已上传文件</span>
                <Tag color="blue">{{ filteredFiles.length }}</Tag>
              </div>
            </template>
            <template #extra>
              <Space>
                <InputSearch
                  v-model:value="fileSearchQuery"
                  class="search-input"
                  placeholder="搜索文件名..."
                />
                <Select
                  v-model:value="fileProjectFilter"
                  :options="allProjects.map((p) => ({ label: p, value: p }))"
                  allow-clear
                  class="filter-select"
                  placeholder="按项目筛选"
                />
              </Space>
            </template>
            <div class="file-list">
              <div
                v-if="filteredFiles.length === 0"
                class="text-center text-gray-400 py-8"
              >
                暂无上传文件
              </div>
              <div
                v-for="file in filteredFiles"
                :key="file.id"
                class="file-item"
                :class="{
                  'file-item-selected': selectedFileId === file.id,
                }"
              >
                <input
                  :id="file.id"
                  v-model="selectedFileId"
                  type="radio"
                  :value="file.id"
                />
                <label :for="file.id" class="file-label">
                  <div class="flex items-center gap-2">
                    <VbenIcon icon="mdi:file" class="text-gray-400" />
                    <div>
                      <div class="font-medium text-sm">{{ file.name }}</div>
                      <div class="text-xs text-gray-400">
                        <span v-if="file.project">{{ file.project }}</span>
                        <span v-if="file.branch"> / {{ file.branch }}</span>
                        <span v-if="file.gerritId"> / {{ file.gerritId }}</span>
                        <span v-if="!file.project && !file.branch">
                          {{ new Date(file.uploadedAt).toLocaleString() }}
                        </span>
                      </div>
                    </div>
                  </div>
                </label>
                <Button
                  class="delete-btn"
                  size="small"
                  type="text"
                  @click.stop="removeFile(file.id)"
                >
                  <VbenIcon icon="mdi:delete" class="delete-icon" />
                </Button>
              </div>
            </div>
          </Card>
        </Col>

        <!-- 右侧: 历史记录 -->
        <Col :span="12">
          <Card>
            <template #title>
              <div class="flex items-center gap-2">
                <VbenIcon icon="mdi:history" class="text-lg" />
                <span>历史记录</span>
                <Tag color="green">{{ filteredRecords.length }}</Tag>
              </div>
            </template>
            <template #extra>
              <Space wrap>
                <InputSearch
                  v-model:value="recordSearchQuery"
                  class="search-input"
                  placeholder="搜索..."
                />
                <Select
                  v-model:value="recordProjectFilter"
                  :options="allProjects.map((p) => ({ label: p, value: p }))"
                  allow-clear
                  class="filter-select"
                  placeholder="按项目"
                />
                <Select
                  v-model:value="recordBranchFilter"
                  :options="allBranches.map((b) => ({ label: b, value: b }))"
                  allow-clear
                  class="filter-select"
                  placeholder="按分支"
                />
              </Space>
            </template>
            <div class="record-list">
              <div
                v-if="filteredRecords.length === 0"
                class="text-center text-gray-400 py-8"
              >
                暂无分析记录
              </div>
              <div
                v-for="record in filteredRecords"
                :key="record.id"
                class="record-item"
                :class="{
                  'record-item-selected': selectedFileId === record.filename,
                }"
              >
                <div class="record-item-content" @click="viewReport(record)">
                  <div class="flex items-center gap-3">
                    <span class="text-sm font-medium record-filename">
                      {{ record.filename }}
                    </span>
                    <div class="record-item-right">
                      <Tag color="warning" class="record-summary-tag">
                        {{ record.summary || '分析完成' }}
                      </Tag>
                    </div>
                  </div>
                  <div class="text-xs text-gray-500 mt-1">
                    <span v-if="record.project">{{ record.project }}</span>
                    <span v-if="record.branch"> / {{ record.branch }}</span>
                    <span v-if="record.gerritId"> / {{ record.gerritId }}</span>
                  </div>
                  <div class="text-xs text-gray-400">
                    {{ new Date(record.analyzed_at).toLocaleString() }}
                  </div>
                </div>
                <div class="record-item-actions">
                  <div class="record-status-icon">
                    <VbenIcon
                      :icon="
                        record.success ? 'mdi:check-circle' : 'mdi:close-circle'
                      "
                      :class="
                        record.success ? 'text-green-500' : 'text-red-500'
                      "
                    />
                    <Tag
                      :color="record.success ? 'success' : 'error'"
                      class="ml-1"
                    >
                      {{ record.success ? '成功' : '失败' }}
                    </Tag>
                  </div>
                  <Button
                    class="delete-btn"
                    size="small"
                    type="text"
                    @click.stop="removeRecord(record.id)"
                  >
                    <VbenIcon icon="mdi:delete" class="delete-icon" />
                  </Button>
                </div>
              </div>
            </div>
          </Card>
        </Col>
      </Row>

      <!-- 分析参数表单 -->
      <Card class="mb-4">
        <div class="form-row">
          <div class="form-group">
            <label class="form-label">项目名称</label>
            <Input
              v-model:value="analysisForm.project"
              placeholder="请输入项目名称"
              class="form-input"
            />
          </div>
          <div class="form-group">
            <label class="form-label">分支名称</label>
            <Input
              v-model:value="analysisForm.branch"
              placeholder="请输入分支名称"
              class="form-input"
            />
          </div>
          <div class="form-group form-group-wide">
            <label class="form-label">Gerrit ID / Commit ID</label>
            <Input
              v-model:value="analysisForm.gerritId"
              placeholder="请输入 Gerrit ID 或 Commit ID"
              class="form-input"
            />
          </div>
          <div class="form-actions">
            <Button
              :disabled="!selectedFileId"
              :loading="analyzing"
              type="primary"
              class="analyze-btn"
              @click="analyzeSelected"
            >
              {{ analyzing ? '分析中...' : '分析文件' }}
            </Button>
            <Button class="reset-btn" @click="resetForm">重置</Button>
          </div>
        </div>
        <div v-if="selectedFileInfo" class="selected-info">
          <VbenIcon icon="mdi:file-check" class="text-blue-500" />
          <span class="ml-2">已选择: {{ selectedFileInfo.name }}</span>
        </div>
      </Card>

      <!-- 分析报告 -->
      <Card title="分析报告" class="report-card">
        <div
          v-if="currentReport"
          class="prose max-w-none p-4 bg-gray-50 rounded-lg overflow-auto"
          v-html="renderedReport"
        ></div>
        <div v-else class="text-center text-gray-400 py-12">
          <VbenIcon
            icon="mdi:file-document-outline"
            class="text-5xl mb-3 text-gray-300"
          />
          <p>请选择文件并点击分析按钮生成报告</p>
        </div>
      </Card>
    </Spin>
  </Page>
</template>

<style scoped>
.mb-4 {
  margin-bottom: 16px;
}

.mb-4 :deep(.ant-card-body) {
  padding: 0;
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

.upload-area {
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100%;
  min-height: 180px;
  padding: 48px 24px;
  text-align: center;
  background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
  border: none;
  border-radius: 12px;
  box-shadow:
    0 4px 6px -1px rgb(0 0 0 / 10%),
    0 2px 4px -2px rgb(0 0 0 / 10%);
  transition: all 0.3s ease;
}

:deep(.ant-upload-drag) {
  width: 100% !important;
  padding: 0 !important;
  background: transparent !important;
  border: none !important;
}

:deep(.ant-upload-drag-container) {
  display: block !important;
  width: 100% !important;
}

:deep(.ant-upload) {
  width: 100% !important;
}

:deep(.ant-upload-select) {
  width: 100% !important;
}

:deep(.ant-upload-drag-icon) {
  display: none !important;
}

:deep(.ant-upload-text) {
  display: none !important;
}

:deep(.ant-upload-hint) {
  display: none !important;
}

.upload-area:hover {
  background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
  box-shadow:
    0 10px 15px -3px rgb(0 0 0 / 10%),
    0 4px 6px -4px rgb(0 0 0 / 10%);
  transform: translateY(-2px);
}

.upload-area-active {
  background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
  box-shadow:
    0 15px 20px -5px rgb(59 130 246 / 30%),
    0 8px 10px -6px rgb(59 130 246 / 20%);
  transform: scale(1.02);
}

.upload-icon {
  color: #60a5fa;
  transition: transform 0.3s ease;
}

.upload-icon-large {
  margin-bottom: 12px;
  font-size: 48px;
}

.upload-text-primary {
  font-size: 16px;
  color: #4b5563;
}

.upload-text-secondary {
  font-size: 12px;
  color: #9ca3af;
}

.upload-text-link {
  color: #3b82f6;
  cursor: pointer;
}

.upload-text-link:hover {
  text-decoration: underline;
}

.upload-text-uploading {
  font-size: 16px;
  font-weight: 500;
  color: #3b82f6;
}

.upload-content {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.upload-area:hover .upload-icon {
  transform: translateY(-4px);
}

.uploading-icon {
  color: #3b82f6;
  animation: pulse 1s ease-in-out infinite;
}

@keyframes pulse {
  0%,
  100% {
    opacity: 1;
    transform: scale(1);
  }

  50% {
    opacity: 0.7;
    transform: scale(1.05);
  }
}

.upload-progress,
.upload-progress-total {
  width: 60%;
  margin: 0 auto;
}

.upload-progress :deep(.ant-progress-text),
.upload-progress-total :deep(.ant-progress-text) {
  font-weight: 500;
  color: #3b82f6;
}

.upload-progress-wrapper {
  width: 100%;
  max-width: 500px;
}

.upload-progress-header {
  display: flex;
  gap: 12px;
  align-items: center;
  justify-content: center;
  margin-bottom: 16px;
}

.upload-progress-header .upload-icon {
  margin-bottom: 0;
  font-size: 32px;
}

.upload-progress-title {
  font-size: 16px;
  font-weight: 500;
  color: #3b82f6;
}

.upload-progress-list {
  max-height: 150px;
  padding: 0 20px;
  margin-bottom: 16px;
  overflow-y: auto;
}

.upload-progress-item {
  display: flex;
  gap: 12px;
  align-items: center;
  padding: 4px 0;
}

.upload-progress-filename {
  flex: 0 0 150px;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 13px;
  color: #4b5563;
  white-space: nowrap;
}

.upload-progress-item :deep(.ant-progress) {
  flex: 1;
}

.search-input {
  width: 150px;
}

.filter-select {
  width: 120px;
}

.file-list,
.record-list {
  max-height: 220px;
  overflow-y: auto;
}

.file-list::-webkit-scrollbar,
.record-list::-webkit-scrollbar {
  width: 6px;
}

.file-list::-webkit-scrollbar-thumb,
.record-list::-webkit-scrollbar-thumb {
  background: #d1d5db;
  border-radius: 3px;
}

.file-item {
  display: flex;
  align-items: center;
  padding: 10px 12px;
  border-radius: 6px;
  transition: background-color 0.2s;
}

.file-item:hover {
  background-color: #f9fafb;
}

.file-item:hover .delete-btn {
  opacity: 1;
}

.file-item-selected {
  background-color: #eff6ff;
  border: 1px solid #3b82f6;
}

.file-label {
  flex: 1;
  margin-left: 8px;
  cursor: pointer;
}

.record-item {
  display: flex;
  align-items: flex-start;
  padding: 12px;
  margin-bottom: 4px;
  border-radius: 6px;
  transition: background-color 0.2s;
}

.record-item-content {
  flex: 1;
  min-width: 0;
  cursor: pointer;
}

.record-item-right {
  flex-shrink: 0;
}

.record-filename {
  word-break: break-all;
  white-space: normal;
}

.record-summary {
  font-weight: 500;
}

.record-summary-tag {
  font-size: 13px;
  font-weight: 500;
}

.record-item-actions {
  display: flex;
  flex-direction: column;
  gap: 4px;
  align-items: center;
  justify-content: center;
}

.record-status-icon {
  display: flex;
  align-items: center;
}

.record-item:hover {
  background-color: #f9fafb;
}

.record-item:hover .delete-btn {
  opacity: 1;
}

.record-item-selected {
  background-color: #eff6ff;
  border: 1px solid #3b82f6;
}

.delete-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  min-height: 24px;
  padding: 4px;
  opacity: 0.5;
  transition: opacity 0.2s;
}

.delete-btn:hover,
.delete-btn:focus {
  opacity: 1;
}

.delete-btn:focus-visible {
  outline: 2px solid #3b82f6;
  outline-offset: 1px;
}

.delete-icon {
  font-size: 18px;
  line-height: 1;
  color: #9ca3af;
  transition: color 0.2s;
}

.delete-btn:hover .delete-icon,
.delete-btn:focus .delete-icon {
  color: #ef4444;
}

.form-row {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  align-items: flex-end;
  padding: 12px 16px;
}

.form-group {
  flex: 1;
  min-width: 150px;
}

.form-group-wide {
  flex: 1.5;
}

.form-label {
  display: block;
  margin-bottom: 6px;
  font-size: 14px;
  font-weight: 500;
  color: #374151;
}

.form-input {
  width: 100%;
}

.form-actions {
  display: flex;
  gap: 8px;
  align-items: center;
  margin-left: auto;
}

.analyze-btn,
.reset-btn {
  min-width: 80px;
  height: 32px;
}

.selected-info {
  display: flex;
  align-items: center;
  padding: 6px 12px;
  margin: 8px 16px;
  font-size: 13px;
  color: #3b82f6;
  background-color: #eff6ff;
  border-radius: 4px;
}

.report-card {
  min-height: 400px;
}

.report-card :deep(.ant-card-body) {
  min-height: 350px;
}

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
