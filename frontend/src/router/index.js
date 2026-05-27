import { createRouter, createWebHashHistory } from 'vue-router';

/**
 * Kognisant Core Router Configuration
 *
 * Defines the primary navigation paths for the application.
 * Codex is the default entry point, serving as the autonomous agent workspace.
 * Studio is reserved for future creative/visual logic implementation.
 */

const routes = [
  {
    path: '/',
    redirect: '/codex'
  },
  {
    path: '/codex',
    name: 'Codex',
    component: () => import('../views/codex/CodexHome.vue'),
    meta: {
      layout: 'Codex',
      title: 'Agentic Workspace'
    }
  },
  {
    path: '/studio',
    name: 'Studio',
    component: () => import('../views/studio/StudioHome.vue'),
    meta: {
      layout: 'Studio',
      title: 'Studio (Coming Soon)'
    }
  }
];

const router = createRouter({
  history: createWebHashHistory(),
  routes
});

export default router;
