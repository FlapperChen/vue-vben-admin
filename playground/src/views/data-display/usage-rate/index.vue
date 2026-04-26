<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import VChart from 'vue-echarts';

import { Page } from '@vben/common-ui';

import { VbenCountToAnimator, VbenIcon } from '@vben-core/shadcn-ui';

import {
  Button,
  Card,
  Col,
  DatePicker,
  message,
  Row,
  Select,
  Space,
  Spin,
  Table,
} from 'ant-design-vue';
import dayjs from 'dayjs';
import { BarChart, LineChart } from 'echarts/charts';
import {
  DataZoomComponent,
  GridComponent,
  LegendComponent,
  TitleComponent,
  TooltipComponent,
} from 'echarts/components';
import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';

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
  'afa',
  'anythingllm',
  '修梦思',
  '倪俊明',
];
const isValidUser = (username: string) => {
  if (!username) return false;
  const lower = username.toLowerCase();
  if (excludedUsernames.some((u) => lower.includes(u))) return false;
  return /[\u4E00-\u9FA5]/.test(username) || !lower.includes('deleted');
};

// Register ECharts components
use([
  CanvasRenderer,
  BarChart,
  LineChart,
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent,
  DataZoomComponent,
]);

// Data
const usageData = ref<any[]>([]);
const allUsageData = ref<any[]>([]);
const usersInfoData = ref<any[]>([]);
const loading = ref(false);

// Map username to displayname
const usernameToDisplayname = computed(() => {
  const map = new Map<string, string>();
  usersInfoData.value.forEach((u) => {
    if (u.username && u.displayname) {
      map.set(u.username, u.displayname);
    }
  });
  return map;
});

// Get display name for a username
const getDisplayName = (username: string) => {
  return usernameToDisplayname.value.get(username) || username;
};

// Filters
const searchText = ref('');
const dateRange = ref<[dayjs.Dayjs, dayjs.Dayjs]>([
  dayjs().subtract(90, 'day'),
  dayjs(),
]);
const selectedModel = ref<string>('all');

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
  }
};

// Available dates
const availableDates = computed(() => {
  const dates = [...new Set(allUsageData.value.map((d) => d.date))];
  return dates.toSorted();
});

// Available models
const availableModels = computed(() => {
  const models = [...new Set(allUsageData.value.map((d) => d.model_name))];
  return [
    { label: '全部模型', value: 'all' },
    ...models.map((m) => ({ label: m, value: m })),
  ];
});

// Summary stats
const summaryStats = computed(() => {
  const filtered = filteredData.value;
  return {
    totalRequests: filtered.reduce((sum, d) => sum + d.request_count, 0),
    totalTokens: filtered.reduce((sum, d) => sum + d.token_used, 0),
    avgResponseTime:
      filtered.length > 0
        ? filtered.reduce((sum, d) => sum + (d.average_elapsed_time || 0), 0) /
          filtered.length
        : 0,
    userCount: new Set(filtered.map((d) => d.userid)).size,
  };
});

// Overview items for stats cards - 优化版
const overviewItems = computed(() => [
  {
    title: '总请求数',
    value: summaryStats.value.totalRequests,
    subtitle: '累计请求次数',
    icon: 'mdi:api',
    gradient: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    textColor: '#667eea',
  },
  {
    title: 'Token消耗',
    value: summaryStats.value.totalTokens,
    subtitle: 'Token使用总量',
    icon: 'mdi:coin',
    gradient: 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)',
    textColor: '#11998e',
    format: 'token',
  },
  {
    title: '响应耗时',
    value: summaryStats.value.avgResponseTime,
    subtitle: '平均响应时间',
    icon: 'mdi:clock-outline',
    gradient: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
    textColor: '#f5576c',
    format: 'time',
  },
  {
    title: '活跃用户',
    value: summaryStats.value.userCount,
    subtitle: '独立用户数',
    icon: 'mdi:account-group',
    gradient: 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)',
    textColor: '#4facfe',
  },
]);

// Format token value
const formatTokenValue = (value: number) => {
  if (value >= 1_000_000_000) {
    return `${(value / 1_000_000_000).toFixed(1)}B`;
  }
  if (value >= 1_000_000) {
    return `${(value / 1_000_000).toFixed(2)}M`;
  }
  if (value >= 1000) {
    return `${(value / 1000).toFixed(1)}K`;
  }
  return value.toLocaleString();
};

// Selected user for individual chart
const selectedUser = ref<string>('');

// Available users for dropdown
const availableUsers = computed(() => {
  const users = [...new Set(allUsageData.value.map((d) => d.username))];
  return users
    .filter((u) => isValidUser(u))
    .map((u) => ({
      label: getDisplayName(u),
      value: u,
    }))
    .toSorted((a, b) => a.label.localeCompare(b.label, 'zh-CN'));
});

// Auto-select user with highest token consumption when data loads
watch(
  () => allUsageData.value.length,
  (newLen) => {
    if (newLen > 0 && !selectedUser.value) {
      // Calculate total tokens per user
      const userTokensMap = new Map<string, number>();
      allUsageData.value.forEach((d) => {
        if (isValidUser(d.username)) {
          const current = userTokensMap.get(d.username) || 0;
          userTokensMap.set(d.username, current + (d.token_used || 0));
        }
      });

      // Find user with highest tokens
      let maxUser = '';
      let maxTokens = 0;
      userTokensMap.forEach((tokens, user) => {
        if (tokens > maxTokens) {
          maxTokens = tokens;
          maxUser = user;
        }
      });

      if (maxUser) {
        selectedUser.value = maxUser;
      }
    }
  },
);

// Filtered data
const filteredData = computed(() => {
  let data = [...allUsageData.value];

  // Filter by date range
  const startStr = dateRange.value[0].format('YYYY-MM-DD');
  const endStr = dateRange.value[1].format('YYYY-MM-DD');
  data = data.filter((d) => d.date >= startStr && d.date <= endStr);

  // Filter by model
  if (selectedModel.value && selectedModel.value !== 'all') {
    data = data.filter((d) => d.model_name === selectedModel.value);
  }

  // Filter invalid users
  data = data.filter((d) => isValidUser(d.username));

  // Filter by search
  if (searchText.value) {
    const search = searchText.value.toLowerCase();
    data = data.filter(
      (d) =>
        d.username?.toLowerCase().includes(search) ||
        d.model_name?.toLowerCase().includes(search),
    );
  }

  return data;
});

// Load data using fetch
const loadData = async () => {
  loading.value = true;
  // 从 latest.json 获取数据日期码
  const dataDate = dataVersion.value?.dataDate || '20260411';

  try {
    // Load usage data
    const response = await fetch(
      `/src/assets/data-display/usagerate-${dataDate}.json`,
    );
    const data = await response.json();

    if (!data || data.length === 0) {
      throw new Error('数据为空');
    }

    allUsageData.value = data;
    usageData.value = data;

    // Load users info for display names
    try {
      const usersRes = await fetch(
        `/src/assets/data-display/openapi_users-${dataDate}.json`,
      );
      const usersData = await usersRes.json();
      if (usersData && usersData.length > 0) {
        usersInfoData.value = usersData;
      }
    } catch {
      console.warn('无法加载用户信息数据');
    }
  } catch (error) {
    console.error('Error loading usage data:', error);
  } finally {
    loading.value = false;
  }
};

// Get daily aggregated data
const getDailyData = () => {
  const dailyMap = new Map();
  filteredData.value.forEach((d) => {
    if (!dailyMap.has(d.date)) {
      dailyMap.set(d.date, {
        date: d.date,
        requests: 0,
        tokens: 0,
        users: new Set(),
      });
    }
    const day = dailyMap.get(d.date);
    day.requests += d.request_count;
    day.tokens += d.token_used;
    day.users.add(d.userid);
  });
  return [...dailyMap.values()]
    .map((d) => ({ ...d, userCount: d.users.size }))
    .toSorted(
      (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime(),
    );
};

// Get daily data for selected user
const getUserDailyData = () => {
  if (!selectedUser.value) return [];

  const dailyMap = new Map();
  filteredData.value
    .filter((d) => d.username === selectedUser.value)
    .forEach((d) => {
      if (!dailyMap.has(d.date)) {
        dailyMap.set(d.date, {
          date: d.date,
          requests: 0,
          tokens: 0,
        });
      }
      const day = dailyMap.get(d.date);
      day.requests += d.request_count;
      day.tokens += d.token_used;
    });
  return [...dailyMap.values()].toSorted(
    (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime(),
  );
};

// Chart options - Request Count
const requestChartOption = computed(() => {
  const dailyData = getDailyData();
  return {
    title: { text: '每日请求数变化', left: 'center' },
    tooltip: { trigger: 'axis' },
    dataZoom: [
      { type: 'inside', start: 0, end: 100 },
      { type: 'slider', start: 0, end: 100 },
    ],
    xAxis: {
      type: 'category',
      data: dailyData.map((d) => d.date),
      name: '日期',
    },
    yAxis: {
      type: 'value',
      name: '请求数',
    },
    series: [
      {
        name: '请求数',
        type: 'bar',
        data: dailyData.map((d) => d.requests),
        itemStyle: { color: '#409eff' },
        areaStyle: { opacity: 0.2 },
      },
    ],
    grid: { bottom: 100 },
  };
});

// Chart options - Token Usage
const tokenChartOption = computed(() => {
  const dailyData = getDailyData();
  return {
    title: { text: '每日Token使用量变化', left: 'center' },
    tooltip: { trigger: 'axis' },
    dataZoom: [
      { type: 'inside', start: 0, end: 100 },
      { type: 'slider', start: 0, end: 100 },
    ],
    xAxis: {
      type: 'category',
      data: dailyData.map((d) => d.date),
      name: '日期',
    },
    yAxis: {
      type: 'value',
      name: 'Token数',
    },
    series: [
      {
        name: 'Token使用量',
        type: 'line',
        data: dailyData.map((d) => d.tokens),
        smooth: true,
        itemStyle: { color: '#67c23a' },
        areaStyle: { opacity: 0.3 },
      },
    ],
    grid: { bottom: 100 },
  };
});

// Chart options - User Activity
const userChartOption = computed(() => {
  const dailyData = getDailyData();
  return {
    title: { text: '每日活跃用户数', left: 'center' },
    tooltip: { trigger: 'axis' },
    dataZoom: [
      { type: 'inside', start: 0, end: 100 },
      { type: 'slider', start: 0, end: 100 },
    ],
    xAxis: {
      type: 'category',
      data: dailyData.map((d) => d.date),
      name: '日期',
    },
    yAxis: {
      type: 'value',
      name: '用户数',
    },
    series: [
      {
        name: '活跃用户',
        type: 'line',
        data: dailyData.map((d) => d.userCount),
        smooth: true,
        itemStyle: { color: '#e6a23c' },
        areaStyle: { opacity: 0.3 },
      },
    ],
    grid: { bottom: 100 },
  };
});

// Chart options - Individual User Daily Usage
const userDailyChartOption = computed(() => {
  const dailyData = getUserDailyData();

  // Calculate max values for scaling
  let maxRequests = 100;
  let maxTokens = 100;
  if (dailyData.length > 0) {
    maxRequests = Math.max(...dailyData.map((d) => d.requests)) * 1.2;
    maxTokens = Math.max(...dailyData.map((d) => d.tokens)) * 1.2;
    maxRequests = Math.ceil(maxRequests / 10) * 10;
    maxTokens = Math.ceil(maxTokens / 1000) * 1000;
    if (maxTokens < 1000) maxTokens = 1000;
  }

  if (!selectedUser.value) {
    return {
      title: { text: '用户每日使用情况', left: 'center' },
      xAxis: { type: 'category', data: ['暂无数据'] },
      yAxis: [
        { type: 'value', name: '请求数' },
        { type: 'value', name: 'Token数' },
      ],
      series: [
        {
          name: '请求数',
          type: 'bar',
          data: [0],
          itemStyle: { color: '#ccc' },
        },
        {
          name: 'Token使用量',
          type: 'line',
          yAxisIndex: 1,
          data: [0],
          itemStyle: { color: '#ccc' },
        },
      ],
      graphic: {
        type: 'text',
        left: 'center',
        top: 'middle',
        style: {
          text: '请在上方选择用户查看个人趋势',
          fontSize: 16,
          fill: '#999',
        },
      },
    };
  }

  return {
    title: {
      text: `用户每日使用情况 - ${getDisplayName(selectedUser.value)}`,
      left: 'center',
    },
    tooltip: { trigger: 'axis' },
    legend: {
      bottom: 55,
      data: ['请求数', 'Token使用量'],
    },
    dataZoom: [
      { type: 'inside', start: 0, end: 100 },
      { type: 'slider', start: 0, end: 100 },
    ],
    xAxis: {
      type: 'category',
      data: dailyData.map((d) => d.date),
      name: '日期',
    },
    yAxis: [
      {
        type: 'value',
        name: '请求数',
        max: maxRequests,
      },
      {
        type: 'value',
        name: 'Token数',
        max: maxTokens,
      },
    ],
    series: [
      {
        name: '请求数',
        type: 'bar',
        data: dailyData.map((d) => d.requests),
        itemStyle: { color: '#5470c6' },
      },
      {
        name: 'Token使用量',
        type: 'line',
        yAxisIndex: 1,
        data: dailyData.map((d) => d.tokens),
        smooth: true,
        lineStyle: { width: 3 },
        areaStyle: { opacity: 0.3 },
        itemStyle: { color: '#ee6666' },
      },
    ],
    grid: { bottom: 100 },
  };
});

const onRefresh = () => {
  loadData();
  message.success('数据已刷新');
};

// Table pagination state
const tablePagination = ref({
  current: 1,
  pageSize: 10,
  showSizeChanger: true,
  pageSizeOptions: ['10', '20', '50', '100'],
  showTotal: (total: number) => `共 ${total} 条`,
});

// Handle table change
const handleTableChange = (pagination: any) => {
  tablePagination.value.current = pagination.current;
  tablePagination.value.pageSize = pagination.pageSize;
};

// Table columns
const detailColumns = [
  { title: '日期', dataIndex: 'date', key: 'date', width: 120 },
  { title: '用户名', dataIndex: 'username', key: 'username', width: 130 },
  { title: '模型', dataIndex: 'model_name', key: 'model_name', width: 180 },
  {
    title: '请求数',
    dataIndex: 'request_count',
    key: 'request_count',
    width: 100,
  },
  {
    title: 'Token使用量',
    dataIndex: 'token_used',
    key: 'token_used',
    width: 120,
  },
  {
    title: '平均耗时(ms)',
    dataIndex: 'average_elapsed_time',
    key: 'average_elapsed_time',
    width: 120,
  },
];

// Disabled dates
const disabledDate = (current: dayjs.Dayjs) => {
  const dateStr = current.format('YYYY-MM-DD');
  return !availableDates.value.includes(dateStr);
};

onMounted(async () => {
  // 先加载最新数据版本信息
  await loadLatestInfo();
  // 然后加载数据
  loadData();
});
</script>

<template>
  <Page
    description="监控用户请求数、Token使用量的每日变化趋势"
    title="用户使用率统计"
  >
    <Spin :spinning="loading" tip="加载数据中...">
      <!-- Summary Stats Cards - 优化版 -->
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
                <template v-if="item.format">
                  <div
                    class="text-3xl font-extrabold tracking-tight"
                    :style="{ color: item.textColor }"
                  >
                    {{
                      item.format === 'token'
                        ? formatTokenValue(item.value)
                        : `${(item.value / 1000).toFixed(2)}s`
                    }}
                  </div>
                </template>
                <template v-else>
                  <VbenCountToAnimator
                    :end-val="item.value"
                    :start-val="1"
                    class="text-3xl font-extrabold tracking-tight"
                    :style="{ color: item.textColor }"
                  />
                </template>
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

      <!-- Filters -->
      <Card class="mb-4">
        <Space wrap>
          <div class="flex items-center gap-2">
            <span class="filter-label">模型：</span>
            <Select
              v-model:value="selectedModel"
              :options="availableModels"
              style="width: 200px"
            />
          </div>

          <div class="flex items-center gap-2">
            <span class="filter-label">日期范围：</span>
            <DatePicker.RangePicker
              v-model:value="dateRange"
              :disabled-date="disabledDate"
              format="YYYY-MM-DD"
            />
          </div>

          <div class="flex items-center gap-2">
            <span class="filter-label">选择用户：</span>
            <Select
              v-model:value="selectedUser"
              :options="availableUsers"
              style="width: 220px"
              placeholder="选择用户查看个人趋势"
              allow-clear
              show-search
              :filter-option="
                (input: string, option: any) =>
                  option.label.toLowerCase().includes(input.toLowerCase())
              "
            />
          </div>

          <Button type="primary" @click="onRefresh">刷新数据</Button>
        </Space>
      </Card>

      <!-- Charts -->
      <Row :gutter="[16, 16]" class="mb-4">
        <Col :span="12">
          <Card>
            <VChart
              :option="requestChartOption"
              style="height: 300px"
              autoresize
            />
          </Card>
        </Col>
        <Col :span="12">
          <Card>
            <VChart
              :option="tokenChartOption"
              style="height: 300px"
              autoresize
            />
          </Card>
        </Col>
      </Row>

      <!-- Charts Row 2 -->
      <Row :gutter="[16, 16]" class="mb-4">
        <Col :span="12">
          <Card>
            <VChart
              :option="userChartOption"
              style="height: 350px"
              autoresize
            />
          </Card>
        </Col>
        <Col :span="12">
          <Card>
            <VChart
              :option="userDailyChartOption"
              style="height: 350px"
              autoresize
            />
          </Card>
        </Col>
      </Row>

      <!-- Detail Table -->
      <Card title="详细数据">
        <Table
          :columns="detailColumns"
          :data-source="filteredData"
          :pagination="tablePagination"
          row-key="id"
          size="small"
          @change="handleTableChange"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'username'">
              {{ getDisplayName(record.username) }}
            </template>
            <template v-if="column.key === 'token_used'">
              {{ (record.token_used / 1000).toFixed(1) }}K
            </template>
            <template v-if="column.key === 'request_count'">
              {{ record.request_count?.toLocaleString() }}
            </template>
          </template>
        </Table>
      </Card>
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

.stat-card:hover {
  transform: translateY(-4px);
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

/* Filter labels */
.filter-label {
  font-size: 14px;
  font-weight: 500;
  color: #374151;
  white-space: nowrap;
}

/* Optimize select dropdown for better Chinese font display */
:deep(.ant-select-selector) {
  font-size: 14px !important;
}

:deep(.ant-select-selection-item) {
  font-size: 14px !important;
}

:deep(.ant-select-selection-placeholder) {
  font-size: 14px !important;
}

:deep(.ant-picker) {
  font-size: 14px !important;
}

:deep(.ant-input) {
  font-size: 14px !important;
}
</style>
