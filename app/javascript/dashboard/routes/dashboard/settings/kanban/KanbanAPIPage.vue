<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';

const store = useStore();

const currentUser = computed(() => store.getters.getCurrentUser);
const accessToken = computed(() => currentUser.value?.access_token || '');
const accountId = computed(() => store.getters.getCurrentAccountId);

const baseUrl = computed(() => {
  const origin = window.location.origin;
  return `${origin}/api/v1/accounts/${accountId.value}`;
});

const activeTab = ref('auth');
const expandedEndpoints = ref(new Set());
const tokenVisible = ref(false);
const copied = ref(false);

function toggleEndpoint(key) {
  if (expandedEndpoints.value.has(key)) {
    expandedEndpoints.value.delete(key);
  } else {
    expandedEndpoints.value.add(key);
  }
}

function isExpanded(key) {
  return expandedEndpoints.value.has(key);
}

async function copyToken() {
  await navigator.clipboard.writeText(accessToken.value);
  copied.value = true;
  setTimeout(() => {
    copied.value = false;
  }, 2000);
}

async function copyText(text) {
  await navigator.clipboard.writeText(text);
}

const tabs = [
  { id: 'auth', label: 'Autenticação' },
  { id: 'pipelines', label: 'Funis' },
  { id: 'stages', label: 'Etapas' },
  { id: 'items', label: 'Leads / Cards' },
  { id: 'tasks', label: 'Tarefas' },
  { id: 'activities', label: 'Atividades' },
  { id: 'lost', label: 'Motivos de Perda' },
  { id: 'gamification', label: 'Gamificação' },
  { id: 'excel', label: 'Importação / Exportação' },
  { id: 'webhooks', label: 'Webhooks' },
  { id: 'errors', label: 'Erros' },
];

const METHOD_COLORS = {
  GET: 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300',
  POST: 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300',
  PATCH: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300',
  PUT: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300',
  DELETE: 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300',
};

function methodColor(m) {
  return METHOD_COLORS[m] || 'bg-slate-100 text-slate-700';
}

const ENDPOINTS = {
  pipelines: [
    {
      method: 'GET',
      path: '/kanban/pipelines',
      summary: 'Listar funis',
      description: 'Retorna todos os funis da conta com contagem de etapas.',
      params: [],
      response: `{
  "payload": [
    {
      "id": 1, "name": "Vendas", "description": "Funil principal",
      "is_active": true, "is_default": true, "position": 1,
      "stages_count": 5, "settings": {}
    }
  ]
}`,
    },
    {
      method: 'POST',
      path: '/kanban/pipelines',
      summary: 'Criar funil',
      description: 'Cria um novo funil para a conta.',
      body: `{
  "name": "Vendas B2B",
  "description": "Funil para clientes corporativos",
  "is_active": true,
  "settings": { "auto_resolve_conversation": false }
}`,
      response: `{ "payload": { "id": 2, "name": "Vendas B2B", ... } }`,
    },
    {
      method: 'GET',
      path: '/kanban/pipelines/:id',
      summary: 'Detalhar funil',
      params: [{ name: 'id', desc: 'ID do funil', required: true }],
      response: `{ "payload": { "id": 1, "name": "Vendas", ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:id',
      summary: 'Atualizar funil',
      body: `{ "name": "Novo nome", "is_active": false }`,
      response: `{ "payload": { "id": 1, "name": "Novo nome", ... } }`,
    },
    {
      method: 'DELETE',
      path: '/kanban/pipelines/:id',
      summary: 'Excluir funil',
      response: 'HTTP 200 OK (sem corpo)',
    },
  ],
  stages: [
    {
      method: 'GET',
      path: '/kanban/pipelines/:pipeline_id/stages',
      summary: 'Listar etapas de um funil',
      params: [{ name: 'pipeline_id', desc: 'ID do funil', required: true }],
      response: `{ "payload": [{ "id": 1, "name": "Prospecção", "position": 1, "color": "#6366f1", "is_won": false, "is_lost": false, "probability": 10 }] }`,
    },
    {
      method: 'POST',
      path: '/kanban/pipelines/:pipeline_id/stages',
      summary: 'Criar etapa',
      body: `{ "name": "Negociação", "color": "#f59e0b", "probability": 60 }`,
      response: `{ "payload": { "id": 3, "name": "Negociação", ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:pipeline_id/stages/:id',
      summary: 'Atualizar etapa',
      body: `{ "name": "Novo nome", "color": "#10b981", "is_won": true }`,
      response: `{ "payload": { "id": 3, "name": "Novo nome", "is_won": true, ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:pipeline_id/stages/:id/reorder',
      summary: 'Reordenar etapa',
      body: `{ "position": 2 }`,
      response: `{ "payload": { "id": 3, "position": 2, ... } }`,
    },
    {
      method: 'DELETE',
      path: '/kanban/pipelines/:pipeline_id/stages/:id',
      summary: 'Excluir etapa',
      response: 'HTTP 200 OK',
    },
  ],
  items: [
    {
      method: 'GET',
      path: '/kanban/pipelines/:pipeline_id/items',
      summary: 'Listar leads/cards',
      params: [
        { name: 'stage_id', desc: 'Filtrar por etapa' },
        { name: 'assignee_id', desc: 'Filtrar por responsável' },
        { name: 'status', desc: 'open | won | lost' },
        { name: 'temperature', desc: 'hot | warm | cold' },
        { name: 'source', desc: 'whatsapp | instagram | google_ads | ...' },
        { name: 'search', desc: 'Busca por título ou telefone' },
        { name: 'value_min / value_max', desc: 'Faixa de valor' },
        {
          name: 'created_from / created_to',
          desc: 'Intervalo de datas (ISO 8601)',
        },
      ],
      response: `{ "payload": [ { "id": 1, "title": "Empresa XYZ", "value": "15000.00", "status": "open", ... } ] }`,
    },
    {
      method: 'POST',
      path: '/kanban/pipelines/:pipeline_id/items',
      summary: 'Criar lead',
      body: `{
  "stage_id": 2,
  "title": "Empresa XYZ",
  "value": 15000,
  "contact_phone": "+5511999999999",
  "cpf": "000.000.000-00",
  "gender": "male",
  "birth_date": "1990-01-01",
  "address": "Rua Exemplo, 123 - SP",
  "assignee_id": 5,
  "source": "whatsapp",
  "temperature": "hot",
  "probability": 80,
  "expected_close_date": "2026-12-31",
  "tags": ["vip", "urgente"]
}`,
      response: `{ "payload": { "id": 42, "title": "Empresa XYZ", "status": "open", ... } }`,
    },
    {
      method: 'GET',
      path: '/kanban/pipelines/:pipeline_id/items/:id',
      summary: 'Detalhar lead',
      response: `{ "payload": { "id": 42, "title": "Empresa XYZ", "value": "15000.00", "cpf": "000.000.000-00", "assignee": { "id": 5, "name": "João", "avatar_url": "..." }, ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:pipeline_id/items/:id',
      summary: 'Atualizar lead',
      body: `{ "title": "Novo Nome", "value": 20000, "temperature": "warm" }`,
      response: `{ "payload": { "id": 42, ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:pipeline_id/items/:id/move',
      summary: 'Mover lead para outra etapa',
      body: `{ "stage_id": 3, "position": 1 }`,
      response: `{ "payload": { "id": 42, "stage_id": 3, ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:pipeline_id/items/:id/transfer',
      summary: 'Transferir lead para outro funil',
      body: `{ "target_pipeline_id": 2, "stage_id": 7 }`,
      response: `{ "payload": { "id": 42, "pipeline_id": 2, "stage_id": 7, ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:pipeline_id/items/:id/won',
      summary: 'Marcar lead como Ganho 🏆',
      description:
        'Move o lead para a etapa de ganho (se configurada) e registra won_at.',
      response: `{ "payload": { "id": 42, "status": "won", "won_at": 1745000000, ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:pipeline_id/items/:id/lost',
      summary: 'Marcar lead como Perdido',
      body: `{ "lost_reason_id": 3 }`,
      response: `{ "payload": { "id": 42, "status": "lost", "lost_at": 1745000000, ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:pipeline_id/items/:id/reopen',
      summary: 'Reabrir lead',
      description: 'Remove won_at e lost_at, retorna status para open.',
      response: `{ "payload": { "id": 42, "status": "open", ... } }`,
    },
    {
      method: 'DELETE',
      path: '/kanban/pipelines/:pipeline_id/items/:id',
      summary: 'Excluir lead',
      response: 'HTTP 200 OK',
    },
  ],
  tasks: [
    {
      method: 'GET',
      path: '/kanban/pipelines/:pipeline_id/items/:item_id/tasks',
      summary: 'Listar tarefas de um lead',
      response: `{ "payload": [{ "id": 1, "title": "Ligar para cliente", "priority": 1, "completed_at": null, ... }] }`,
    },
    {
      method: 'POST',
      path: '/kanban/pipelines/:pipeline_id/items/:item_id/tasks',
      summary: 'Criar tarefa',
      body: `{
  "title": "Enviar proposta",
  "description": "Enviar via e-mail com PDF",
  "priority": 2,
  "due_date": "2026-12-01",
  "assignee_id": 5,
  "is_recurring": false
}`,
      response: `{ "payload": { "id": 10, "title": "Enviar proposta", ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:pipeline_id/items/:item_id/tasks/:id',
      summary: 'Atualizar tarefa',
      body: `{ "title": "Novo título", "priority": 0 }`,
      response: `{ "payload": { "id": 10, ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:pipeline_id/items/:item_id/tasks/:id/complete',
      summary: 'Concluir tarefa',
      response: `{ "payload": { "id": 10, "completed_at": 1745000000, ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/pipelines/:pipeline_id/items/:item_id/tasks/:id/reopen',
      summary: 'Reabrir tarefa',
      response: `{ "payload": { "id": 10, "completed_at": null, ... } }`,
    },
    {
      method: 'DELETE',
      path: '/kanban/pipelines/:pipeline_id/items/:item_id/tasks/:id',
      summary: 'Excluir tarefa',
      response: 'HTTP 200 OK',
    },
  ],
  activities: [
    {
      method: 'GET',
      path: '/kanban/pipelines/:pipeline_id/items/:item_id/activities',
      summary: 'Listar atividades / timeline de um lead',
      params: [
        {
          name: 'action_type',
          desc: 'Filtrar por tipo: created | moved | won | lost | assigned | note_added | task_created | ...',
        },
        { name: 'start_date', desc: 'Data inicial (ISO 8601)' },
        { name: 'end_date', desc: 'Data final (ISO 8601)' },
      ],
      response: `{
  "payload": [
    {
      "id": 1, "action_type": "moved",
      "metadata": { "from_stage_name": "Prospecção", "to_stage_name": "Negociação" },
      "author": { "id": 5, "name": "João", "avatar_url": "..." },
      "created_at": 1745000000
    }
  ]
}`,
    },
  ],
  lost: [
    {
      method: 'GET',
      path: '/kanban/lost_reasons',
      summary: 'Listar motivos de perda',
      response: `{ "payload": [{ "id": 1, "name": "Preço alto", "active": true, "position": 1 }] }`,
    },
    {
      method: 'POST',
      path: '/kanban/lost_reasons',
      summary: 'Criar motivo de perda',
      body: `{ "name": "Concorrente", "active": true }`,
      response: `{ "payload": { "id": 2, "name": "Concorrente", ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/lost_reasons/:id',
      summary: 'Atualizar motivo',
      body: `{ "name": "Novo nome", "active": false }`,
      response: `{ "payload": { "id": 2, ... } }`,
    },
    {
      method: 'DELETE',
      path: '/kanban/lost_reasons/:id',
      summary: 'Excluir motivo',
      response: 'HTTP 200 OK',
    },
  ],
  gamification: [
    {
      method: 'GET',
      path: '/kanban/gamification/rankings',
      summary: 'Ranking de agentes',
      params: [
        { name: 'period', desc: 'today | week | month | year | custom' },
        {
          name: 'start_date / end_date',
          desc: 'Período customizado (ISO 8601)',
        },
      ],
      response: `{
  "payload": [
    {
      "rank": 1,
      "agent": { "id": 5, "name": "Maria", "avatar_url": "..." },
      "stats": { "won": 12, "value": 85000, "conversion_rate": 40, "max_deal_value": 15000 }
    }
  ]
}`,
    },
    {
      method: 'GET',
      path: '/kanban/gamification/overview',
      summary: 'Visão geral do período',
      params: [{ name: 'period', desc: 'today | week | month | year' }],
      response: `{ "payload": { "total_won": 45, "total_value": 320000, "total_open": 120, ... } }`,
    },
    {
      method: 'GET',
      path: '/kanban/gamification/recent_wins',
      summary: 'Últimas vitórias',
      response: `{ "payload": [ { "item": {...}, "agent": {...}, "won_at": 1745000000 } ] }`,
    },
    {
      method: 'GET',
      path: '/kanban/gamification/global_goals',
      summary: 'Metas globais da equipe',
      response: `{ "payload": { "team_goal_value": 500000, "team_goal_won": 100 } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/gamification/global_goals',
      summary: 'Atualizar metas globais',
      body: `{ "team_goal_value": 600000, "team_goal_won": 120 }`,
      response: `{ "payload": { "team_goal_value": 600000, "team_goal_won": 120 } }`,
    },
    {
      method: 'GET',
      path: '/kanban/goals',
      summary: 'Metas individuais do mês',
      params: [
        { name: 'year', desc: 'Ano (ex: 2026)', required: true },
        { name: 'month', desc: 'Mês 1-12', required: true },
      ],
      response: `{ "payload": [{ "id": 1, "assignee_id": 5, "year": 2026, "month": 4, "target_value": 50000, "target_won": 10 }] }`,
    },
    {
      method: 'POST',
      path: '/kanban/goals/upsert',
      summary: 'Criar ou atualizar meta individual',
      body: `{ "assignee_id": 5, "year": 2026, "month": 4, "target_value": 50000, "target_won": 10 }`,
      response: `{ "payload": { "id": 1, "assignee_id": 5, "target_value": 50000, ... } }`,
    },
    {
      method: 'GET',
      path: '/kanban/badges',
      summary: 'Listar badges',
      response: `{ "payload": [{ "id": 1, "name": "Closer", "icon": "🏆", "condition_type": "won_gte", "condition_value": 10, "active": true }] }`,
    },
    {
      method: 'POST',
      path: '/kanban/badges',
      summary: 'Criar badge (admin)',
      body: `{ "name": "Top Vendedor", "icon": "⭐", "color": "#f59e0b", "condition_type": "value_gte", "condition_value": 100000, "active": true }`,
      response: `{ "payload": { "id": 5, ... } }`,
    },
  ],
  excel: [
    {
      method: 'GET',
      path: '/kanban/export/items',
      summary: 'Exportar leads para Excel (.xlsx)',
      params: [
        { name: 'pipeline_id', desc: 'Filtrar por funil' },
        { name: 'stage_id', desc: 'Filtrar por etapa' },
        { name: 'status', desc: 'open | won | lost' },
        { name: 'created_from / created_to', desc: 'Intervalo de datas' },
      ],
      description:
        'Retorna arquivo .xlsx com todos os campos dos leads filtrados. O token deve ser enviado como query param `api_access_token` ou no header.',
      response: 'Arquivo binário .xlsx (Content-Disposition: attachment)',
    },
    {
      method: 'GET',
      path: '/kanban/export/tasks',
      summary: 'Exportar tarefas para Excel',
      params: [{ name: 'pipeline_id', desc: 'Filtrar por funil' }],
      response: 'Arquivo binário .xlsx',
    },
    {
      method: 'GET',
      path: '/kanban/export/pipelines',
      summary: 'Exportar funis e etapas para Excel',
      response: 'Arquivo binário .xlsx (2 abas: Funis, Etapas)',
    },
    {
      method: 'GET',
      path: '/kanban/export/full',
      summary: 'Exportação completa (leads + tarefas + funis + etapas)',
      response: 'Arquivo binário .xlsx (4 abas)',
    },
    {
      method: 'GET',
      path: '/kanban/import/template',
      summary: 'Baixar template de importação',
      description:
        'Retorna planilha .xlsx modelo com cabeçalhos corretos e linha de exemplo.',
      response: 'Arquivo binário .xlsx',
    },
    {
      method: 'POST',
      path: '/kanban/import/items',
      summary: 'Importar leads via planilha Excel',
      description:
        'Envie um arquivo .xlsx ou .csv (multipart/form-data). Colunas obrigatórias: pipeline_name, stage_name, title. Se a coluna "id" estiver preenchida, atualiza o lead existente.',
      body: `Content-Type: multipart/form-data
Campo: file = <arquivo.xlsx>`,
      response: `{
  "payload": {
    "created": 15,
    "updated": 3,
    "total": 18,
    "errors": [
      { "row": 5, "message": "Funil 'Vendas X' não encontrado" }
    ]
  }
}`,
    },
  ],
  webhooks: [
    {
      method: 'GET',
      path: '/kanban/webhooks',
      summary: 'Listar webhooks',
      response: `{ "payload": [{ "id": 1, "url": "https://...", "events": ["kanban.item.won"], "active": true }] }`,
    },
    {
      method: 'POST',
      path: '/kanban/webhooks',
      summary: 'Criar webhook',
      body: `{
  "url": "https://n8n.example.com/webhook/kanban",
  "events": ["kanban.item.won", "kanban.item.stage_changed"],
  "pipeline_id": 1,
  "active": true
}`,
      description:
        'Eventos disponíveis: kanban.item.created, kanban.item.updated, kanban.item.deleted, kanban.item.stage_changed, kanban.item.won, kanban.item.lost',
      response: `{ "payload": { "id": 3, ... } }`,
    },
    {
      method: 'PATCH',
      path: '/kanban/webhooks/:id',
      summary: 'Atualizar webhook',
      body: `{ "active": false }`,
      response: `{ "payload": { "id": 3, "active": false, ... } }`,
    },
    {
      method: 'DELETE',
      path: '/kanban/webhooks/:id',
      summary: 'Excluir webhook',
      response: 'HTTP 200 OK',
    },
  ],
};

const globalItems = {
  method: 'GET',
  path: '/kanban/items',
  summary: 'Buscar leads por conversa (global)',
  params: [
    {
      name: 'conversation_id',
      desc: 'ID da conversa no Chatwoot',
      required: true,
    },
  ],
  response: `{ "payload": [{ "id": 42, "title": "Lead da Conversa", "pipeline_id": 1, ... }] }`,
};
</script>

<!-- eslint-disable vue/no-bare-strings-in-template, vue/max-attributes-per-line, prettier/prettier -->
<template>
  <div class="w-full max-w-5xl">
    <!-- Header -->
    <div class="mb-8">
      <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100">
        API do Kanban CRM
      </h1>
      <p class="text-slate-500 dark:text-slate-400 mt-1 text-sm">
        Documentação completa da API REST do Kanban. Todos os endpoints seguem o
        padrão de autenticação do Chatwoot.
      </p>
    </div>

    <!-- Base URL card -->
    <div
      class="rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/50 p-4 mb-6 flex items-center gap-3 flex-wrap"
    >
      <span class="text-xs font-semibold uppercase tracking-wide text-slate-400">Base URL</span>
      <code
        class="flex-1 font-mono text-sm text-indigo-600 dark:text-indigo-400 break-all"
        >{{ baseUrl }}/kanban</code>
      <button
        class="text-xs text-slate-500 hover:text-indigo-600 flex items-center gap-1"
        @click="copyText(`${baseUrl}/kanban`)"
      >
        <span class="i-lucide-copy size-3.5" /> Copiar
      </button>
    </div>

    <!-- Tabs -->
    <div
      class="flex flex-wrap gap-1.5 mb-6 border-b border-slate-200 dark:border-slate-700 pb-3"
    >
      <button
        v-for="tab in tabs"
        :key="tab.id"
        class="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
        :class="
          activeTab === tab.id
            ? 'bg-indigo-600 text-white'
            : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700'
        "
        @click="activeTab = tab.id"
      >
        {{ tab.label }}
      </button>
    </div>

    <!-- AUTH TAB -->
    <div v-if="activeTab === 'auth'" class="space-y-5">
      <div class="rounded-xl border border-slate-200 dark:border-slate-700 p-5">
        <h2
          class="text-base font-semibold text-slate-800 dark:text-slate-100 mb-3"
        >
          Como autenticar
        </h2>
        <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
          Todos os endpoints exigem autenticação via token de acesso. Use o
          header
          <code
            class="bg-slate-100 dark:bg-slate-700 px-1.5 py-0.5 rounded text-xs"
            >api_access_token</code>
          em todas as requisições, ou envie como query parameter.
        </p>

        <div class="rounded-lg bg-slate-900 p-4 mb-4">
          <p class="text-slate-400 text-xs mb-2"># Via header (recomendado)</p>
          <code class="text-green-400 text-sm font-mono">curl -H "api_access_token: SEU_TOKEN"
            {{ baseUrl }}/kanban/pipelines</code>
          <p class="text-slate-400 text-xs mt-3 mb-2"># Via query parameter</p>
          <code class="text-green-400 text-sm font-mono">{{ baseUrl }}/kanban/pipelines?api_access_token=SEU_TOKEN</code>
        </div>

        <div
          class="rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 p-3 text-xs text-amber-700 dark:text-amber-400 mb-5"
        >
          ⚠️ O token de acesso identifica o usuário. Mantenha-o em segredo. Use
          via header em produção para evitar que o token apareça em logs do
          servidor.
        </div>

        <h3
          class="text-sm font-semibold text-slate-700 dark:text-slate-200 mb-2"
        >
          Seu Token de Acesso
        </h3>
        <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
          Este é o mesmo token usado em todo o Chatwoot. Você pode gerenciá-lo
          em <strong>Configurações → Perfil</strong>.
        </p>
        <div
          class="flex items-center gap-2 p-3 bg-slate-100 dark:bg-slate-800 rounded-lg"
        >
          <code
            class="flex-1 font-mono text-xs text-slate-700 dark:text-slate-300 truncate"
          >
            {{
              tokenVisible
                ? accessToken
                : accessToken.slice(0, 8) + '••••••••••••••••••••••••'
            }}
          </code>
          <button
            class="shrink-0 text-slate-500 hover:text-indigo-600 text-xs flex items-center gap-1"
            @click="tokenVisible = !tokenVisible"
          >
            <span
              :class="tokenVisible ? 'i-lucide-eye-off' : 'i-lucide-eye'"
              class="size-3.5"
            />
            {{ tokenVisible ? 'Ocultar' : 'Mostrar' }}
          </button>
          <button
            class="shrink-0 text-slate-500 hover:text-indigo-600 text-xs flex items-center gap-1"
            @click="copyToken"
          >
            <span class="i-lucide-copy size-3.5" />
            {{ copied ? 'Copiado!' : 'Copiar' }}
          </button>
        </div>
      </div>

      <div class="rounded-xl border border-slate-200 dark:border-slate-700 p-5">
        <h2
          class="text-base font-semibold text-slate-800 dark:text-slate-100 mb-3"
        >
          Formato das respostas
        </h2>
        <p class="text-sm text-slate-600 dark:text-slate-400 mb-3">
          Todas as respostas são JSON com envelope
          <code class="bg-slate-100 dark:bg-slate-700 px-1 rounded text-xs">payload</code>.
        </p>
        <div
          class="rounded-lg bg-slate-900 p-4 text-sm font-mono text-green-400"
        >
          <span class="text-slate-400"># Sucesso</span><br />
          {{ '{ "payload": { ... } }' }}<br /><br />
          <span class="text-slate-400"># Lista</span><br />
          {{ '{ "payload": [ ... ] }' }}<br /><br />
          <span class="text-slate-400"># Erro</span><br />
          {{ '{ "error": "mensagem" }' }}
        </div>
      </div>

      <div class="rounded-xl border border-slate-200 dark:border-slate-700 p-5">
        <h2
          class="text-base font-semibold text-slate-800 dark:text-slate-100 mb-3"
        >
          Scoping por conta
        </h2>
        <p class="text-sm text-slate-600 dark:text-slate-400">
          Todos os endpoints são escopados pela conta. O
          <code class="bg-slate-100 dark:bg-slate-700 px-1 rounded text-xs">account_id</code>
          no URL é <strong>{{ accountId }}</strong> para sua conta atual. Um
          token só acessa dados da conta à qual pertence.
        </p>
      </div>
    </div>

    <!-- ERRORS TAB -->
    <div v-else-if="activeTab === 'errors'" class="space-y-4">
      <div class="rounded-xl border border-slate-200 dark:border-slate-700 p-5">
        <h2
          class="text-base font-semibold text-slate-800 dark:text-slate-100 mb-4"
        >
          Códigos de status HTTP
        </h2>
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-slate-200 dark:border-slate-700">
              <th class="text-left py-2 pr-4 text-slate-500 font-medium">
                Status
              </th>
              <th class="text-left py-2 text-slate-500 font-medium">
                Significado
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 dark:divide-slate-700/50">
            <tr
              v-for="row in [
                ['200 OK', 'Sucesso — operação realizada'],
                ['201 Created', 'Recurso criado com sucesso'],
                ['400 Bad Request', 'Parâmetros inválidos ou ausentes'],
                ['401 Unauthorized', 'Token ausente ou inválido'],
                [
                  '403 Forbidden',
                  'Sem permissão para esta ação (ex: admin required)',
                ],
                [
                  '404 Not Found',
                  'Recurso não encontrado (verificar IDs e account_id)',
                ],
                [
                  '422 Unprocessable Entity',
                  'Validação falhou — veja o campo errors na resposta',
                ],
                [
                  '500 Internal Server Error',
                  'Erro interno — contacte o suporte',
                ],
              ]"
              :key="row[0]"
            >
              <td
                class="py-2 pr-4 font-mono text-xs text-slate-600 dark:text-slate-300"
              >
                {{ row[0] }}
              </td>
              <td class="py-2 text-slate-600 dark:text-slate-400 text-xs">
                {{ row[1] }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ENDPOINTS TABS -->
    <div v-else class="space-y-2">
      <div
        v-for="(ep, idx) in ENDPOINTS[activeTab] || []"
        :key="idx"
        class="rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden"
      >
        <!-- Endpoint header row -->
        <button
          class="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors"
          @click="toggleEndpoint(`${activeTab}-${idx}`)"
        >
          <span
            class="shrink-0 inline-flex items-center justify-center rounded px-2 py-0.5 text-xs font-bold font-mono min-w-[52px]"
            :class="methodColor(ep.method)"
            >{{ ep.method }}</span>
          <code
            class="flex-1 text-sm text-slate-700 dark:text-slate-200 font-mono truncate"
            >{{ ep.path }}</code>
          <span class="shrink-0 text-xs text-slate-400 hidden sm:block">{{
            ep.summary
          }}</span>
          <span
            class="shrink-0 size-4 transition-transform text-slate-400"
            :class="[
              isExpanded(`${activeTab}-${idx}`)
                ? 'i-lucide-chevron-up'
                : 'i-lucide-chevron-down',
            ]"
          />
        </button>

        <!-- Expanded details -->
        <div
          v-if="isExpanded(`${activeTab}-${idx}`)"
          class="border-t border-slate-200 dark:border-slate-700 px-4 py-4 space-y-4 bg-white dark:bg-slate-900/30"
        >
          <div
            v-if="ep.description"
            class="text-sm text-slate-600 dark:text-slate-400"
          >
            {{ ep.description }}
          </div>

          <div v-if="ep.params?.length">
            <p
              class="text-xs font-semibold uppercase tracking-wide text-slate-400 mb-2"
            >
              Parâmetros
            </p>
            <table class="w-full text-xs">
              <tbody class="divide-y divide-slate-100 dark:divide-slate-700/50">
                <tr v-for="p in ep.params" :key="p.name">
                  <td
                    class="py-1.5 pr-3 font-mono text-indigo-600 dark:text-indigo-400 whitespace-nowrap"
                  >
                    {{ p.name }}
                  </td>
                  <td class="py-1.5 pr-3">
                    <span v-if="p.required" class="text-red-500 text-xs">obrigatório</span>
                    <span v-else class="text-slate-400 text-xs">opcional</span>
                  </td>
                  <td class="py-1.5 text-slate-500 dark:text-slate-400">
                    {{ p.desc }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div v-if="ep.body">
            <p
              class="text-xs font-semibold uppercase tracking-wide text-slate-400 mb-2"
            >
              Body (JSON)
            </p>
            <div class="relative">
              <pre
                class="rounded-lg bg-slate-900 p-3 text-xs text-green-400 font-mono overflow-x-auto"
                >{{ ep.body }}</pre>
              <button
                class="absolute top-2 right-2 text-slate-500 hover:text-slate-300"
                @click="copyText(ep.body)"
              >
                <span class="i-lucide-copy size-3.5" />
              </button>
            </div>
          </div>

          <div v-if="ep.response">
            <p
              class="text-xs font-semibold uppercase tracking-wide text-slate-400 mb-2"
            >
              Resposta
            </p>
            <pre
              class="rounded-lg bg-slate-900 p-3 text-xs text-sky-400 font-mono overflow-x-auto"
              >{{ ep.response }}</pre>
          </div>

          <div class="flex items-center gap-2 pt-1">
            <span class="text-xs text-slate-400">URL completa:</span>
            <code class="text-xs font-mono text-slate-500 dark:text-slate-400">{{ baseUrl }}{{ ep.path }}</code>
            <button
              class="text-slate-400 hover:text-indigo-600"
              @click="copyText(`${baseUrl}${ep.path}`)"
            >
              <span class="i-lucide-copy size-3" />
            </button>
          </div>
        </div>
      </div>

      <!-- Global items endpoint shown under items tab -->
      <div
        v-if="activeTab === 'items'"
        class="rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden"
      >
        <button
          class="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-slate-50 dark:hover:bg-slate-800/50"
          @click="toggleEndpoint('global-items')"
        >
          <span
            class="shrink-0 inline-flex items-center justify-center rounded px-2 py-0.5 text-xs font-bold font-mono min-w-[52px]"
            :class="methodColor('GET')"
            >GET</span>
          <code
            class="flex-1 text-sm text-slate-700 dark:text-slate-200 font-mono"
            >/kanban/items</code>
          <span class="shrink-0 text-xs text-slate-400 hidden sm:block">{{
            globalItems.summary
          }}</span>
          <span
            class="shrink-0 size-4"
            :class="
              isExpanded('global-items')
                ? 'i-lucide-chevron-up'
                : 'i-lucide-chevron-down'
            "
          />
        </button>
        <div
          v-if="isExpanded('global-items')"
          class="border-t border-slate-200 dark:border-slate-700 px-4 py-4 space-y-4 bg-white dark:bg-slate-900/30"
        >
          <table class="w-full text-xs">
            <tbody>
              <tr v-for="p in globalItems.params" :key="p.name">
                <td
                  class="py-1.5 pr-3 font-mono text-indigo-600 dark:text-indigo-400"
                >
                  {{ p.name }}
                </td>
                <td class="py-1.5 pr-3 text-red-500">obrigatório</td>
                <td class="py-1.5 text-slate-500">{{ p.desc }}</td>
              </tr>
            </tbody>
          </table>
          <pre
            class="rounded-lg bg-slate-900 p-3 text-xs text-sky-400 font-mono overflow-x-auto"
            >{{ globalItems.response }}</pre>
        </div>
      </div>

      <div
        v-if="!ENDPOINTS[activeTab]?.length"
        class="text-center py-12 text-slate-400 text-sm"
      >
        Nenhum endpoint nesta seção.
      </div>
    </div>
  </div>
</template>
