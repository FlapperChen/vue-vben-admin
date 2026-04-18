<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import VChart from 'vue-echarts';

import { Page } from '@vben/common-ui';

import { VbenIcon } from '@vben-core/shadcn-ui';

import {
  Button,
  Card,
  Col,
  DatePicker,
  message,
  Row,
  Space,
  Spin,
  Table,
  Tag,
} from 'ant-design-vue';
import dayjs from 'dayjs';
import { LineChart, PieChart } from 'echarts/charts';
import {
  DataZoomComponent,
  GridComponent,
  LegendComponent,
  TitleComponent,
  TooltipComponent,
} from 'echarts/components';
import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';

// Register ECharts components
use([
  CanvasRenderer,
  PieChart,
  LineChart,
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent,
  DataZoomComponent,
]);

// Data
const allAnythingllmData = ref<any[]>([]);
const allAnythingllmDocsData = ref<any[]>([]);
const loading = ref(false);

// Date range
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
      console.warn('AnythingLLM日期范围已设置:', info.dateRange);
    }
  } catch {
    console.warn('无法读取最新数据信息，使用默认范围');
  }
};

// Available dates
const availableDates = computed(() => {
  const dates = [...new Set(allAnythingllmData.value.map((d) => d.date))];
  return dates.toSorted();
});

// Summary stats
const summaryStats = computed(() => {
  const data = filteredData.value;
  if (data.length === 0) {
    return {
      totalDocs: 0,
      totalWps: 0,
      totalUploads: 0,
      avgEmbedRate: 0,
      recordCount: 0,
    };
  }

  // 计算记录数
  const recordCount = data.length;

  // 计算平均嵌入率
  const embedRatios = data
    .filter((d) => d.embed_ratio > 0)
    .map((d) => d.embed_ratio);
  const avgEmbedRate =
    embedRatios.length > 0
      ? embedRatios.reduce((sum, r) => sum + r, 0) / embedRatios.length
      : 0;

  // 获取最新日期的所有记录（汇总所有文件类型）- 降序后第一个就是最新的
  const latestDate = data[0]?.date;
  if (!latestDate) {
    return {
      totalDocs: 0,
      totalWps: 0,
      totalUploads: 0,
      avgEmbedRate,
      recordCount,
    };
  }

  const latestRecords = data.filter((d) => d.date === latestDate);

  // 汇总最新日期所有文件类型的值
  const totalWps = latestRecords.reduce(
    (sum, d) => sum + (d.wps_total || 0),
    0,
  );
  const totalUploads = latestRecords.reduce(
    (sum, d) => sum + (d.upload_num || 0),
    0,
  );

  return {
    totalDocs: totalUploads,
    totalWps,
    totalUploads,
    avgEmbedRate,
    recordCount,
  };
});

// Overview items for stats cards - 优化版
const overviewItems = computed(() => [
  {
    title: '总文档数',
    value: summaryStats.value.totalDocs,
    subtitle: '文档总数',
    icon: 'mdi:file-document',
    gradient: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    textColor: '#667eea',
  },
  {
    title: '总字数',
    value: summaryStats.value.totalWps,
    subtitle: '总Word数',
    icon: 'mdi:text-box',
    gradient: 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)',
    textColor: '#11998e',
    format: 'wps',
  },
  {
    title: '上传数',
    value: summaryStats.value.totalUploads,
    subtitle: '上传文档数',
    icon: 'mdi:upload',
    gradient: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
    textColor: '#f5576c',
  },
  {
    title: '平均嵌入率',
    value: summaryStats.value.avgEmbedRate,
    subtitle: '嵌入成功率',
    icon: 'mdi:check-circle',
    gradient: 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)',
    textColor: '#4facfe',
    format: 'percent',
  },
  {
    title: '文档总数',
    value: docsSummaryStats.value.totalFileNum,
    subtitle: '知识库文档总数',
    icon: 'mdi:file-multiple',
    gradient: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    textColor: '#667eea',
  },
  {
    title: '今日上传',
    value: docsSummaryStats.value.totalDailyUpload,
    subtitle: '今日上传文档数',
    icon: 'mdi:file-upload',
    gradient: 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)',
    textColor: '#11998e',
  },
  {
    title: '今日更新',
    value: docsSummaryStats.value.totalDailyUpdate,
    subtitle: '今日更新文档数',
    icon: 'mdi:file-sync',
    gradient: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
    textColor: '#f5576c',
  },
]);

// Format wps value
const formatWpsValue = (value: number) => {
  if (value >= 1_000_000) {
    return `${(value / 1_000_000).toFixed(1)}M`;
  }
  if (value >= 1000) {
    return `${(value / 1000).toFixed(1)}K`;
  }
  return value.toLocaleString();
};

// Filtered data (descending - for table and stats)
const filteredData = computed(() => {
  let data = [...allAnythingllmData.value];

  // Filter by date range
  const startStr = dateRange.value[0].format('YYYY-MM-DD');
  const endStr = dateRange.value[1].format('YYYY-MM-DD');
  data = data.filter((d) => d.date >= startStr && d.date <= endStr);

  return data;
});

// Chart data (ascending - for charts)
const chartData = computed(() => {
  return [...filteredData.value].toReversed();
});

// Filtered documents data
const filteredDocsData = computed(() => {
  let data = [...allAnythingllmDocsData.value];

  // Filter by date range
  const startStr = dateRange.value[0].format('YYYY-MM-DD');
  const endStr = dateRange.value[1].format('YYYY-MM-DD');
  data = data.filter((d) => d.date >= startStr && d.date <= endStr);

  return data;
});

// Documents summary stats
const docsSummaryStats = computed(() => {
  const data = filteredDocsData.value;
  if (data.length === 0) {
    return {
      totalFileNum: 0,
      totalDailyUpload: 0,
      totalDailyUpdate: 0,
    };
  }

  // Get latest record (first after descending sort)
  const latestRecord = data[0];
  return {
    totalFileNum: latestRecord.total_file_num || 0,
    totalDailyUpload: latestRecord.daily_upload_num || 0,
    totalDailyUpdate: latestRecord.daily_update_num || 0,
  };
});

// Load data using fetch
const loadData = async () => {
  loading.value = true;
  // 从 latest.json 获取数据日期码
  const dataDate = dataVersion.value?.dataDate || '20260413';

  try {
    // Load daily stats
    const response = await fetch(
      `/src/assets/data-display/anythingllm_daily_stats-${dataDate}.json`,
    );
    const data = await response.json();

    if (!data || data.length === 0) {
      throw new Error('数据为空');
    }

    allAnythingllmData.value = data;

    // Sort by date (descending - newest first)
    allAnythingllmData.value.sort(
      (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime(),
    );

    // Load documents stats
    const docsResponse = await fetch(
      `/src/assets/data-display/anythingllm_documents_stats-${dataDate}.json`,
    );
    const docsData = await docsResponse.json();

    if (docsData && docsData.length > 0) {
      allAnythingllmDocsData.value = docsData;
      // Sort by date (descending - newest first)
      allAnythingllmDocsData.value.sort(
        (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime(),
      );
    }
  } catch (error) {
    console.error('Error loading AnythingLLM data:', error);
  } finally {
    loading.value = false;
  }
};

// File type distribution data
const fileTypeData = computed(() => {
  const typeMap = new Map<string, { count: number; wps: number }>();

  chartData.value.forEach((item) => {
    const type = item.file_type || 'unknown';
    const existing = typeMap.get(type) || { count: 0, wps: 0 };
    existing.count += 1;
    existing.wps += item.wps_total || 0;
    typeMap.set(type, existing);
  });

  return [...typeMap.entries()]
    .map(([name, value]) => ({ name, value: value.count }))
    .toSorted((a, b) => b.value - a.value);
});

// Chart options - File Type Distribution (Rose/Nightingale Chart)
const fileTypeChartOption = computed(() => {
  // 南丁格尔玫瑰图配色方案
  const colors = [
    '#5470c6',
    '#91cc75',
    '#fac858',
    '#ee6666',
    '#73c0de',
    '#3ba272',
    '#fc8452',
    '#9a60b4',
    '#ea7ccc',
    '#ff5722',
  ];

  return {
    title: { text: '文件类型分布', left: 'center' },
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} 个 ({d}%)',
    },
    legend: {
      bottom: 10,
      type: 'scroll',
      orient: 'horizontal',
    },
    series: [
      {
        type: 'pie',
        radius: ['20%', '65%'], // 南丁格尔玫瑰图半径范围
        center: ['50%', '50%'],
        roseType: 'radius', // 关键：南丁格尔玫瑰图
        itemStyle: {
          borderRadius: 5,
          borderColor: '#fff',
          borderWidth: 2,
        },
        label: {
          show: true,
          position: 'outside',
          formatter: '{b}\n{d}%',
          fontSize: 11,
          color: '#666',
        },
        emphasis: {
          label: {
            show: true,
            fontSize: 14,
            fontWeight: 'bold',
          },
          itemStyle: {
            shadowBlur: 20,
            shadowColor: 'rgba(0, 0, 0, 0.5)',
          },
        },
        labelLine: {
          show: true,
          length: 10,
          length2: 15,
          smooth: true,
        },
        data: fileTypeData.value,
        color: colors,
      },
    ],
    grid: { bottom: 80 },
  };
});

// Get daily embed rate data
const getDailyEmbedData = () => {
  const dailyMap = new Map<
    string,
    { embedRatios: number[]; uploadNums: number[] }
  >();

  chartData.value.forEach((item) => {
    const date = item.date;
    if (!dailyMap.has(date)) {
      dailyMap.set(date, { embedRatios: [], uploadNums: [] });
    }
    const day = dailyMap.get(date);
    if (day && item.embed_ratio > 0) {
      day.embedRatios.push(item.embed_ratio);
    }
    if (day && item.upload_num > 0) {
      day.uploadNums.push(item.upload_num);
    }
  });

  return [...dailyMap.entries()]
    .map(([date, data]) => ({
      date,
      avgEmbedRate:
        data.embedRatios.length > 0
          ? data.embedRatios.reduce((a, b) => a + b, 0) /
            data.embedRatios.length
          : 0,
      totalUploads: data.uploadNums.reduce((a, b) => a + b, 0),
    }))
    .toSorted(
      (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime(),
    );
};

// Chart options - Embed Success Trend
const embedTrendChartOption = computed(() => {
  const dailyData = getDailyEmbedData();
  return {
    title: { text: '嵌入成功率趋势', left: 'center' },
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
      name: '嵌入率 (%)',
      max: 100,
    },
    series: [
      {
        name: '平均嵌入率',
        type: 'line',
        data: dailyData.map((d) => d.avgEmbedRate),
        smooth: true,
        areaStyle: { opacity: 0.3 },
        lineStyle: { width: 3 },
        itemStyle: { color: '#67c23a' },
      },
    ],
    legend: { bottom: 55 },
    grid: { bottom: 100 },
  };
});

// Disabled dates
const disabledDate = (current: dayjs.Dayjs) => {
  const dateStr = current.format('YYYY-MM-DD');
  return !availableDates.value.includes(dateStr);
};

// Table columns
const tableColumns = [
  { title: '日期', dataIndex: 'date', key: 'date', width: 110 },
  { title: '文件类型', dataIndex: 'file_type', key: 'file_type', width: 100 },
  { title: '总字数', dataIndex: 'wps_total', key: 'wps_total' },
  { title: '上传数', dataIndex: 'upload_num', key: 'upload_num' },
  { title: '数据库数', dataIndex: 'db_type_num', key: 'db_type_num' },
  {
    title: '嵌入率(%)',
    dataIndex: 'embed_ratio',
    key: 'embed_ratio',
    width: 100,
  },
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

// Docs table columns
const docsTableColumns = [
  { title: '日期', dataIndex: 'date', key: 'date', width: 110 },
  {
    title: '上传数',
    dataIndex: 'daily_upload_num',
    key: 'daily_upload_num',
  },
  {
    title: '更新数',
    dataIndex: 'daily_update_num',
    key: 'daily_update_num',
  },
  {
    title: '文档总数',
    dataIndex: 'total_file_num',
    key: 'total_file_num',
  },
];

// Docs table pagination state
const docsTablePagination = ref({
  current: 1,
  pageSize: 10,
  showSizeChanger: true,
  pageSizeOptions: ['10', '20', '50', '100'],
  showTotal: (total: number) => `共 ${total} 条`,
});

// Handle docs table change
const handleDocsTableChange = (pagination: any) => {
  docsTablePagination.value.current = pagination.current;
  docsTablePagination.value.pageSize = pagination.pageSize;
};

onMounted(async () => {
  // 先加载最新数据版本信息
  await loadLatestInfo();
  // 然后加载数据
  loadData();
});
</script>

<template>
  <Page description="文档处理和嵌入统计监控" title="AnythingLLM 每日统计">
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
                <div
                  class="text-3xl font-extrabold tracking-tight"
                  :style="{ color: item.textColor }"
                >
                  {{
                    item.format === 'percent'
                      ? `${item.value.toFixed(1)}%`
                      : item.format === 'wps'
                        ? formatWpsValue(item.value)
                        : item.value.toLocaleString()
                  }}
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

      <!-- Controls -->
      <Card class="mb-4">
        <Space wrap>
          <div class="flex items-center gap-2">
            <span>日期范围：</span>
            <DatePicker.RangePicker
              v-model:value="dateRange"
              :disabled-date="disabledDate"
              format="YYYY-MM-DD"
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
              :option="fileTypeChartOption"
              style="height: 350px"
              autoresize
            />
          </Card>
        </Col>
        <Col :span="12">
          <Card>
            <VChart
              :option="embedTrendChartOption"
              style="height: 350px"
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
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'wps_total'">
              {{ record.wps_total?.toLocaleString() }}
            </template>
            <template v-if="column.key === 'upload_num'">
              {{ record.upload_num?.toLocaleString() }}
            </template>
            <template v-if="column.key === 'db_type_num'">
              {{ record.db_type_num?.toLocaleString() }}
            </template>
            <template v-if="column.key === 'embed_ratio'">
              <Tag
                :color="
                  record.embed_ratio >= 90
                    ? 'success'
                    : record.embed_ratio >= 50
                      ? 'warning'
                      : 'error'
                "
              >
                {{ record.embed_ratio?.toFixed(1) }}%
              </Tag>
            </template>
          </template>
        </Table>
      </Card>

      <!-- Documents Stats Table -->
      <Card title="文档统计" class="mt-4">
        <Table
          :columns="docsTableColumns"
          :data-source="filteredDocsData"
          :pagination="docsTablePagination"
          row-key="id"
          size="small"
          @change="handleDocsTableChange"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'daily_upload_num'">
              {{ record.daily_upload_num?.toLocaleString() }}
            </template>
            <template v-if="column.key === 'daily_update_num'">
              {{ record.daily_update_num?.toLocaleString() }}
            </template>
            <template v-if="column.key === 'total_file_num'">
              <Tag color="blue">
                {{ record.total_file_num?.toLocaleString() }}
              </Tag>
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
</style>
