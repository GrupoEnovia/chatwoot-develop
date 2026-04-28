import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import KanbanAPIPage from './KanbanAPIPage.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/kanban-api'),
      component: SettingsWrapper,
      props: { keepAlive: false },
      children: [
        {
          path: '',
          name: 'kanban_api_docs',
          component: KanbanAPIPage,
          meta: { permissions: ['administrator', 'agent'] },
        },
      ],
    },
  ],
};
