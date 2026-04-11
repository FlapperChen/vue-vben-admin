<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';

import { Page } from '@vben/common-ui';

import {
  Card,
  Row,
  Col,
  Select,
  Table,
  Spin,
  Radio,
  DatePicker,
  Space,
  Button,
  message,
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
  { label: '使用率', value: 'usage' },
  { label: '温度', value: 'temperature' },
  { label: '功耗', value: 'power' },
];
const activeTab = ref('usage');

// Data
const gpuData = ref<any[]>([]);
const allGpuData = ref<any[]>([]);
const loading = ref(false);
const selectedGpu = ref<number>(0);

// Date range - default last 7 days
const dateRange = ref<[dayjs.Dayjs, dayjs.Dayjs]>([
  dayjs().subtract(7, 'day'),
  dayjs(),
]);

const gpuOptions = ref<any[]>([]);

// Available dates for disabled dates
const availableDates = computed(() => {
  const dates = [...new Set(allGpuData.value.map((d) => d.date))];
  return dates.sort();
});

// Format date helper
const formatDate = (date: Date) => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

// Load data using fetch
const loadData = async () => {
  loading.value = true;
  try {
    const response = await fetch('/src/assets/data-display/gpu_daily_stats-260411.json');
    const data = await response.json();

    if (!data || data.length === 0) {
      throw new Error('数据为空');
    }

    allGpuData.value = data;

    // Sort by date
    allGpuData.value.sort(
      (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()
    );

    // Get unique GPU IDs
    const gpuIds = [...new Set(data.map((d: any) => d.gpu_id))].sort((a: number, b: number) => a - b);
    gpuOptions.value = gpuIds.map((id: number) => ({ label: `GPU ${id}`, value: id }));

    if (gpuOptions.value.length > 0) {
      selectedGpu.value = gpuOptions.value[0].value;
    }

    filterDataByDateRange();
  } catch (e) {
    console.error('Error loading GPU data:', e);
  } finally {
    loading.value = false;
  }
};

// Filter data by date range and GPU
const filterDataByDateRange = () => {
  const startStr = formatDate(dateRange.value[0].toDate());
  const endStr = formatDate(dateRange.value[1].toDate());

  gpuData.value = allGpuData.value
    .filter((d) => d.date >= startStr && d.date <= endStr)
    .filter((d) => d.gpu_id === selectedGpu.value)
    .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
};

// Get chart data
const getGpuDataById = (gpuId: number) => {
  return gpuData.value
    .filter((d) => d.gpu_id === gpuId)
    .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
};

// Usage rate chart option
const usageChartOption = computed(() => {
  const data = getGpuDataById(selectedGpu.value);
  if (data.length === 0) return {};

  return {
    title: { text: 'GPU使用率变化 (%)', left: 'center' },
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
      name: '使用率 (%)',
      min: 0,
      max: 100,
    },
    series: [
      {
        name: '平均使用率',
        type: 'line',
        data: data.map((d) => d.avg_usage_rate),
        smooth: true,
        lineStyle: { width: 3 },
      },
      {
        name: '最大使用率',
        type: 'line',
        data: data.map((d) => d.max_usage_rate),
        smooth: true,
        lineStyle: { width: 2, type: 'dashed' },
      },
      {
        name: '最小使用率',
        type: 'line',
        data: data.map((d) => d.min_usage_rate),
        smooth: true,
        lineStyle: { width: 2, type: 'dotted' },
      },
    ],
    legend: { bottom: 30 },
    grid: { bottom: 80 },
  };
});

// Temperature chart option
const tempChartOption = computed(() => {
  const data = getGpuDataById(selectedGpu.value);
  if (data.length === 0) return {};

  return {
    title: { text: 'GPU温度变化 (°C)', left: 'center' },
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
      name: '温度 (°C)',
    },
    series: [
      {
        name: '平均温度',
        type: 'line',
        data: data.map((d) => d.avg_temperature),
        smooth: true,
        areaStyle: { opacity: 0.3 },
        lineStyle: { width: 3 },
      },
      {
        name: '最高温度',
        type: 'line',
        data: data.map((d) => d.max_temperature),
        smooth: true,
        lineStyle: { width: 2, type: 'dashed' },
      },
    ],
    legend: { bottom: 30 },
    grid: { bottom: 80 },
  };
});

// Power chart option
const powerChartOption = computed(() => {
  const data = getGpuDataById(selectedGpu.value);
  if (data.length === 0) return {};

  return {
    title: { text: 'GPU功耗变化 (W)', left: 'center' },
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
      name: '功耗 (W)',
    },
    series: [
      {
        name: '平均功耗',
        type: 'line',
        data: data.map((d) => d.avg_power_draw),
        smooth: true,
        areaStyle: { opacity: 0.3 },
        lineStyle: { width: 3 },
      },
      {
        name: '最大功耗',
        type: 'line',
        data: data.map((d) => d.max_power_draw),
        smooth: true,
        lineStyle: { width: 2, type: 'dashed' },
      },
    ],
    legend: { bottom: 30 },
    grid: { bottom: 80 },
  };
});

// Get current chart option based on active tab
const currentChartOption = computed(() => {
  switch (activeTab.value) {
    case 'usage':
      return usageChartOption.value;
    case 'temperature':
      return tempChartOption.value;
    case 'power':
      return powerChartOption.value;
    default:
      return usageChartOption.value;
  }
});

const onGpuChange = () => {
  filterDataByDateRange();
};

const onDateRangeChange = () => {
  filterDataByDateRange();
};

const onRefresh = () => {
  loadData();
  message.success('数据已刷新');
};

// Disabled dates
const disabledDate = (current: dayjs.Dayjs) => {
  const dateStr = current.format('YYYY-MM-DD');
  return !availableDates.value.includes(dateStr);
};

// Table columns
const columns = [
  { title: '日期', dataIndex: 'date', key: 'date', width: 120 },
  { title: 'GPU ID', dataIndex: 'gpu_id', key: 'gpu_id', width: 80 },
  { title: '平均使用率(%)', dataIndex: 'avg_usage_rate', key: 'avg_usage_rate' },
  { title: '最大使用率(%)', dataIndex: 'max_usage_rate', key: 'max_usage_rate' },
  { title: '平均温度(°C)', dataIndex: 'avg_temperature', key: 'avg_temperature' },
  { title: '最高温度(°C)', dataIndex: 'max_temperature', key: 'max_temperature' },
  { title: '平均功耗(W)', dataIndex: 'avg_power_draw', key: 'avg_power_draw' },
  { title: '最大功耗(W)', dataIndex: 'max_power_draw', key: 'max_power_draw' },
  { title: '采样数', dataIndex: 'sample_count', key: 'sample_count', width: 80 },
];

// Watch for tab change
watch(activeTab, () => {
  // Chart will auto-update due to computed property
});

onMounted(() => {
  loadData();
});
</script>

<template>
  <Page description="监控GPU使用率、温度、功耗的每日变化趋势" title="GPU每日统计">
    <Spin :spinning="loading" tip="加载数据中...">
      <!-- Controls -->
      <Card class="mb-4">
        <Space wrap>
          <div class="flex items-center gap-2">
            <span>GPU选择：</span>
            <Select
              v-model:value="selectedGpu"
              :options="gpuOptions"
              style="width: 120px"
              @change="onGpuChange"
            />
          </div>

          <div class="flex items-center gap-2">
            <span>日期范围：</span>
            <DatePicker.RangePicker
              v-model:value="dateRange"
              :disabled-date="disabledDate"
              format="YYYY-MM-DD"
              @change="onDateRangeChange"
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
      </Card>

      <!-- Main Chart -->
      <Card class="mb-4">
        <VChart
          :option="currentChartOption"
          style="height: 400px"
          autoresize
        />
      </Card>

      <!-- Quick Stats -->
      <Row :gutter="[16, 16]" class="mb-4">
        <Col :span="6">
          <Card size="small">
            <div class="text-center">
              <div class="text-gray-500 text-sm">平均使用率</div>
              <div class="text-2xl font-bold text-blue-600">
                {{
                  (
                    getGpuDataById(selectedGpu).reduce(
                      (sum, d) => sum + d.avg_usage_rate,
                      0
                    ) / (getGpuDataById(selectedGpu).length || 1)
                  ).toFixed(1)
                }}%
              </div>
            </div>
          </Card>
        </Col>
        <Col :span="6">
          <Card size="small">
            <div class="text-center">
              <div class="text-gray-500 text-sm">平均温度</div>
              <div class="text-2xl font-bold text-orange-600">
                {{
                  (
                    getGpuDataById(selectedGpu).reduce(
                      (sum, d) => sum + d.avg_temperature,
                      0
                    ) / (getGpuDataById(selectedGpu).length || 1)
                  ).toFixed(1)
                }}°C
              </div>
            </div>
          </Card>
        </Col>
        <Col :span="6">
          <Card size="small">
            <div class="text-center">
              <div class="text-gray-500 text-sm">平均功耗</div>
              <div class="text-2xl font-bold text-green-600">
                {{
                  (
                    getGpuDataById(selectedGpu).reduce(
                      (sum, d) => sum + d.avg_power_draw,
                      0
                    ) / (getGpuDataById(selectedGpu).length || 1)
                  ).toFixed(1)
                }}W
              </div>
            </div>
          </Card>
        </Col>
        <Col :span="6">
          <Card size="small">
            <div class="text-center">
              <div class="text-gray-500 text-sm">数据记录</div>
              <div class="text-2xl font-bold text-purple-600">
                {{ getGpuDataById(selectedGpu).length }}
              </div>
            </div>
          </Card>
        </Col>
      </Row>

      <!-- Data Table -->
      <Card title="详细数据">
        <Table
          :columns="columns"
          :data-source="getGpuDataById(selectedGpu)"
          :pagination="{ pageSize: 10, showSizeChanger: true }"
          row-key="id"
          size="small"
        />
      </Card>
    </Spin>
  </Page>
</template>

<style scoped>
.mb-4 {
  margin-bottom: 16px;
}

.text-blue-600 {
  color: #2563eb;
}

.text-orange-600 {
  color: #ea580c;
}

.text-green-600 {
  color: #16a34a;
}

.text-purple-600 {
  color: #9333ea;
}

.ml-4 {
  margin-left: 16px;
}
</style>