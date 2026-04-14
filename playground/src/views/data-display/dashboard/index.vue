<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { Page } from '@vben/common-ui';

import { VbenCountToAnimator, VbenIcon } from '@vben-core/shadcn-ui';

import { Card, Col, DatePicker, Row, Space } from 'ant-design-vue';
import dayjs from 'dayjs';

const router = useRouter();

// Date range - default last 90 days (从 latest.json 读取)
const dateRange = ref<[dayjs.Dayjs, dayjs.Dayjs]>([
  dayjs().subtract(90, 'day'),
  dayjs(),
]);

// 数据版本信息
const dataVersion = ref<any>(null);

// 加载最新数据版本信息
const loadLatestInfo = async () => {
  try {
    const res = await fetch('/src/assets/data-display/latest.json');
    const info = await res.json();
    dataVersion.value = info;

    // 设置日期范围为最新数据的90天
    if (info.dateRange) {
      dateRange.value = [
        dayjs(info.dateRange.earliest),
        dayjs(info.dateRange.latest),
      ];
      console.warn('日期范围已设置:', info.dateRange);
    }
  } catch {
    console.warn('无法读取最新数据信息，使用默认范围');
    // 使用默认的90天范围
    dateRange.value = [dayjs().subtract(90, 'day'), dayjs()];
  }
};

// Store all available dates from all data
const allAvailableDates = ref<string[]>([]);

// All raw data
const allGpuData = ref<any[]>([]);
const allUsageData = ref<any[]>([]);

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

// Filter out invalid users (no Chinese name, deleted, system users)
const excludedUsernames = [
  'deleted',
  'code_review',
  'bmc',
  'root',
  'share',
  'test',
  'admin',
  'guest',
];
const isValidUser = (username: string) => {
  if (!username) return false;
  const lower = username.toLowerCase();
  // Exclude system users
  if (excludedUsernames.some((u) => lower.includes(u))) return false;
  // Must have Chinese characters or be a valid user
  return /[\u4E00-\u9FA5]/.test(username) || !lower.includes('deleted');
};

// Get all available dates from both datasets
const availableDates = computed(() => {
  const gpuDates = allGpuData.value.map((d) => d.date);
  const usageDates = allUsageData.value.map((d) => d.date);
  return [...new Set([...gpuDates, ...usageDates])].toSorted();
});

// Disabled dates - only allow dates that have data
const disabledDate = (current: dayjs.Dayjs) => {
  const dateStr = current.format('YYYY-MM-DD');
  return !availableDates.value.includes(dateStr);
};

// Load all data first to get available dates
const loadAllData = async () => {
  console.warn('Loading all data to get available dates...');

  // 从 latest.json 获取数据日期码
  const dataDate = dataVersion.value?.dataDate || '260411';

  try {
    const gpuRes = await fetch(
      `/src/assets/data-display/gpu_daily_stats-${dataDate}.json`,
    );
    allGpuData.value = await gpuRes.json();
    console.warn('GPU data loaded, count:', allGpuData.value.length);
  } catch (error) {
    console.error('GPU error:', error);
  }

  try {
    const usageRes = await fetch(
      `/src/assets/data-display/usagerate-${dataDate}.json`,
    );
    allUsageData.value = await usageRes.json();
    console.warn('Usage data loaded, count:', allUsageData.value.length);
  } catch (error) {
    console.error('Usage error:', error);
  }

  // Set all available dates
  allAvailableDates.value = availableDates.value;
  console.warn('Available dates:', allAvailableDates.value.length);

  // Calculate stats (日期范围已在 loadLatestInfo 中设置)
  filterDataByDateRange();
};

const filterDataByDateRange = () => {
  const startStr = formatDate(dateRange.value[0].toDate());
  const endStr = formatDate(dateRange.value[1].toDate());

  // Filter GPU data
  const filteredGpu = allGpuData.value.filter(
    (d) => d.date >= startStr && d.date <= endStr,
  );
  const uniqueGpus = [...new Set(filteredGpu.map((d) => d.gpu_id))];
  summaryData.value.gpuCount = uniqueGpus.length;

  // Filter Usage data and exclude invalid users
  const filteredUsage = allUsageData.value
    .filter((d) => d.date >= startStr && d.date <= endStr)
    .filter((d) => isValidUser(d.username));

  summaryData.value.userCount = new Set(
    filteredUsage.map((d) => d.userid),
  ).size;
  summaryData.value.totalRequests = filteredUsage.reduce(
    (sum: number, d: any) => sum + d.request_count,
    0,
  );
  summaryData.value.totalTokens = filteredUsage.reduce(
    (sum: number, d: any) => sum + d.token_used,
    0,
  );

  console.warn(
    'Filtered data - GPU:',
    filteredGpu.length,
    'Usage:',
    filteredUsage.length,
  );
};

const overviewItems = computed(() => [
  {
    title: 'GPU 数量',
    value: summaryData.value.gpuCount,
    subtitle: '可用GPU服务器',
    icon: 'mdi:memory',
    gradient: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    textColor: '#667eea',
  },
  {
    title: '活跃用户',
    value: summaryData.value.userCount,
    subtitle: '总用户数',
    icon: 'mdi:account-group',
    gradient: 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)',
    textColor: '#4facfe',
  },
  {
    title: '总请求数',
    value: summaryData.value.totalRequests,
    subtitle: '累计请求次数',
    icon: 'mdi:api',
    gradient: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
    textColor: '#f5576c',
  },
  {
    title: 'Token 消耗',
    value: summaryData.value.totalTokens,
    subtitle: 'Token使用总量',
    icon: 'mdi:coin',
    gradient: 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)',
    textColor: '#11998e',
  },
]);

const menuItems = [
  {
    key: 'gpu',
    title: 'GPU 统计',
    desc: 'GPU使用率、温度、功耗监控',
    icon: '🖥️',
    path: '/data-display/gpu-stats',
    color: '#409eff',
    bgGradient: 'linear-gradient(135deg, #409eff 0%, #67c23a 100%)',
  },
  {
    key: 'usage',
    title: '使用率统计',
    desc: '用户请求数、Token使用量统计',
    icon: '📈',
    path: '/data-display/usage-rate',
    color: '#67c23a',
    bgGradient: 'linear-gradient(135deg, #67c23a 0%, #e6a23c 100%)',
  },
  {
    key: 'vllm',
    title: 'VLLM 统计',
    desc: '模型性能指标(TPU、缓存命中率)',
    icon: '⚡',
    path: '/data-display/vllm-stats',
    color: '#e6a23c',
    bgGradient: 'linear-gradient(135deg, #e6a23c 0%, #f56c6c 100%)',
  },
  {
    key: 'users',
    title: 'API 用户',
    desc: 'OpenAPI用户数据管理',
    icon: '👥',
    path: '/data-display/api-users',
    color: '#f56c6c',
    bgGradient: 'linear-gradient(135deg, #f56c6c 0%, #409eff 100%)',
  },
];

const navigateTo = (path: string) => {
  router.push(path);
};

const onDateRangeChange = () => {
  filterDataByDateRange();
};

onMounted(async () => {
  // 先加载最新数据版本信息
  await loadLatestInfo();
  // 然后加载数据
  loadAllData();
});
</script>

<template>
  <Page
    description="实时监控GPU使用率、用户请求、VLLM性能等关键指标"
    title="数据仪表盘"
  >
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

    <!-- Stats Cards - 优化版 -->
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
              <VbenCountToAnimator
                :end-val="item.value"
                :start-val="1"
                class="text-3xl font-extrabold tracking-tight"
                :style="{ color: item.textColor }"
              />
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
              <div class="menu-title text-lg font-semibold">
                {{ item.title }}
              </div>
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
          <div class="text-sm text-blue-800 font-semibold mb-1">
            数据日期范围
          </div>
          <div class="font-medium text-blue-900">
            {{ dateRange[0].format('YYYY-MM-DD') }} ~
            {{ dateRange[1].format('YYYY-MM-DD') }}
          </div>
        </div>
        <div class="p-4 bg-green-100 rounded-lg border border-green-200">
          <div class="text-sm text-green-800 font-semibold mb-1">
            数据更新频率
          </div>
          <div class="font-medium text-green-900">每日更新</div>
        </div>
        <div class="p-4 bg-orange-100 rounded-lg border border-orange-200">
          <div class="text-sm text-orange-800 font-semibold mb-1">
            支持的功能
          </div>
          <div class="font-medium text-orange-900">
            图表展示 / 数据筛选 / 导出
          </div>
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

.stat-card {
  overflow: hidden;
  border-radius: 12px;
}

.stat-card:hover {
  transform: translateY(-4px);
}

.menu-card {
  border-top: 4px solid #409eff;
}

.menu-card:hover .arrow {
  color: #409eff;
  transform: translateX(5px);
}

.arrow {
  transition: all 0.3s;
}

.text-primary {
  color: var(--primary-color, #409eff);
}
</style>
