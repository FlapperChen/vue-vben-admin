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
import { LineChart } from 'echarts/charts';
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
  LineChart,
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent,
  DataZoomComponent,
]);

// Data
const allGerritData = ref<any[]>([]);
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
      console.warn('Gerrit日期范围已设置:', info.dateRange);
    }
  } catch {
    console.warn('无法读取最新数据信息，使用默认范围');
  }
};

// Available dates
const availableDates = computed(() => {
  const dates = [...new Set(allGerritData.value.map((d) => d.date))];
  return dates.toSorted();
});

// Summary stats - get the latest record
const summaryStats = computed(() => {
  const data = filteredData.value;
  if (data.length === 0) {
    return {
      totalGerritComments: 0,
      totalAiComments: 0,
      aiCommentRate: 0,
      aiAcceptRate: 0,
      totalProjectBranchCount: 0,
      aiCoveredProjectBranchCount: 0,
      aiCodeReviewCoverRate: 0,
    };
  }
  // Use the first record (cumulative stats - newest first after sort)
  const latestRecord = data[0];
  return {
    totalGerritComments: latestRecord.total_gerrit_comments || 0,
    totalAiComments: latestRecord.total_ai_comments || 0,
    aiCommentRate: latestRecord.total_ai_comments_rate || 0,
    aiAcceptRate: latestRecord.total_ai_accept_rate || 0,
    totalProjectBranchCount: latestRecord.total_project_branch_count || 0,
    aiCoveredProjectBranchCount:
      latestRecord.ai_covered_project_branch_count || 0,
    aiCodeReviewCoverRate: latestRecord.total_ai_codereview_cover_rate || 0,
  };
});

// Overview items for stats cards - 优化版
const overviewItems = computed(() => [
  {
    title: '累计AI评论',
    value: summaryStats.value.totalAiComments,
    subtitle: 'AI生成评论',
    icon: 'mdi:robot',
    gradient: 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)',
    textColor: '#11998e',
  },
  {
    title: 'AI覆盖分支数',
    value: summaryStats.value.aiCoveredProjectBranchCount,
    subtitle: 'AI覆盖项目分支',
    icon: 'mdi:source-branch',
    gradient: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    textColor: '#667eea',
  },
  {
    title: 'AI代码审查覆盖率',
    value: summaryStats.value.aiCodeReviewCoverRate,
    subtitle: 'AI代码审查覆盖率',
    icon: 'mdi:chart-line',
    gradient: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
    textColor: '#f5576c',
    format: 'percent',
  },
  {
    title: 'AI接受率',
    value: summaryStats.value.aiAcceptRate,
    subtitle: 'AI评论被接受率',
    icon: 'mdi:check-decagram',
    gradient: 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)',
    textColor: '#4facfe',
    format: 'percent',
  },
]);

// Filtered data (descending - for table and stats)
const filteredData = computed(() => {
  let data = [...allGerritData.value];

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

// Load data using fetch
const loadData = async () => {
  loading.value = true;
  // 从 latest.json 获取数据日期码
  const dataDate = dataVersion.value?.dataDate || '20260413';

  try {
    const response = await fetch(
      `/src/assets/data-display/gerrit_metrics-${dataDate}.json`,
    );
    const data = await response.json();

    if (!data || data.length === 0) {
      throw new Error('数据为空');
    }

    allGerritData.value = data;

    // Sort by date (descending - newest first)
    allGerritData.value.sort(
      (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime(),
    );
  } catch (error) {
    console.error('Error loading Gerrit data:', error);
  } finally {
    loading.value = false;
  }
};

// Chart options - Daily Comments Trend
const commentsChartOption = computed(() => {
  const data = chartData.value;
  return {
    title: { text: '每日评论趋势', left: 'center' },
    tooltip: { trigger: 'axis' },
    legend: { bottom: 10, data: ['Gerrit评论', 'AI评论'] },
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
      name: '评论数',
    },
    series: [
      {
        name: 'Gerrit评论',
        type: 'line',
        data: data.map((d) => d.daily_gerrit_comments || 0),
        smooth: true,
        lineStyle: { width: 3 },
        itemStyle: { color: '#409eff' },
      },
      {
        name: 'AI评论',
        type: 'line',
        data: data.map((d) => d.daily_ai_comments || 0),
        smooth: true,
        lineStyle: { width: 3 },
        itemStyle: { color: '#e6a23c' },
      },
    ],
    grid: { bottom: 100 },
  };
});

// Chart options - AI Rate Trend
const aiRateChartOption = computed(() => {
  const data = chartData.value;
  return {
    title: { text: 'AI评论占比、接受率与覆盖率', left: 'center' },
    tooltip: { trigger: 'axis' },
    legend: {
      bottom: 10,
      data: ['AI评论占比', 'AI接受率', 'AI代码审查覆盖率'],
    },
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
      name: '百分比 (%)',
      max: 100,
    },
    series: [
      {
        name: 'AI评论占比',
        type: 'line',
        data: data.map((d) => d.daily_ai_comments_rate || 0),
        smooth: true,
        areaStyle: { opacity: 0.3 },
        lineStyle: { width: 3 },
        itemStyle: { color: '#67c23a' },
      },
      {
        name: 'AI接受率',
        type: 'line',
        data: data.map((d) => d.daily_ai_accept_rate || 0),
        smooth: true,
        areaStyle: { opacity: 0.3 },
        lineStyle: { width: 3 },
        itemStyle: { color: '#f56c6c' },
      },
      {
        name: 'AI代码审查覆盖率',
        type: 'line',
        data: data.map((d) => d.total_ai_codereview_cover_rate || 0),
        smooth: true,
        areaStyle: { opacity: 0.3 },
        lineStyle: { width: 3 },
        itemStyle: { color: '#409eff' },
      },
    ],
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
  {
    title: 'Gerrit评论',
    dataIndex: 'daily_gerrit_comments',
    key: 'daily_gerrit_comments',
  },
  { title: 'AI评论', dataIndex: 'daily_ai_comments', key: 'daily_ai_comments' },
  {
    title: 'AI评论占比(%)',
    dataIndex: 'daily_ai_comments_rate',
    key: 'daily_ai_comments_rate',
    width: 120,
  },
  {
    title: 'AI接受数',
    dataIndex: 'daily_ai_accept_comments',
    key: 'daily_ai_accept_comments',
  },
  {
    title: 'AI接受率(%)',
    dataIndex: 'daily_ai_accept_rate',
    key: 'daily_ai_accept_rate',
    width: 120,
  },
  {
    title: '总分支数',
    dataIndex: 'total_project_branch_count',
    key: 'total_project_branch_count',
  },
  {
    title: 'AI覆盖分支',
    dataIndex: 'ai_covered_project_branch_count',
    key: 'ai_covered_project_branch_count',
  },
  {
    title: 'AI覆盖率(%)',
    dataIndex: 'total_ai_codereview_cover_rate',
    key: 'total_ai_codereview_cover_rate',
    width: 120,
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

onMounted(async () => {
  // 先加载最新数据版本信息
  await loadLatestInfo();
  // 然后加载数据
  loadData();
});
</script>

<template>
  <Page description="Code Review AI 指标监控" title="Gerrit 每日统计">
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
                      ? `${item.value.toFixed(2)}%`
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
              :option="commentsChartOption"
              style="height: 350px"
              autoresize
            />
          </Card>
        </Col>
        <Col :span="12">
          <Card>
            <VChart
              :option="aiRateChartOption"
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
          row-key="date"
          size="small"
          @change="handleTableChange"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'daily_gerrit_comments'">
              {{ record.daily_gerrit_comments?.toLocaleString() }}
            </template>
            <template v-if="column.key === 'daily_ai_comments'">
              {{ record.daily_ai_comments?.toLocaleString() }}
            </template>
            <template v-if="column.key === 'daily_ai_comments_rate'">
              <Tag
                :color="
                  record.daily_ai_comments_rate > 50
                    ? 'success'
                    : record.daily_ai_comments_rate > 0
                      ? 'warning'
                      : 'default'
                "
              >
                {{ record.daily_ai_comments_rate?.toFixed(1) }}%
              </Tag>
            </template>
            <template v-if="column.key === 'daily_ai_accept_comments'">
              {{ record.daily_ai_accept_comments?.toLocaleString() }}
            </template>
            <template v-if="column.key === 'daily_ai_accept_rate'">
              <Tag
                :color="
                  record.daily_ai_accept_rate > 50
                    ? 'success'
                    : record.daily_ai_accept_rate > 0
                      ? 'warning'
                      : 'default'
                "
              >
                {{ record.daily_ai_accept_rate?.toFixed(1) }}%
              </Tag>
            </template>
            <template v-if="column.key === 'total_project_branch_count'">
              {{ record.total_project_branch_count?.toLocaleString() }}
            </template>
            <template v-if="column.key === 'ai_covered_project_branch_count'">
              {{ record.ai_covered_project_branch_count?.toLocaleString() }}
            </template>
            <template v-if="column.key === 'total_ai_codereview_cover_rate'">
              <Tag
                :color="
                  record.total_ai_codereview_cover_rate > 50
                    ? 'success'
                    : record.total_ai_codereview_cover_rate > 0
                      ? 'warning'
                      : 'default'
                "
              >
                {{ record.total_ai_codereview_cover_rate?.toFixed(2) }}%
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
