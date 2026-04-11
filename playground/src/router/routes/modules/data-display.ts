import type { RouteRecordRaw } from 'vue-router';

import { $t } from '#/locales';

const routes: RouteRecordRaw[] = [
  {
    meta: {
      icon: 'mdi:chart-line',
      order: 900,
      title: '数据展示',
    },
    name: 'DataDisplay',
    path: '/data-display',
    children: [
      // Dashboard
      {
        meta: {
          icon: 'mdi:view-dashboard',
          title: '总览',
        },
        name: 'DataDashboard',
        path: '/data-display/dashboard',
        component: () => import('#/views/data-display/dashboard/index.vue'),
      },
      // GPU Stats
      {
        meta: {
          icon: 'mdi:gpu',
          title: 'GPU 统计',
        },
        name: 'GpuStats',
        path: '/data-display/gpu-stats',
        component: () => import('#/views/data-display/gpu-stats/index.vue'),
      },
      // Usage Rate
      {
        meta: {
          icon: 'mdi:chart-bar',
          title: '使用率',
        },
        name: 'UsageRate',
        path: '/data-display/usage-rate',
        component: () => import('#/views/data-display/usage-rate/index.vue'),
      },
      // VLLM Stats
      {
        meta: {
          icon: 'mdi:robot',
          title: 'VLLM 统计',
        },
        name: 'VllmStats',
        path: '/data-display/vllm-stats',
        component: () => import('#/views/data-display/vllm-stats/index.vue'),
      },
      // API Users
      {
        meta: {
          icon: 'mdi:account-group',
          title: 'API 用户',
        },
        name: 'ApiUsers',
        path: '/data-display/api-users',
        component: () => import('#/views/data-display/api-users/index.vue'),
      },
    ],
  },
];

export default routes;