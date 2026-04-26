<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { Page } from '@vben/common-ui';

import { VbenIcon } from '@vben-core/shadcn-ui';

import { Card, Col, Row } from 'ant-design-vue';

const router = useRouter();

// 统计数据
const stats = ref({
  totalAnalyses: 0,
  successCount: 0,
  failCount: 0,
  todayCount: 0,
});

// 加载统计数据（从 localStorage）
const loadStats = () => {
  try {
    const STORAGE_KEY = 'coredump_analysis_data';
    const saved = localStorage.getItem(STORAGE_KEY);

    if (!saved) {
      return;
    }

    const data = JSON.parse(saved);
    // coredump 页面存储的是对象 { files, records, ... }，需要取 records 数组
    const allRecords = data.records || [];

    stats.value = {
      totalAnalyses: allRecords.length,
      successCount: allRecords.filter((r: any) => r.success).length,
      failCount: allRecords.filter((r: any) => !r.success).length,
      todayCount: allRecords.filter((r: any) => {
        const recordDate = new Date(r.analyzed_at).toDateString();
        const today = new Date().toDateString();
        return recordDate === today;
      }).length,
    };
  } catch {
    console.warn('无法加载统计数据');
  }
};

// 统计卡片数据
const overviewItems = computed(() => [
  {
    title: '总分析次数',
    value: stats.value.totalAnalyses,
    subtitle: '累计分析文件数',
    icon: 'mdi:file-chart',
    gradient: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    textColor: '#667eea',
  },
  {
    title: '成功次数',
    value: stats.value.successCount,
    subtitle: '分析成功',
    icon: 'mdi:check-circle',
    gradient: 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)',
    textColor: '#11998e',
  },
  {
    title: '失败次数',
    value: stats.value.failCount,
    subtitle: '分析失败',
    icon: 'mdi:close-circle',
    gradient: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
    textColor: '#f5576c',
  },
  {
    title: '今日分析',
    value: stats.value.todayCount,
    subtitle: '今日分析次数',
    icon: 'mdi:calendar-today',
    gradient: 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)',
    textColor: '#4facfe',
  },
]);

// 菜单项
const menuItems = [
  {
    key: 'coredump',
    title: 'AI Coredump 分析',
    desc: '上传 coredump 文件，自动分析崩溃原因并生成报告',
    icon: '💥',
    path: '/ai-fault-analysis/ai-coredump',
    color: '#f56c6c',
    bgGradient: 'linear-gradient(135deg, #f56c6c 0%, #e6a23c 100%)',
  },
  {
    key: 'blackbox',
    title: 'AI 黑盒日志分析',
    desc: '上传系统日志，自动分析错误模式和潜在问题',
    icon: '📋',
    path: '/ai-fault-analysis/ai-blackbox',
    color: '#409eff',
    bgGradient: 'linear-gradient(135deg, #409eff 0%, #67c23a 100%)',
  },
];

const navigateTo = (path: string) => {
  router.push(path);
};

onMounted(() => {
  loadStats();
});
</script>

<template>
  <Page
    description="AI 驱动的故障分析工具，自动分析 coredump 和日志文件"
    title="AI 故障分析"
  >
    <!-- 统计卡片 -->
    <Row :gutter="[16, 16]" class="mb-5">
      <Col :span="6" v-for="item in overviewItems" :key="item.title">
        <Card
          hoverable
          class="stat-card hover:shadow-xl transition-all duration-300"
        >
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
              <div class="text-gray-400 text-xs mt-1">{{ item.subtitle }}</div>
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

    <!-- 功能入口 -->
    <Row :gutter="[16, 16]">
      <Col v-for="item in menuItems" :key="item.key" :span="12">
        <Card
          hoverable
          class="menu-card cursor-pointer hover:shadow-xl transition-all duration-300"
          @click="navigateTo(item.path)"
        >
          <div class="flex items-center gap-4">
            <div
              class="menu-icon w-16 h-16 rounded-xl flex items-center justify-center text-3xl"
              :style="{ background: item.bgGradient }"
            >
              {{ item.icon }}
            </div>
            <div class="menu-info flex-1">
              <div class="menu-title text-xl font-semibold">
                {{ item.title }}
              </div>
              <div class="menu-desc text-sm text-gray-500 mt-2">
                {{ item.desc }}
              </div>
            </div>
            <div class="arrow text-gray-300 text-2xl">→</div>
          </div>
        </Card>
      </Col>
    </Row>

    <!-- 使用说明 -->
    <Card title="使用说明" class="mt-5">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="p-4 bg-red-50 rounded-lg border border-red-200">
          <div
            class="text-sm text-red-800 font-semibold mb-2 flex items-center gap-2"
          >
            <span>💥</span> Coredump 分析
          </div>
          <ol class="text-sm text-red-700 space-y-1 list-decimal list-inside">
            <li>上传 coredump 文件（.core 格式）</li>
            <li>选择要分析的文件</li>
            <li>点击分析按钮</li>
            <li>查看 Markdown 格式的分析报告</li>
          </ol>
        </div>
        <div class="p-4 bg-blue-50 rounded-lg border border-blue-200">
          <div
            class="text-sm text-blue-800 font-semibold mb-2 flex items-center gap-2"
          >
            <span>📋</span> 黑盒日志分析
          </div>
          <ol class="text-sm text-blue-700 space-y-1 list-decimal list-inside">
            <li>上传系统日志文件</li>
            <li>选择要分析的文件</li>
            <li>点击分析按钮</li>
            <li>查看错误模式和潜在问题报告</li>
          </ol>
        </div>
      </div>
    </Card>
  </Page>
</template>

<style scoped>
.mb-5 {
  margin-bottom: 20px;
}

.mt-5 {
  margin-top: 20px;
}

.stat-card {
  overflow: hidden;
  border-radius: 12px;
}

.stat-card:hover {
  transform: translateY(-4px);
}

.menu-card {
  min-height: 120px;
}

.menu-card:hover .arrow {
  color: #409eff;
  transform: translateX(5px);
}

.arrow {
  transition: all 0.3s;
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
</style>
