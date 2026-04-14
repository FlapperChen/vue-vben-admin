<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';

import { Page } from '@vben/common-ui';

import {
  Card,
  Row,
  Col,
  Table,
  Spin,
  Select,
  Space,
  Button,
  DatePicker,
  Radio,
  Statistic,
  message,
  Tag,
} from 'ant-design-vue';
import VChart from 'vue-echarts';
import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';
import { LineChart, BarChart } from 'echarts/charts';
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
  LineChart,
  BarChart,
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent,
  DataZoomComponent,
]);

// Tab options
const tabOptions = [
  { label: 'TPU 使用', value: 'tpu' },
  { label: '缓存命中率', value: 'cache' },
  { label: '请求队列', value: 'queue' },
];
const activeTab = ref('tpu');

// Data
const vllmData = ref<any[]>([]);
const allVllmData = ref<any[]>([]);
const loading = ref(false);
const selectedModel = ref<string>('');

// Date range
const dateRange = ref<[dayjs.Dayjs, dayjs.Dayjs]>([
  dayjs().subtract(90, 'day'),
  dayjs(),
]);

const modelOptions = ref<any[]>([]);

// Available dates
const availableDates = computed(() => {
  const dates = [...new Set(allVllmData.value.map((d) => d.date))];
  return dates.sort();
});

// Available models
const availableModels = computed(() => {
  const models = [...new Set(allVllmData.value.map((d) => d.model_name))];
  return [
    { label: '全部模型', value: 'all' },
    ...models.map((m) => ({ label: m, value: m })),
  ];
});

// Summary stats
const summaryStats = computed(() => {
  const data = filteredData.value;
  if (data.length === 0) {
    return {
      avgPromptTpu: 0,
      maxPromptTpu: 0,
      avgGenTpu: 0,
      avgCacheHit: 0,
      avgRunningReqs: 0,
    };
  }
  return {
    avgPromptTpu:
      data.reduce((sum, d) => sum + d.avg_prompt_tpu, 0) / data.length,
    maxPromptTpu: Math.max(...data.map((d) => d.max_prompt_tpu || 0)),
    avgGenTpu:
      data.reduce((sum, d) => sum + d.avg_generation_tpu, 0) / data.length,
    avgCacheHit:
      data.reduce((sum, d) => sum + d.avg_prefix_cache_hit_rate, 0) /
      data.length,
    avgRunningReqs:
      data.reduce((sum, d) => sum + d.avg_running_reqs, 0) / data.length,
  };
});

// Data filter list - exclude specific data points
// Format: { date: 'YYYY-MM-DD', field: 'fieldName', value: targetValue }
const dataFilterList = ref<Array<{ date: string; field: string; value: number }>>([
  { date: '2026-03-07', field: 'max_running_reqs', value: 90 },
  { date: '2026-03-26', field: 'max_running_reqs', value: 128 },
]);

// Check if a data point should be filtered
const shouldFilterData = (item: any) => {
  return dataFilterList.value.some(filter => {
    if (item.date !== filter.date) return false;
    return item[filter.field] === filter.value;
  });
};

// Filtered data (for TPU and Cache charts - no filter applied)
const filteredData = computed(() => {
  let data = [...allVllmData.value];

  // Filter by date range
  const startStr = dateRange.value[0].format('YYYY-MM-DD');
  const endStr = dateRange.value[1].format('YYYY-MM-DD');
  data = data.filter((d) => d.date >= startStr && d.date <= endStr);

  // Filter by model
  if (selectedModel.value && selectedModel.value !== 'all' && selectedModel.value !== '') {
    data = data.filter((d) => d.model_name === selectedModel.value);
  }

  return data;
});

// Filtered data for queue chart (with data filter applied)
const filteredQueueData = computed(() => {
  let data = [...allVllmData.value];

  // Filter by date range
  const startStr = dateRange.value[0].format('YYYY-MM-DD');
  const endStr = dateRange.value[1].format('YYYY-MM-DD');
  data = data.filter((d) => d.date >= startStr && d.date <= endStr);

  // Filter by model
  if (selectedModel.value && selectedModel.value !== 'all' && selectedModel.value !== '') {
    data = data.filter((d) => d.model_name === selectedModel.value);
  }

  // Apply filter list only for queue chart
  data = data.filter((d) => !shouldFilterData(d));

  return data;
});

// Load data using fetch
const loadData = async () => {
  loading.value = true;
  try {
    const response = await fetch('/src/assets/data-display/vllm_daily_stats-260411.json');
    const data = await response.json();

    if (!data || data.length === 0) {
      throw new Error('数据为空');
    }

    allVllmData.value = data;

    // Sort by date
    allVllmData.value.sort(
      (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()
    );

    // Get unique models
    const models = [...new Set(data.map((d: any) => d.model_name))];
    modelOptions.value = models.map((m: string) => ({ label: m, value: m }));

    // Set default model to MiniMax-M2.1 or M2.5
    if (modelOptions.value.length > 0 && !selectedModel.value) {
      const minimaxModel = modelOptions.value.find(
        (m: any) => m.value.includes('M2.1') || m.value.includes('M2.5') || m.value.includes('minimax')
      );
      selectedModel.value = minimaxModel ? minimaxModel.value : modelOptions.value[0].value;
    }
  } catch (e) {
    console.error('Error loading VLLM data:', e);
  } finally {
    loading.value = false;
  }
};

// Chart options - TPU Usage
const tpuChartOption = computed(() => {
  const data = filteredData.value;
  return {
    title: { text: 'TPU使用量变化', left: 'center' },
    tooltip: { trigger: 'axis' },
    dataZoom: [
      { type: 'inside', start: 0, end: 100 },
      { type: 'slider', start: 0, end: 100 },
    ],
    xAxis: {
      type: 'category',
      data: data.map((d) => d.date),
      name: '日期',
    },
    yAxis: {
      type: 'value',
      name: 'TPU',
    },
    series: [
      {
        name: '平均Prompt TPU',
        type: 'line',
        data: data.map((d) => d.avg_prompt_tpu),
        smooth: true,
        lineStyle: { width: 3 },
      },
      {
        name: '最大Prompt TPU',
        type: 'line',
        data: data.map((d) => d.max_prompt_tpu || 0),
        smooth: true,
        lineStyle: { width: 2, type: 'dashed' },
      },
      {
        name: '平均Generation TPU',
        type: 'line',
        data: data.map((d) => d.avg_generation_tpu),
        smooth: true,
        lineStyle: { width: 2 },
      },
    ],
    legend: { bottom: 55 },
    grid: { bottom: 100 },
  };
});

// Chart options - Cache Hit Rate
const cacheChartOption = computed(() => {
  const data = filteredData.value;
  return {
    title: { text: '缓存命中率变化 (%)', left: 'center' },
    tooltip: { trigger: 'axis' },
    dataZoom: [
      { type: 'inside', start: 0, end: 100 },
      { type: 'slider', start: 0, end: 100 },
    ],
    xAxis: {
      type: 'category',
      data: data.map((d) => d.date),
      name: '日期',
    },
    yAxis: {
      type: 'value',
      name: '命中率 (%)',
      min: 0,
    },
    series: [
      {
        name: 'Prefix Cache Hit Rate',
        type: 'line',
        data: data.map((d) => d.avg_prefix_cache_hit_rate),
        smooth: true,
        areaStyle: { opacity: 0.3 },
        lineStyle: { width: 3 },
      },
    ],
    legend: { bottom: 55 },
    grid: { bottom: 100 },
  };
});

// Filter specific values in chart data - return null to skip point in line chart
const getFilteredValue = (value: number, date: string, field: string) => {
  const shouldFilter = dataFilterList.value.some(filter =>
    date === filter.date && field === filter.field && value === filter.value
  );
  // Return null to skip the point (ECharts will connect previous and next points)
  return shouldFilter ? null : value;
};

// Chart options - Request Queue (use filtered data with value filtering)
const queueChartOption = computed(() => {
  const data = filteredData.value;
  return {
    title: { text: '请求队列变化', left: 'center' },
    tooltip: { trigger: 'axis' },
    dataZoom: [
      { type: 'inside', start: 0, end: 100 },
      { type: 'slider', start: 0, end: 100 },
    ],
    xAxis: {
      type: 'category',
      data: data.map((d) => d.date),
      name: '日期',
    },
    yAxis: {
      type: 'value',
      name: '请求数',
    },
    series: [
      {
        name: '平均运行请求',
        type: 'line',
        data: data.map((d) => d.avg_running_reqs),
        smooth: true,
        areaStyle: { opacity: 0.3 },
        connectNulls: true,
      },
      {
        name: '最大运行请求',
        type: 'line',
        data: data.map((d) => getFilteredValue(d.max_running_reqs || 0, d.date, 'max_running_reqs')),
        smooth: true,
        lineStyle: { type: 'dashed' },
        connectNulls: true,
      },
      {
        name: '平均等待请求',
        type: 'line',
        data: data.map((d) => d.avg_waitting_reqs || 0),
        smooth: true,
        connectNulls: true,
      },
    ],
    legend: { bottom: 55 },
    grid: { bottom: 100 },
  };
});

// Get current chart option
const currentChartOption = computed(() => {
  switch (activeTab.value) {
    case 'tpu':
      return tpuChartOption.value;
    case 'cache':
      return cacheChartOption.value;
    case 'queue':
      return queueChartOption.value;
    default:
      return tpuChartOption.value;
  }
});

// Disabled dates
const disabledDate = (current: dayjs.Dayjs) => {
  const dateStr = current.format('YYYY-MM-DD');
  return !availableDates.value.includes(dateStr);
};

// Table columns
const tableColumns = [
  { title: '日期', dataIndex: 'date', key: 'date', width: 110 },
  { title: '模型', dataIndex: 'model_name', key: 'model_name', width: 180 },
  { title: '引擎', dataIndex: 'engine', key: 'engine', width: 70 },
  { title: '平均Prompt TPU', dataIndex: 'avg_prompt_tpu', key: 'avg_prompt_tpu' },
  { title: '最大Prompt TPU', dataIndex: 'max_prompt_tpu', key: 'max_prompt_tpu' },
  { title: '平均Gen TPU', dataIndex: 'avg_generation_tpu', key: 'avg_generation_tpu' },
  { title: '缓存命中率(%)', dataIndex: 'avg_prefix_cache_hit_rate', key: 'avg_prefix_cache_hit_rate' },
  { title: '采样数', dataIndex: 'sample_count', key: 'sample_count', width: 80 },
];

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

// Watch for tab change
watch(activeTab, () => {
  // Chart will auto-update due to computed property
});

onMounted(() => {
  loadData();
});
</script>

<template>
  <Page description="监控模型性能指标(TPU、缓存命中率)" title="VLLM每日统计">
    <Spin :spinning="loading" tip="加载数据中...">
      <!-- Summary Stats -->
      <Row :gutter="[16, 16]" class="mb-4">
        <Col :span="6">
          <Card>
            <Statistic
              :value="summaryStats.avgPromptTpu.toFixed(0)"
              title="平均Prompt TPU"
              :value-style="{ color: '#409eff' }"
            />
          </Card>
        </Col>
        <Col :span="6">
          <Card>
            <Statistic
              :value="summaryStats.maxPromptTpu.toFixed(0)"
              title="最大Prompt TPU"
              :value-style="{ color: '#67c23a' }"
            />
          </Card>
        </Col>
        <Col :span="6">
          <Card>
            <Statistic
              :value="summaryStats.avgCacheHit.toFixed(1) + '%'"
              title="平均缓存命中率"
              :value-style="{ color: '#e6a23c' }"
            />
          </Card>
        </Col>
        <Col :span="6">
          <Card>
            <Statistic
              :value="summaryStats.avgRunningReqs.toFixed(2)"
              title="平均运行请求"
              :value-style="{ color: '#f56c6c' }"
            />
          </Card>
        </Col>
      </Row>

      <!-- Controls -->
      <Card class="mb-4">
        <Space wrap>
          <div class="flex items-center gap-2">
            <span>模型选择：</span>
            <Select
              v-model:value="selectedModel"
              :options="availableModels"
              style="width: 250px"
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

          <Button type="primary" @click="onRefresh">刷新数据</Button>

          <div class="flex items-center gap-2 ml-4">
            <span>指标切换：</span>
            <Radio.Group v-model:value="activeTab" button-style="solid">
              <Radio.Button
                v-for="tab in tabOptions"
                :key="tab.value"
                :value="tab.value"
              >
                {{ tab.label }}
              </Radio.Button>
            </Radio.Group>
          </div>
        </Space>
        <!-- Filter Info -->
        <div v-if="dataFilterList.length > 0" class="mt-3 text-sm text-gray-500">
          <span>已过滤数据：</span>
          <Tag v-for="(filter, index) in dataFilterList" :key="index" color="red" class="ml-1">
            {{ filter.date }} {{ filter.field }}={{ filter.value }}
          </Tag>
        </div>
      </Card>

      <!-- Main Chart -->
      <Card class="mb-4">
        <VChart
          :option="currentChartOption"
          style="height: 400px"
          autoresize
        />
      </Card>

      <!-- Additional Charts -->
      <Row v-if="filteredData.length > 0" :gutter="[16, 16]" class="mb-4">
        <Col :span="12">
          <Card title="KV Cache 使用">
            <VChart
              :option="{
                title: { text: 'GPU KV Cache 变化', left: 'center' },
                tooltip: { trigger: 'axis' },
                xAxis: {
                  type: 'category',
                  data: filteredData.map(d => d.date),
                },
                yAxis: { type: 'value', name: 'Cache' },
                series: [
                  { name: '平均', type: 'line', data: filteredData.map(d => d.avg_gpu_kv_cache || 0), smooth: true },
                  { name: '最大', type: 'line', data: filteredData.map(d => d.max_gpu_kv_cache || 0), smooth: true }
                ],
                grid: { bottom: 40 },
              }"
              style="height: 250px"
              autoresize
            />
          </Card>
        </Col>
        <Col :span="12">
          <Card title="请求统计">
            <VChart
              :option="{
                title: { text: '运行vs等待请求', left: 'center' },
                tooltip: { trigger: 'axis' },
                xAxis: {
                  type: 'category',
                  data: filteredData.map(d => d.date),
                },
                yAxis: { type: 'value', name: '请求数' },
                series: [
                  { name: '运行中', type: 'bar', data: filteredData.map(d => d.avg_running_reqs) },
                  { name: '等待中', type: 'bar', data: filteredData.map(d => d.avg_waitting_reqs || 0) }
                ],
                grid: { bottom: 40 },
              }"
              style="height: 250px"
              autoresize
            />
          </Card>
        </Col>
      </Row>

      <!-- Data Table -->
      <Card title="详细数据">
        <Table
          :columns="tableColumns"
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

.ml-4 {
  margin-left: 16px;
}
</style>