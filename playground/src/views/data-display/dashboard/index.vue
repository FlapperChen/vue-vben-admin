<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRouter } from 'vue-router';

import { Page } from '@vben/common-ui';
import { Card, Row, Col, Space, DatePicker } from 'ant-design-vue';
import { VbenCountToAnimator, VbenIcon } from '@vben-core/shadcn-ui';

import {
  SvgCardIcon,
  SvgDownloadIcon,
  SvgCakeIcon,
  SvgBellIcon,
} from '@vben/icons';

import dayjs from 'dayjs';

const router = useRouter();

// Date range - default last 7 days
const dateRange = ref<[dayjs.Dayjs, dayjs.Dayjs]>([
  dayjs().subtract(7, 'day'),
  dayjs(),
]);

const allAvailableDates = ref<string[]>([]);

const summaryData = ref({
  gpuCount: 0,
  userCount: 0,
  totalRequests: 0,
  totalTokens: 0,
});

// Format date helper
const formatDate = (date: Date) => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

// Available dates for disabled dates
const availableDates = computed(() => {
  return allAvailableDates.value.sort();
});

// Disabled dates
const disabledDate = (current: dayjs.Dayjs) => {
  const dateStr = current.format('YYYY-MM-DD');
  return !availableDates.value.includes(dateStr);
};

const loadData = async () => {
  const startStr = formatDate(dateRange.value[0].toDate());
  const endStr = formatDate(dateRange.value[1].toDate());

  let gpuDates: string[] = [];

  try {
    const gpuRes = await fetch('/src/assets/data-display/gpu_daily_stats-260411.json');
    const gpuData = await gpuRes.json();
    // Filter by date range
    const filteredGpu = gpuData.filter((d: any) => d.date >= startStr && d.date <= endStr);
    gpuDates = [...new Set(filteredGpu.map((d: any) => d.date))];
    const uniqueGpus = [...new Set(filteredGpu.map((d: any) => d.gpu_id))];
    summaryData.value.gpuCount = uniqueGpus.length;
  } catch (e) {
    console.error('GPU error:', e);
  }

  try {
    const usageRes = await fetch('/src/assets/data-display/usagerate-260411.json');
    const usageData = await usageRes.json();
    // Filter by date range
    const filteredUsage = usageData.filter((d: any) => d.date >= startStr && d.date <= endStr);
    const usageDates = [...new Set(filteredUsage.map((d: any) => d.date))];

    allAvailableDates.value = [...new Set([...gpuDates, ...usageDates])].sort();

    summaryData.value.userCount = [...new Set(filteredUsage.map((d: any) => d.userid))].length;
    summaryData.value.totalRequests = filteredUsage.reduce(
      (sum: number, d: any) => sum + d.request_count, 0);
    summaryData.value.totalTokens = filteredUsage.reduce(
      (sum: number, d: any) => sum + d.token_used, 0);
  } catch (e) {
    console.error('Usage error:', e);
  }
};

const overviewItems = computed(() => [
  { title: 'GPU 数量', value: summaryData.value.gpuCount, subtitle: '可用GPU', icon: SvgCardIcon },
  { title: '活跃用户', value: summaryData.value.userCount, subtitle: '总用户数', icon: SvgCakeIcon },
  { title: '总请求数', value: summaryData.value.totalRequests, subtitle: '累计请求', icon: SvgDownloadIcon },
  { title: 'Token 使用', value: summaryData.value.totalTokens, subtitle: 'Token总量', icon: SvgBellIcon },
]);

const menuItems = [
  { key: 'gpu', title: 'GPU 统计', desc: 'GPU使用率、温度、功耗监控', icon: '🖥️', path: '/data-display/gpu-stats', color: '#409eff', bgGradient: 'linear-gradient(135deg, #409eff 0%, #67c23a 100%)' },
  { key: 'usage', title: '使用率统计', desc: '用户请求数、Token使用量统计', icon: '📈', path: '/data-display/usage-rate', color: '#67c23a', bgGradient: 'linear-gradient(135deg, #67c23a 0%, #e6a23c 100%)' },
  { key: 'vllm', title: 'VLLM 统计', desc: '模型性能指标(TPU、缓存命中率)', icon: '⚡', path: '/data-display/vllm-stats', color: '#e6a23c', bgGradient: 'linear-gradient(135deg, #e6a23c 0%, #f56c6c 100%)' },
  { key: 'users', title: 'API 用户', desc: 'OpenAPI用户数据管理', icon: '👥', path: '/data-display/api-users', color: '#f56c6c', bgGradient: 'linear-gradient(135deg, #f56c6c 0%, #409eff 100%)' },
];

const navigateTo = (path: string) => {
  router.push(path);
};

const onDateRangeChange = () => {
  loadData();
};

onMounted(() => {
  loadData();
});
</script>

<template>
  <Page description="实时监控GPU使用率、用户请求、VLLM性能等关键指标" title="数据仪表盘">
    <!-- Date Range Selector -->
    <Card class="mb-4">
      <Space>
        <span>日期范围：</span>
        <DatePicker.RangePicker
          v-model:value="dateRange"
          :disabled-date="disabledDate"
          format="YYYY-MM-DD"
          @change="onDateRangeChange"
        />
      </Space>
    </Card>

    <!-- Stats Cards with VbenCountToAnimator and VbenIcon -->
    <Row :gutter="[16, 16]" class="mb-5">
      <Col :span="6" v-for="item in overviewItems" :key="item.title">
        <Card hoverable class="hover:shadow-lg transition-shadow">
          <div class="flex items-center justify-between">
            <div>
              <div class="text-gray-500 text-sm">{{ item.title }}</div>
              <VbenCountToAnimator
                :end-val="item.value"
                :start-val="1"
                class="text-2xl font-bold"
              />
              <div class="text-gray-400 text-xs">{{ item.subtitle }}</div>
            </div>
            <VbenIcon :icon="item.icon" class="text-3xl text-primary" />
          </div>
        </Card>
      </Col>
    </Row>

    <!-- Navigation Cards with gradient backgrounds -->
    <Row :gutter="[16, 16]">
      <Col v-for="item in menuItems" :key="item.key" :span="12">
        <Card
          hoverable
          class="menu-card cursor-pointer hover:shadow-xl transition-all duration-300"
          :style="{ borderTopColor: item.color }"
          @click="navigateTo(item.path)"
        >
          <div class="flex items-center gap-4">
            <div
              class="menu-icon w-14 h-14 rounded-xl flex items-center justify-center text-2xl"
              :style="{ background: item.bgGradient }"
            >
              {{ item.icon }}
            </div>
            <div class="menu-info flex-1">
              <div class="menu-title text-lg font-semibold">{{ item.title }}</div>
              <div class="menu-desc text-sm text-gray-500">{{ item.desc }}</div>
            </div>
            <div class="arrow text-gray-300">→</div>
          </div>
        </Card>
      </Col>
    </Row>

    <!-- Data Overview -->
    <Card title="数据概览" class="mt-5">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="p-4 bg-blue-100 rounded-lg border border-blue-200">
          <div class="text-sm text-blue-800 font-semibold mb-1">数据日期范围</div>
          <div class="font-medium text-blue-900">
            {{ dateRange[0].format('YYYY-MM-DD') }} ~ {{ dateRange[1].format('YYYY-MM-DD') }}
          </div>
        </div>
        <div class="p-4 bg-green-100 rounded-lg border border-green-200">
          <div class="text-sm text-green-800 font-semibold mb-1">数据更新频率</div>
          <div class="font-medium text-green-900">每日更新</div>
        </div>
        <div class="p-4 bg-orange-100 rounded-lg border border-orange-200">
          <div class="text-sm text-orange-800 font-semibold mb-1">支持的功能</div>
          <div class="font-medium text-orange-900">图表展示 / 数据筛选 / 导出</div>
        </div>
      </div>
    </Card>
  </Page>
</template>

<style scoped>
.mb-4 {
  margin-bottom: 16px;
}

.mb-5 {
  margin-bottom: 20px;
}

.mt-5 {
  margin-top: 20px;
}

.menu-card {
  border-top: 4px solid #409eff;
}

.menu-card:hover .arrow {
  transform: translateX(5px);
  color: #409eff;
}

.arrow {
  transition: all 0.3s;
}

.text-primary {
  color: var(--primary-color, #409eff);
}
</style>