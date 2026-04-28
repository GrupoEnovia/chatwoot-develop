import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import AiAgentIndex from './Index.vue';
import AiAgentDetail from './Detail.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ai-agents'),
      component: SettingsWrapper,
      props: {
        headerTitle: 'Agentes de IA',
        icon: 'i-lucide-bot',
        showNewButton: false,
        keepAlive: false,
      },
      children: [
        {
          path: '',
          name: 'ai_agents_index',
          component: AiAgentIndex,
          meta: { permissions: ['administrator'] },
        },
        {
          path: ':agentId',
          name: 'ai_agents_detail',
          component: AiAgentDetail,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
