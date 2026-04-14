<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';

import { Page } from '@vben/common-ui';

import {
  Card,
  Row,
  Col,
  Table,
  Spin,
  Input,
  DatePicker,
  Space,
  Button,
  Select,
  message,
  Statistic,
} from 'ant-design-vue';
import VChart from 'vue-echarts';
import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';
import { BarChart, LineChart } from 'echarts/charts';
import {
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent,
  DataZoomComponent,
} from 'echarts/components';
import dayjs from 'dayjs';

// Filter out invalid users (no Chinese name, deleted, system users)
const excludedUsernames = ['deleted', 'code_review', 'bmc', 'root', 'share', 'test', 'admin', 'guest'];
const isValidUser = (username: string) => {
  if (!username) return false;
  const lower = username.toLowerCase();
  if (excludedUsernames.some(u => lower.includes(u))) return false;
  return /[\u4e00-\u9fa5]/.test(username) || !lower.includes('deleted');
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
const loading = ref(false);

// Filters
const searchText = ref('');
const dateRange = ref<[dayjs.Dayjs, dayjs.Dayjs]>([
  dayjs().subtract(90, 'day'),
  dayjs(),
]);
const selectedModel = ref<string>('all');

// Available dates
const availableDates = computed(() => {
  const dates = [...new Set(allUsageData.value.map((d) => d.date))];
  return dates.sort();
});

// Available models
const availableModels = computed(() => {
  const models = [...new Set(allUsageData.value.map((d) => d.model_name))];
  return [{ label: '全部模型', value: 'all' }, ...models.map((m) => ({ label: m, value: m }))];
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
    userCount: [...new Set(filtered.map((d) => d.userid))].length,
  };
});

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
        d.model_name?.toLowerCase().includes(search)
    );
  }

  return data;
});

// Load data using fetch
const loadData = async () => {
  loading.value = true;
  try {
    const response = await fetch('/src/assets/data-display/usagerate-260411.json');
    const data = await response.json();

    if (!data || data.length === 0) {
      throw new Error('数据为空');
    }

    allUsageData.value = data;
    usageData.value = data;
  } catch (e) {
    console.error('Error loading usage data:', e);
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
  return Array.from(dailyMap.values())
    .map((d) => ({ ...d, userCount: d.users.size }))
    .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
};

// Get top users by requests
const getTopUsersByRequests = (limit = 10) => {
  const userMap = new Map();
  filteredData.value.forEach((d) => {
    if (!userMap.has(d.userid)) {
      userMap.set(d.userid, {
        userid: d.userid,
        username: d.username,
        requests: 0,
        tokens: 0,
      });
    }
    const user = userMap.get(d.userid);
    user.requests += d.request_count;
    user.tokens += d.token_used;
  });
  return Array.from(userMap.values())
    .sort((a, b) => b.requests - a.requests)
    .slice(0, limit);
};

// Get top users by tokens
const getTopUsersByTokens = (limit = 10) => {
  const userMap = new Map();
  filteredData.value.forEach((d) => {
    if (!userMap.has(d.userid)) {
      userMap.set(d.userid, {
        userid: d.userid,
        username: d.username,
        requests: 0,
        tokens: 0,
      });
    }
    const user = userMap.get(d.userid);
    user.requests += d.request_count;
    user.tokens += d.token_used;
  });
  return Array.from(userMap.values())
    .sort((a, b) => b.tokens - a.tokens)
    .slice(0, limit);
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
const topUsersByRequestsColumns = [
  { title: '用户名', dataIndex: 'username', key: 'username' },
  { title: '请求数', dataIndex: 'requests', key: 'requests' },
  { title: 'Token使用量', dataIndex: 'tokens', key: 'tokens' },
];

const topUsersByTokensColumns = [
  { title: '用户名', dataIndex: 'username', key: 'username' },
  { title: 'Token使用量', dataIndex: 'tokens', key: 'tokens' },
  { title: '请求数', dataIndex: 'requests', key: 'requests' },
];

const detailColumns = [
  { title: '日期', dataIndex: 'date', key: 'date', width: 110 },
  { title: '用户名', dataIndex: 'username', key: 'username', width: 120 },
  { title: '模型', dataIndex: 'model_name', key: 'model_name', width: 150 },
  { title: '请求数', dataIndex: 'request_count', key: 'request_count' },
  { title: 'Token使用量', dataIndex: 'token_used', key: 'token_used' },
  { title: '平均耗时(ms)', dataIndex: 'average_elapsed_time', key: 'average_elapsed_time', width: 120 },
];

// Disabled dates
const disabledDate = (current: dayjs.Dayjs) => {
  const dateStr = current.format('YYYY-MM-DD');
  return !availableDates.value.includes(dateStr);
};

onMounted(() => {
  loadData();
});
</script>

<template>
  <Page description="监控用户请求数、Token使用量的每日变化趋势" title="用户使用率统计">
    <Spin :spinning="loading" tip="加载数据中...">
      <!-- Summary Stats -->
      <Row :gutter="[16, 16]" class="mb-4">
        <Col :span="6">
          <Card>
            <Statistic
              :value="summaryStats.totalRequests"
              title="总请求数"
              :value-style="{ color: '#409eff' }"
            />
          </Card>
        </Col>
        <Col :span="6">
          <Card>
            <Statistic
              :value="(summaryStats.totalTokens / 1000000).toFixed(2) + 'M'"
              title="总Token使用量"
              :value-style="{ color: '#67c23a' }"
            />
          </Card>
        </Col>
        <Col :span="6">
          <Card>
            <Statistic
              :value="(summaryStats.avgResponseTime / 1000).toFixed(2) + 's'"
              title="平均响应时间"
              :value-style="{ color: '#e6a23c' }"
            />
          </Card>
        </Col>
        <Col :span="6">
          <Card>
            <Statistic
              :value="summaryStats.userCount"
              title="活跃用户数"
              :value-style="{ color: '#f56c6c' }"
            />
          </Card>
        </Col>
      </Row>

      <!-- Filters -->
      <Card class="mb-4">
        <Space wrap>
          <div class="flex items-center gap-2">
            <span>搜索：</span>
            <Input
              v-model:value="searchText"
              placeholder="搜索用户名或模型"
              style="width: 180px"
              allow-clear
            />
          </div>

          <div class="flex items-center gap-2">
            <span>日期范围：</span>
            <DatePicker.RangePicker
              v-model:value="dateRange"
              :disabled-date="disabledDate"
              format="YYYY-MM-DD"
            />
          </div>

          <div class="flex items-center gap-2">
            <span>模型：</span>
            <Select
              v-model:value="selectedModel"
              :options="availableModels"
              style="width: 200px"
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

      <Row :gutter="[16, 16]" class="mb-4">
        <Col :span="24">
          <Card>
            <VChart
              :option="userChartOption"
              style="height: 300px"
              autoresize
            />
          </Card>
        </Col>
      </Row>

      <!-- Top Users -->
      <Row :gutter="[16, 16]" class="mb-4">
        <Col :span="12">
          <Card title="Top 10 用户 (请求数)">
            <Table
              :columns="topUsersByRequestsColumns"
              :data-source="getTopUsersByRequests(10)"
              :pagination="false"
              row-key="userid"
              size="small"
            >
              <template #bodyCell="{ column, record }">
                <template v-if="column.key === 'requests'">
                  {{ record.requests.toLocaleString() }}
                </template>
                <template v-if="column.key === 'tokens'">
                  {{ (record.tokens / 1000000).toFixed(2) }}M
                </template>
              </template>
            </Table>
          </Card>
        </Col>
        <Col :span="12">
          <Card title="Top 10 用户 (Token使用量)">
            <Table
              :columns="topUsersByTokensColumns"
              :data-source="getTopUsersByTokens(10)"
              :pagination="false"
              row-key="userid"
              size="small"
            >
              <template #bodyCell="{ column, record }">
                <template v-if="column.key === 'requests'">
                  {{ record.requests.toLocaleString() }}
                </template>
                <template v-if="column.key === 'tokens'">
                  {{ (record.tokens / 1000000).toFixed(2) }}M
                </template>
              </template>
            </Table>
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
        />
      </Card>
    </Spin>
  </Page>
</template>

<style scoped>
.mb-4 {
  margin-bottom: 16px;
}
</style>