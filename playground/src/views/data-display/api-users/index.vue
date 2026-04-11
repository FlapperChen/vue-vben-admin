<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';

import { Page } from '@vben/common-ui';

import {
  Card,
  Row,
  Col,
  Table,
  Spin,
  Statistic,
  Input,
  Select,
  Space,
  Button,
  Tag,
  message,
} from 'ant-design-vue';

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
        u.userid?.toString().includes(search)
    );
  }

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
  const totalUsers = usersData.value.length;
  const totalRequests = usersData.value.reduce(
    (sum, u) => sum + (u.request_total || 0),
    0
  );
  const totalTokens = usersData.value.reduce(
    (sum, u) => sum + (u.token_used_total || 0),
    0
  );
  const avgTokensPerUser = totalUsers > 0 ? totalTokens / totalUsers : 0;
  const topUser = [...usersData.value].sort(
    (a, b) => (b.token_used_total || 0) - (a.token_used_total || 0)
  )[0];

  return {
    totalUsers,
    totalRequests,
    totalTokens,
    avgTokensPerUser,
    topUser: topUser?.username || '-',
  };
});

// Load data using fetch
const loadData = async () => {
  loading.value = true;
  try {
    const response = await fetch('/src/assets/data-display/openapi_users-260411.json');
    const data = await response.json();

    if (!data || data.length === 0) {
      throw new Error('数据为空');
    }

    usersData.value = data;
  } catch (e) {
    console.error('Error loading users data:', e);
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
};

const onRefresh = () => {
  loadData();
  message.success('数据已刷新');
};

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
      if (text >= 1000000) {
        return (text / 1000000).toFixed(2) + 'M';
      }
      if (text >= 1000) {
        return (text / 1000).toFixed(2) + 'K';
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
        return (daily / 1000).toFixed(1) + 'K';
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

onMounted(() => {
  loadData();
});
</script>

<template>
  <Page description="OpenAPI用户数据管理" title="API用户">
    <Spin :spinning="loading" tip="加载数据中...">
      <!-- Summary Cards -->
      <Row :gutter="[16, 16]" class="mb-4">
        <Col :span="6">
          <Card>
            <Statistic
              :value="summaryData.totalUsers"
              title="总用户数"
              prefix="👥"
              value-style="color: #409eff"
            />
          </Card>
        </Col>
        <Col :span="6">
          <Card>
            <Statistic
              :value="(summaryData.totalRequests / 1000).toFixed(1) + 'K'"
              title="总请求数"
              prefix="📊"
              value-style="color: #67c23a"
            />
          </Card>
        </Col>
        <Col :span="6">
          <Card>
            <Statistic
              :value="(summaryData.totalTokens / 1000000).toFixed(2) + 'M'"
              title="Token使用总量"
              prefix="💎"
              value-style="color: #e6a23c"
            />
          </Card>
        </Col>
        <Col :span="6">
          <Card>
            <Statistic
              :value="summaryData.topUser"
              title="最高Token用户"
              prefix="🏆"
              value-style="color: #f56c6c; font-size: 18px"
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
              placeholder="搜索用户ID/用户名/显示名"
              style="width: 220px"
              allow-clear
            />
          </div>

          <div class="flex items-center gap-2">
            <span>排序：</span>
            <Select v-model:value="sortField" style="width: 140px">
              <Select.Option value="request_total">按请求数</Select.Option>
              <Select.Option value="token_used_total">按Token使用量</Select.Option>
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
            pageSize: 20,
            showSizeChanger: true,
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

.ml-4 {
  margin-left: 16px;
}
</style>