<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { VbenIcon } from '@vben-core/shadcn-ui';

import {
  Button,
  Card,
  Col,
  Input,
  message,
  Row,
  Select,
  Space,
  Spin,
  Table,
  Tag,
} from 'ant-design-vue';

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
const isValidUser = (username: string, displayname: null | string) => {
  if (!username) return false;
  const lower = username.toLowerCase();
  if (excludedUsernames.some((u) => lower.includes(u))) return false;
  // Must have Chinese display name or valid username
  if (displayname && /[\u4E00-\u9FA5]/.test(displayname)) return true;
  return !lower.includes('deleted');
};

// Data
const usersData = ref<any[]>([]);
const loading = ref(false);

// Filters
const searchText = ref('');
const sortField = ref<string>('request_total');
const sortOrder = ref<'ascend' | 'descend'>('descend');

// Filtered and sorted data
const filteredData = computed(() => {
  let data = [...usersData.value];

  // Search filter
  if (searchText.value) {
    const search = searchText.value.toLowerCase();
    data = data.filter(
      (u) =>
        u.username?.toLowerCase().includes(search) ||
        u.displayname?.toLowerCase().includes(search) ||
        u.userid?.toString().includes(search),
    );
  }

  // Filter invalid users
  data = data.filter((u) => isValidUser(u.username, u.displayname));

  // Sort
  data.sort((a, b) => {
    let aVal = a[sortField.value];
    let bVal = b[sortField.value];

    // Handle string sorting
    if (typeof aVal === 'string') {
      aVal = aVal?.toLowerCase() || '';
      bVal = bVal?.toLowerCase() || '';
    }

    if (sortOrder.value === 'ascend') {
      return aVal > bVal ? 1 : -1;
    } else {
      return aVal < bVal ? 1 : -1;
    }
  });

  return data;
});

// Summary stats
const summaryData = computed(() => {
  // Use filtered data (with user filter applied)
  const data = filteredData.value;
  const totalUsers = data.length;
  const totalRequests = data.reduce(
    (sum, u) => sum + (u.request_total || 0),
    0,
  );
  const totalTokens = data.reduce(
    (sum, u) => sum + (u.token_used_total || 0),
    0,
  );
  const avgTokensPerUser = totalUsers > 0 ? totalTokens / totalUsers : 0;
  const topUser = [...data].toSorted(
    (a, b) => (b.token_used_total || 0) - (a.token_used_total || 0),
  )[0];

  return {
    totalUsers,
    totalRequests,
    totalTokens,
    avgTokensPerUser,
    topUser: topUser?.username || '-',
  };
});

// Overview items for stats cards - 优化版
const overviewItems = computed(() => [
  {
    title: '总用户数',
    value: summaryData.value.totalUsers,
    subtitle: '注册用户总数',
    icon: 'mdi:account-group',
    gradient: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    textColor: '#667eea',
  },
  {
    title: 'API请求',
    value: summaryData.value.totalRequests,
    subtitle: '累计API调用次数',
    icon: 'mdi:api',
    gradient: 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)',
    textColor: '#11998e',
    format: 'K',
  },
  {
    title: 'Token消耗',
    value: summaryData.value.totalTokens,
    subtitle: 'Token使用总量',
    icon: 'mdi:coin',
    gradient: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
    textColor: '#f5576c',
    format: 'M',
  },
  {
    title: 'Top用户',
    value: summaryData.value.topUser,
    subtitle: 'Token消耗最高',
    icon: 'mdi:trophy',
    gradient: 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)',
    textColor: '#4facfe',
    format: 'text',
  },
]);

// 数据版本信息
const dataVersion = ref<any>(null);

// 加载最新数据版本信息
const loadLatestInfo = async () => {
  try {
    const res = await fetch('/src/assets/data-display/latest.json');
    const info = await res.json();
    dataVersion.value = info;
    console.warn('API用户数据日期:', info.dateRange);
  } catch {
    console.warn('无法读取最新数据信息');
  }
};

// Load data using fetch
const loadData = async () => {
  loading.value = true;
  // 从 latest.json 获取数据日期码
  const dataDate = dataVersion.value?.dataDate || '20260411';

  try {
    const response = await fetch(
      `/src/assets/data-display/openapi_users-${dataDate}.json`,
    );
    const data = await response.json();

    if (!data || data.length === 0) {
      throw new Error('数据为空');
    }

    usersData.value = data;
  } catch (error) {
    console.error('Error loading users data:', error);
  } finally {
    loading.value = false;
  }
};

// Handle table change
const handleTableChange = (pagination: any, filters: any, sorter: any) => {
  if (sorter.field) {
    sortField.value = sorter.field;
    sortOrder.value = sorter.order;
  }
  tablePagination.value.current = pagination.current;
  tablePagination.value.pageSize = pagination.pageSize;
};

const onRefresh = () => {
  loadData();
  message.success('数据已刷新');
};

// Table pagination state
const tablePagination = ref({
  current: 1,
  pageSize: 20,
});

// Format created_at
const formatDate = (dateStr: string) => {
  if (!dateStr) return '-';
  return dateStr.split('T')[0];
};

// Table columns
const tableColumns = [
  {
    title: '用户ID',
    dataIndex: 'userid',
    key: 'userid',
    width: 80,
    sorter: true,
  },
  {
    title: '用户名',
    dataIndex: 'username',
    key: 'username',
    width: 150,
    sorter: true,
  },
  {
    title: '显示名称',
    dataIndex: 'displayname',
    key: 'displayname',
    width: 120,
    customRender: ({ text }: { text: string }) => text || '-',
  },
  {
    title: '总请求数',
    dataIndex: 'request_total',
    key: 'request_total',
    width: 120,
    sorter: true,
    customRender: ({ text }: { text: number }) => text?.toLocaleString() || 0,
  },
  {
    title: 'Token使用量',
    dataIndex: 'token_used_total',
    key: 'token_used_total',
    width: 150,
    sorter: true,
    customRender: ({ text }: { text: number }) => {
      if (text >= 1_000_000) {
        return `${(text / 1_000_000).toFixed(2)}M`;
      }
      if (text >= 1000) {
        return `${(text / 1000).toFixed(2)}K`;
      }
      return text?.toLocaleString() || 0;
    },
  },
  {
    title: '日均Token',
    key: 'daily_avg',
    width: 120,
    customRender: ({ record }: { record: any }) => {
      const daily = (record.token_used_total || 0) / 30;
      if (daily >= 1000) {
        return `${(daily / 1000).toFixed(1)}K`;
      }
      return daily.toFixed(0);
    },
  },
  {
    title: '创建时间',
    dataIndex: 'created_at',
    key: 'created_at',
    width: 120,
    sorter: true,
    customRender: ({ text }: { text: string }) => formatDate(text),
  },
  {
    title: '最后更新',
    dataIndex: 'updated_at',
    key: 'updated_at',
    width: 120,
    customRender: ({ text }: { text: string }) => formatDate(text),
  },
];

onMounted(async () => {
  // 先加载最新数据版本信息
  await loadLatestInfo();
  // 然后加载数据
  loadData();
});
</script>

<template>
  <Page description="OpenAPI用户数据管理" title="API用户">
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
                    item.format === 'K'
                      ? `${(item.value / 1000).toFixed(1)}K`
                      : item.format === 'M'
                        ? `${(item.value / 1000000).toFixed(2)}M`
                        : item.value
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

      <!-- Filters -->
      <Card class="mb-4">
        <Space wrap>
          <div class="flex items-center gap-2">
            <span>搜索：</span>
            <Input
              v-model:value="searchText"
              placeholder="搜索用户ID/用户名/显示名"
              style="width: 220px"
              allow-clear
            />
          </div>

          <div class="flex items-center gap-2">
            <span>排序：</span>
            <Select v-model:value="sortField" style="width: 140px">
              <Select.Option value="request_total">按请求数</Select.Option>
              <Select.Option value="token_used_total">
                按Token使用量
              </Select.Option>
              <Select.Option value="userid">按用户ID</Select.Option>
              <Select.Option value="created_at">按创建时间</Select.Option>
            </Select>
            <Select v-model:value="sortOrder" style="width: 100px">
              <Select.Option value="descend">降序</Select.Option>
              <Select.Option value="ascend">升序</Select.Option>
            </Select>
          </div>

          <Button type="primary" @click="onRefresh">刷新数据</Button>

          <Tag color="blue" class="ml-4">
            共 {{ filteredData.length }} 条记录
          </Tag>
        </Space>
      </Card>

      <!-- Data Table -->
      <Card title="用户列表">
        <Table
          :columns="tableColumns"
          :data-source="filteredData"
          :pagination="{
            current: tablePagination.current,
            pageSize: tablePagination.pageSize,
            showSizeChanger: true,
            pageSizeOptions: ['10', '20', '50', '100'],
            showQuickJumper: true,
            showTotal: (total: number) => `共 ${total} 条`,
          }"
          :row-key="(record: any) => record.userid"
          :scroll="{ x: 1200 }"
          size="middle"
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

.mb-5 {
  margin-bottom: 20px;
}

.ml-4 {
  margin-left: 16px;
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
