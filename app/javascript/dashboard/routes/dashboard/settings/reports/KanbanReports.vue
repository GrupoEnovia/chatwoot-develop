<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore } from 'vuex';
import { Doughnut } from 'vue-chartjs';
import { Chart as ChartJS, ArcElement, Title, Tooltip, Legend } from 'chart.js';

ChartJS.register(ArcElement, Title, Tooltip, Legend);

const store = useStore();

// ── Filters ───────────────────────────────────────────────────────────────────
const PERIODS = [
  { value: 'this_month', label: 'Este mês' },
  { value: 'last_month', label: 'Último mês' },
  { value: 'this_quarter', label: 'Este trimestre' },
  { value: 'this_year', label: 'Este ano' },
  { value: 'custom', label: 'Personalizado' },
];
const filterPeriod = ref('this_month');
const filterPipelineId = ref('');
const filterAssigneeId = ref('');
const filterSource = ref('');
const customFrom = ref('');
const customTo = ref('');

const SECTION_TABS = ['Pipeline', 'Receita', 'Responsável', 'Canal'];
const activeSection = ref('Pipeline');

// ── Store ─────────────────────────────────────────────────────────────────────
const pipelines = computed(() => store.getters['kanban/getPipelines']);
const stages = computed(() => store.getters['kanban/getStages']);
const agents = computed(() => store.getters['agents/getAgents'] || []);

// ── Item loading across pipelines ─────────────────────────────────────────────
const allItems = ref([]);
const loading = ref(false);

function periodRange() {
  const now = new Date();
  let from;
  let to;
  switch (filterPeriod.value) {
    case 'this_month':
      from = new Date(now.getFullYear(), now.getMonth(), 1)
        .toISOString()
        .slice(0, 10);
      to = new Date(now.getFullYear(), now.getMonth() + 1, 0)
        .toISOString()
        .slice(0, 10);
      break;
    case 'last_month':
      from = new Date(now.getFullYear(), now.getMonth() - 1, 1)
        .toISOString()
        .slice(0, 10);
      to = new Date(now.getFullYear(), now.getMonth(), 0)
        .toISOString()
        .slice(0, 10);
      break;
    case 'this_quarter': {
      const q = Math.floor(now.getMonth() / 3);
      from = new Date(now.getFullYear(), q * 3, 1).toISOString().slice(0, 10);
      to = new Date(now.getFullYear(), q * 3 + 3, 0).toISOString().slice(0, 10);
      break;
    }
    case 'this_year':
      from = `${now.getFullYear()}-01-01`;
      to = `${now.getFullYear()}-12-31`;
      break;
    case 'custom':
      from = customFrom.value;
      to = customTo.value;
      break;
    default:
      break;
  }
  return { from, to };
}

async function loadAllItems() {
  loading.value = true;
  allItems.value = [];
  try {
    const { from, to } = periodRange();
    const filters = {};
    if (from) filters.created_from = from;
    if (to) filters.created_to = to;
    if (filterAssigneeId.value) filters.assignee_id = filterAssigneeId.value;
    if (filterSource.value) filters.source = filterSource.value;

    const targetPipelines = filterPipelineId.value
      ? pipelines.value.filter(p => p.id === Number(filterPipelineId.value))
      : pipelines.value;

    // Sequential fetch per pipeline to avoid store race conditions
    await targetPipelines.reduce(
      (chain, pipeline) =>
        chain.then(async () => {
          await store.dispatch('kanban/fetchStages', pipeline.id);
          await store.dispatch('kanban/fetchItems', {
            pipelineId: pipeline.id,
            filters,
          });
          const items = store.getters['kanban/getItems'];
          allItems.value.push(
            ...items.map(i => ({ ...i, _pipeline_name: pipeline.name }))
          );
        }),
      Promise.resolve()
    );
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  await store.dispatch('kanban/fetchPipelines');
  store.dispatch('agents/get').catch(() => {});
  await loadAllItems();
});

watch(
  [
    filterPeriod,
    filterPipelineId,
    filterAssigneeId,
    filterSource,
    customFrom,
    customTo,
  ],
  loadAllItems
);

// ── Metrics ───────────────────────────────────────────────────────────────────
const openItems = computed(() =>
  allItems.value.filter(i => !i.won_at && !i.lost_at)
);
const wonItems = computed(() => allItems.value.filter(i => i.won_at));
const lostItems = computed(() => allItems.value.filter(i => i.lost_at));

const totalOpenValue = computed(() =>
  openItems.value.reduce((s, i) => s + (parseFloat(i.value) || 0), 0)
);
const totalWonValue = computed(() =>
  wonItems.value.reduce((s, i) => s + (parseFloat(i.value) || 0), 0)
);
const totalLostValue = computed(() =>
  lostItems.value.reduce((s, i) => s + (parseFloat(i.value) || 0), 0)
);

const convRate = computed(() => {
  const c = wonItems.value.length + lostItems.value.length;
  return c ? ((wonItems.value.length / c) * 100).toFixed(1) : '0.0';
});
const avgTicket = computed(() =>
  wonItems.value.length ? totalWonValue.value / wonItems.value.length : 0
);
const avgCycle = computed(() => {
  const w = wonItems.value.filter(i => i.created_at && i.won_at);
  if (!w.length) return 0;
  return Math.round(
    w.reduce((s, i) => s + (i.won_at - i.created_at) / 86400, 0) / w.length
  );
});
const forecast = computed(() =>
  openItems.value.reduce((s, i) => {
    const stage = stages.value.find(st => st.id === i.stage_id);
    return s + (parseFloat(i.value) || 0) * ((stage?.probability || 0) / 100);
  }, 0)
);

// ── Stage breakdown ───────────────────────────────────────────────────────────
const stageBreakdown = computed(() => {
  const pipelinesFiltered = filterPipelineId.value
    ? pipelines.value.filter(p => p.id === Number(filterPipelineId.value))
    : pipelines.value;

  return pipelinesFiltered.map(pipeline => {
    const ps = stages.value
      .filter(s => s.pipeline_id === pipeline.id)
      .sort((a, b) => a.position - b.position);
    return {
      pipeline,
      stages: ps.map(stage => {
        const si = allItems.value.filter(
          i => i.stage_id === stage.id && !i.won_at && !i.lost_at
        );
        return {
          stage,
          count: si.length,
          value: si.reduce((s, i) => s + (parseFloat(i.value) || 0), 0),
        };
      }),
    };
  });
});

const maxStageItems = computed(() => {
  let m = 0;
  stageBreakdown.value.forEach(pb =>
    pb.stages.forEach(s => {
      if (s.count > m) m = s.count;
    })
  );
  return m || 1;
});

// ── Source breakdown ──────────────────────────────────────────────────────────
const sourceBreakdown = computed(() => {
  const map = {};
  allItems.value.forEach(i => {
    const s = i.source || 'Outros';
    if (!map[s]) map[s] = { count: 0, won: 0, value: 0 };
    map[s].count++;
    if (i.won_at) {
      map[s].won++;
      map[s].value += parseFloat(i.value) || 0;
    }
  });
  return Object.entries(map).map(([source, d]) => ({ source, ...d }));
});

const doughnutData = computed(() => ({
  labels: sourceBreakdown.value.map(s => s.source),
  datasets: [
    {
      data: sourceBreakdown.value.map(s => s.count),
      backgroundColor: [
        '#6366f1',
        '#0ea5e9',
        '#10b981',
        '#f59e0b',
        '#ef4444',
        '#8b5cf6',
        '#ec4899',
        '#64748b',
      ],
    },
  ],
}));
const doughnutOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { position: 'bottom' } },
};

// ── Assignee breakdown ────────────────────────────────────────────────────────
const assigneeBreakdown = computed(() => {
  const map = {};
  allItems.value.forEach(i => {
    const k = i.assignee?.id || 'unassigned';
    const n = i.assignee?.name || 'Sem responsável';
    if (!map[k]) map[k] = { name: n, total: 0, won: 0, lost: 0, wonValue: 0 };
    map[k].total++;
    if (i.won_at) {
      map[k].won++;
      map[k].wonValue += parseFloat(i.value) || 0;
    }
    if (i.lost_at) map[k].lost++;
  });
  return Object.values(map).sort((a, b) => b.won - a.won);
});

// ── Formatter ─────────────────────────────────────────────────────────────────
const BRL = v =>
  new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  }).format(v || 0);
</script>

<template>
  <div class="flex flex-col h-full bg-white dark:bg-slate-900">
    <!-- Header -->
    <div
      class="px-6 py-5 border-b border-slate-200 dark:border-slate-700 shrink-0"
    >
      <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">
        Relatórios Kanban
      </h1>
      <p class="text-sm text-slate-400 mt-0.5">
        Acompanhe suas métricas de vendas e performance
      </p>
    </div>

    <!-- Filters -->
    <div
      class="px-6 py-3 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50 flex items-center gap-2 flex-wrap shrink-0"
    >
      <select
        v-model="filterPeriod"
        class="text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-woot-500"
      >
        <option v-for="p in PERIODS" :key="p.value" :value="p.value">
          {{ p.label }}
        </option>
      </select>
      <template v-if="filterPeriod === 'custom'">
        <input
          v-model="customFrom"
          type="date"
          class="text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
        />
        <span class="text-slate-400 text-sm">até</span>
        <input
          v-model="customTo"
          type="date"
          class="text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
        />
      </template>
      <select
        v-model="filterPipelineId"
        class="text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
      >
        <option value="">Todos os funis</option>
        <option v-for="p in pipelines" :key="p.id" :value="p.id">
          {{ p.name }}
        </option>
      </select>
      <select
        v-model="filterAssigneeId"
        class="text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
      >
        <option value="">Todos</option>
        <option v-for="a in agents" :key="a.id" :value="a.id">
          {{ a.name }}
        </option>
      </select>
      <select
        v-model="filterSource"
        class="text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
      >
        <option value="">Todas as fontes</option>
        <option value="whatsapp">WhatsApp</option>
        <option value="instagram">Instagram</option>
        <option value="facebook">Facebook</option>
        <option value="website">Website</option>
        <option value="phone">Telefone</option>
        <option value="email">E-mail</option>
        <option value="referral">Indicação</option>
      </select>
      <span
        v-if="loading"
        class="ml-auto i-lucide-loader-circle size-4 animate-spin text-woot-500"
      />
    </div>

    <!-- Metric cards -->
    <div
      class="px-6 py-4 grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 shrink-0"
    >
      <div
        class="bg-blue-50 dark:bg-blue-900/20 border border-blue-100 dark:border-blue-800 rounded-xl p-4"
      >
        <p class="text-xs font-medium text-blue-600 flex items-center gap-1">
          <span class="i-lucide-layers size-3.5" />Em Aberto
        </p>
        <p class="text-2xl font-bold text-blue-700 dark:text-blue-300 mt-1">
          {{ openItems.length }}
        </p>
        <p class="text-xs text-blue-500 mt-0.5">{{ BRL(totalOpenValue) }}</p>
      </div>
      <div
        class="bg-green-50 dark:bg-green-900/20 border border-green-100 dark:border-green-800 rounded-xl p-4"
      >
        <p class="text-xs font-medium text-green-600 flex items-center gap-1">
          <span class="i-lucide-trophy size-3.5" />Ganhos
        </p>
        <p class="text-2xl font-bold text-green-700 dark:text-green-300 mt-1">
          {{ wonItems.length }}
        </p>
        <p class="text-xs text-green-500 mt-0.5">{{ BRL(totalWonValue) }}</p>
      </div>
      <div
        class="bg-red-50 dark:bg-red-900/20 border border-red-100 dark:border-red-800 rounded-xl p-4"
      >
        <p class="text-xs font-medium text-red-600 flex items-center gap-1">
          <span class="i-lucide-x-circle size-3.5" />Perdidos
        </p>
        <p class="text-2xl font-bold text-red-700 dark:text-red-300 mt-1">
          {{ lostItems.length }}
        </p>
        <p class="text-xs text-red-500 mt-0.5">{{ BRL(totalLostValue) }}</p>
      </div>
      <div
        class="bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-4"
      >
        <p class="text-xs font-medium text-slate-500 flex items-center gap-1">
          <span class="i-lucide-percent size-3.5" />Taxa Conversão
        </p>
        <p class="text-2xl font-bold text-slate-700 dark:text-slate-100 mt-1">
          {{ convRate }}%
        </p>
        <p class="text-xs text-slate-400 mt-0.5">ganhos / fechados</p>
      </div>
      <div
        class="bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-4"
      >
        <p class="text-xs font-medium text-slate-500 flex items-center gap-1">
          <span class="i-lucide-dollar-sign size-3.5" />Ticket Médio
        </p>
        <p class="text-base font-bold text-slate-700 dark:text-slate-100 mt-1">
          {{ BRL(avgTicket) }}
        </p>
        <p class="text-xs text-slate-400 mt-0.5">por ganho</p>
      </div>
      <div
        class="bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-4"
      >
        <p class="text-xs font-medium text-slate-500 flex items-center gap-1">
          <span class="i-lucide-clock size-3.5" />Ciclo Médio
        </p>
        <p class="text-2xl font-bold text-slate-700 dark:text-slate-100 mt-1">
          {{ avgCycle }}
        </p>
        <p class="text-xs text-slate-400 mt-0.5">dias até ganho</p>
      </div>
    </div>

    <!-- Section tabs -->
    <div class="px-6 border-b border-slate-200 dark:border-slate-700 shrink-0">
      <div class="flex">
        <button
          v-for="tab in SECTION_TABS"
          :key="tab"
          class="px-4 py-3 text-sm font-medium border-b-2 transition-colors"
          :class="
            activeSection === tab
              ? 'border-woot-500 text-woot-600 dark:text-woot-400'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          "
          @click="activeSection = tab"
        >
          {{ tab }}
        </button>
      </div>
    </div>

    <!-- Section content -->
    <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">
      <!-- PIPELINE -->
      <template v-if="activeSection === 'Pipeline'">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div
            class="bg-woot-50 dark:bg-woot-900/20 border border-woot-100 dark:border-woot-800 rounded-xl p-4"
          >
            <p
              class="text-xs font-medium text-woot-600 flex items-center gap-1"
            >
              <span class="i-lucide-trending-up size-3.5" />Forecast (ponderado)
            </p>
            <p class="text-2xl font-bold text-woot-700 dark:text-woot-300 mt-1">
              {{ BRL(forecast) }}
            </p>
            <p class="text-xs text-woot-500 mt-0.5">
              Valor em aberto × probabilidade da etapa
            </p>
          </div>
          <div
            class="bg-green-50 dark:bg-green-900/20 border border-green-100 dark:border-green-800 rounded-xl p-4"
          >
            <p
              class="text-xs font-medium text-green-600 flex items-center gap-1"
            >
              <span class="i-lucide-check-circle size-3.5" />Realizado no
              período
            </p>
            <p
              class="text-2xl font-bold text-green-700 dark:text-green-300 mt-1"
            >
              {{ BRL(totalWonValue) }}
            </p>
            <p class="text-xs text-green-500 mt-0.5">
              {{ wonItems.length }} negócios fechados
            </p>
          </div>
        </div>

        <div
          v-for="pb in stageBreakdown"
          :key="pb.pipeline.id"
          class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl overflow-hidden"
        >
          <div
            class="px-4 py-3 border-b border-slate-100 dark:border-slate-700 flex items-center gap-2"
          >
            <span class="i-lucide-filter size-4 text-woot-500" />
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ pb.pipeline.name }}
            </h3>
          </div>
          <div class="divide-y divide-slate-100 dark:divide-slate-700">
            <div
              v-for="sb in pb.stages"
              :key="sb.stage.id"
              class="px-4 py-3 flex items-center gap-3"
            >
              <span
                class="size-2.5 rounded-full shrink-0"
                :style="{ backgroundColor: sb.stage.color }"
              />
              <span
                class="text-sm text-slate-700 dark:text-slate-200 w-36 truncate"
                >{{ sb.stage.name }}</span
              >
              <div
                class="flex-1 h-2 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden"
              >
                <div
                  class="h-full rounded-full"
                  :style="{
                    width: `${(sb.count / maxStageItems) * 100}%`,
                    backgroundColor: sb.stage.color,
                  }"
                />
              </div>
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200 w-8 text-right"
                >{{ sb.count }}</span
              >
              <span class="text-xs text-slate-400 w-24 text-right">{{
                BRL(sb.value)
              }}</span>
              <span class="text-xs text-slate-400 w-8 text-right"
                >{{ sb.stage.probability }}%</span
              >
            </div>
            <div
              v-if="!pb.stages.length"
              class="px-4 py-3 text-xs text-slate-400"
            >
              Sem etapas
            </div>
          </div>
        </div>
      </template>

      <!-- RECEITA -->
      <template v-else-if="activeSection === 'Receita'">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div
            class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-4"
          >
            <h3
              class="text-sm font-semibold text-slate-700 dark:text-slate-200 mb-3"
            >
              Distribuição por Canal
            </h3>
            <div style="height: 220px">
              <Doughnut
                v-if="sourceBreakdown.length"
                :data="doughnutData"
                :options="doughnutOptions"
              />
              <p v-else class="text-xs text-slate-400 text-center pt-8">
                Sem dados
              </p>
            </div>
          </div>
          <div
            class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-4"
          >
            <h3
              class="text-sm font-semibold text-slate-700 dark:text-slate-200 mb-3"
            >
              Por Canal
            </h3>
            <table class="w-full text-xs">
              <thead>
                <tr
                  class="text-slate-400 border-b border-slate-100 dark:border-slate-700"
                >
                  <th class="text-left pb-2">Canal</th>
                  <th class="text-right pb-2">Leads</th>
                  <th class="text-right pb-2">Ganhos</th>
                  <th class="text-right pb-2">Conv%</th>
                  <th class="text-right pb-2">Valor</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="s in sourceBreakdown"
                  :key="s.source"
                  class="border-b border-slate-50 dark:border-slate-700/50"
                >
                  <td
                    class="py-1.5 capitalize font-medium text-slate-700 dark:text-slate-200"
                  >
                    {{ s.source }}
                  </td>
                  <td class="text-right text-slate-500">{{ s.count }}</td>
                  <td class="text-right text-green-600">{{ s.won }}</td>
                  <td class="text-right text-slate-500">
                    {{ s.count ? ((s.won / s.count) * 100).toFixed(0) : 0 }}%
                  </td>
                  <td class="text-right text-slate-500">{{ BRL(s.value) }}</td>
                </tr>
                <tr v-if="!sourceBreakdown.length">
                  <td colspan="5" class="py-3 text-center text-slate-400">
                    Sem dados
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </template>

      <!-- RESPONSÁVEL -->
      <template v-else-if="activeSection === 'Responsável'">
        <div
          class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl overflow-hidden"
        >
          <div
            class="px-4 py-3 border-b border-slate-100 dark:border-slate-700"
          >
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              Performance por Responsável
            </h3>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead class="bg-slate-50 dark:bg-slate-900/40">
                <tr
                  class="text-xs text-slate-400 font-semibold uppercase tracking-wider"
                >
                  <th class="text-left px-4 py-2.5">Agente</th>
                  <th class="text-right px-4 py-2.5">Total</th>
                  <th class="text-right px-4 py-2.5">Ganhos</th>
                  <th class="text-right px-4 py-2.5">Perdidos</th>
                  <th class="text-right px-4 py-2.5">Conv%</th>
                  <th class="text-right px-4 py-2.5">Valor Ganho</th>
                  <th class="text-right px-4 py-2.5">Ticket Médio</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
                <tr
                  v-for="a in assigneeBreakdown"
                  :key="a.name"
                  class="hover:bg-slate-50 dark:hover:bg-slate-700/30"
                >
                  <td
                    class="px-4 py-3 font-medium text-slate-700 dark:text-slate-200"
                  >
                    {{ a.name }}
                  </td>
                  <td class="px-4 py-3 text-right text-slate-500">
                    {{ a.total }}
                  </td>
                  <td class="px-4 py-3 text-right text-green-600 font-medium">
                    {{ a.won }}
                  </td>
                  <td class="px-4 py-3 text-right text-red-500">
                    {{ a.lost }}
                  </td>
                  <td class="px-4 py-3 text-right text-slate-500">
                    {{
                      a.won + a.lost
                        ? ((a.won / (a.won + a.lost)) * 100).toFixed(0)
                        : 0
                    }}%
                  </td>
                  <td
                    class="px-4 py-3 text-right text-slate-700 dark:text-slate-200"
                  >
                    {{ BRL(a.wonValue) }}
                  </td>
                  <td class="px-4 py-3 text-right text-slate-500">
                    {{ BRL(a.won ? a.wonValue / a.won : 0) }}
                  </td>
                </tr>
                <tr v-if="!assigneeBreakdown.length">
                  <td
                    colspan="7"
                    class="px-4 py-6 text-center text-xs text-slate-400"
                  >
                    Sem dados no período
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </template>

      <!-- CANAL -->
      <template v-else-if="activeSection === 'Canal'">
        <div
          class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl overflow-hidden"
        >
          <div
            class="px-4 py-3 border-b border-slate-100 dark:border-slate-700"
          >
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              Performance por Canal de Origem
            </h3>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead class="bg-slate-50 dark:bg-slate-900/40">
                <tr
                  class="text-xs text-slate-400 font-semibold uppercase tracking-wider"
                >
                  <th class="text-left px-4 py-2.5">Canal</th>
                  <th class="text-right px-4 py-2.5">Leads</th>
                  <th class="text-right px-4 py-2.5">Ganhos</th>
                  <th class="text-right px-4 py-2.5">Perdidos</th>
                  <th class="text-right px-4 py-2.5">Conv%</th>
                  <th class="text-right px-4 py-2.5">Valor Ganho</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
                <tr v-for="s in sourceBreakdown" :key="s.source">
                  <td
                    class="px-4 py-3 capitalize font-medium text-slate-700 dark:text-slate-200"
                  >
                    {{ s.source }}
                  </td>
                  <td class="px-4 py-3 text-right text-slate-500">
                    {{ s.count }}
                  </td>
                  <td class="px-4 py-3 text-right text-green-600">
                    {{ s.won }}
                  </td>
                  <td class="px-4 py-3 text-right text-red-500">
                    {{ s.count - s.won }}
                  </td>
                  <td class="px-4 py-3 text-right text-slate-500">
                    {{ s.count ? ((s.won / s.count) * 100).toFixed(0) : 0 }}%
                  </td>
                  <td
                    class="px-4 py-3 text-right text-slate-700 dark:text-slate-200"
                  >
                    {{ BRL(s.value) }}
                  </td>
                </tr>
                <tr v-if="!sourceBreakdown.length">
                  <td
                    colspan="6"
                    class="px-4 py-6 text-center text-xs text-slate-400"
                  >
                    Sem dados no período
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
