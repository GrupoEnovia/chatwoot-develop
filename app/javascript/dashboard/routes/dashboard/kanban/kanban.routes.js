import { frontendURL } from '../../../helper/URLHelper';
import KanbanBoard from '../../../components/kanban/KanbanBoard.vue';
import KanbanGamification from '../../../components/kanban/KanbanGamification.vue';
import KanbanTVMode from '../../../components/kanban/KanbanTVMode.vue';
import KanbanAutomationBoard from '../../../components/kanban/KanbanAutomationBoard.vue';

const meta = {
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    name: 'kanban_board',
    component: KanbanBoard,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/kanban/gamification'),
    name: 'kanban_gamification',
    component: KanbanGamification,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/kanban/tv'),
    name: 'kanban_tv',
    component: KanbanTVMode,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/kanban/automation'),
    name: 'kanban_automation',
    component: KanbanAutomationBoard,
    meta,
  },
];
