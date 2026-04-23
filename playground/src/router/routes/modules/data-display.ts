import type { RouteRecordRaw } from 'vue-router';

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
      // AnythingLLM Stats
      {
        meta: {
          icon: 'mdi:file-document',
          title: 'AnythingLLM',
        },
        name: 'AnythingllmStats',
        path: '/data-display/anythingllm-stats',
        component: () =>
          import('#/views/data-display/anythingllm-stats/index.vue'),
      },
      // Gerrit Stats
      {
        meta: {
          icon: 'mdi:source-pull',
          title: 'Gerrit 统计',
        },
        name: 'GerritStats',
        path: '/data-display/gerrit-stats',
        component: () => import('#/views/data-display/gerrit-stats/index.vue'),
      },
    ],
  },
  // AI 故障分析
  {
    meta: {
      icon: 'mdi:alert-box-outline',
      order: 901,
      title: 'AI 故障分析',
    },
    name: 'AiFaultAnalysis',
    path: '/ai-fault-analysis',
    children: [
      // AI 故障分析首页
      {
        meta: {
          icon: 'mdi:home',
          title: '故障分析首页',
        },
        name: 'AiFaultAnalysisHome',
        path: '/ai-fault-analysis',
        component: () => import('#/views/ai-fault-analysis/index.vue'),
      },
      // AI Coredump 分析
      {
        meta: {
          icon: 'mdi:bomb',
          title: 'Coredump 分析',
        },
        name: 'AiCoredump',
        path: '/ai-fault-analysis/ai-coredump',
        component: () =>
          import('#/views/ai-fault-analysis/ai-coredump/index.vue'),
      },
      // AI 黑盒日志分析
      {
        meta: {
          icon: 'mdi:file-document-outline',
          title: '黑盒日志分析',
        },
        name: 'AiBlackbox',
        path: '/ai-fault-analysis/ai-blackbox',
        component: () =>
          import('#/views/ai-fault-analysis/ai-blackbox/index.vue'),
      },
    ],
  },
];

export default routes;
