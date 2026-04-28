<script setup>
import { ref, onMounted, watch } from 'vue';
import aiAgentsAPI from '../../api/aiAgents';

const props = defineProps({
  agentId: { type: Number, required: true },
});

const data = ref(null);
const loading = ref(false);
const period = ref('week');

const PERIODS = [
  { value: 'today', label: 'Hoje' },
  { value: 'week', label: '7 dias' },
  { value: 'month', label: '30 dias' },
];

async function load() {
  loading.value = true;
  try {
    const res = await aiAgentsAPI.getAgentMetrics(props.agentId, period.value);
    data.value = res.data.payload;
  } finally {
    loading.value = false;
  }
}

watch(period, load);
onMounted(load);

function statusColor(status) {
  return (
    {
      success: 'bg-emerald-100 text-emerald-700',
      error: 'bg-red-100 text-red-600',
      skipped: 'bg-slate-100 text-slate-500',
      protocol: 'bg-purple-100 text-purple-700',
      buffered: 'bg-yellow-100 text-yellow-700',
    }[status] || 'bg-slate-100 text-slate-500'
  );
}

function formatDuration(ms) {
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

function maxTimelineCount(timeline) {
  if (!timeline?.length) return 1;
  return Math.max(...timeline.map(e => (e.success || 0) + (e.error || 0)), 1);
}
</script>

<template>
  <div class="space-y-5">
    <!-- Period selector -->
    <div class="flex items-center justify-between">
      <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200">
        Métricas do Agente
      </h3>
      <div class="flex gap-1">
        <button
          v-for="p in PERIODS"
          :key="p.value"
          class="px-3 py-1 text-xs rounded-full border transition-colors"
          :class="
            period === p.value
              ? 'bg-violet-600 text-white border-violet-600'
              : 'bg-white dark:bg-slate-800 border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300'
          "
          @click="period = p.value"
        >
          {{ p.label }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex justify-center py-12">
      <span class="i-lucide-loader-2 size-6 animate-spin text-slate-400" />
    </div>

    <template v-else-if="data">
      <!-- Summary cards -->
      <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div
          class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-4"
        >
          <p class="text-xs text-slate-500 mb-1">Conversas</p>
          <p class="text-2xl font-bold text-slate-800 dark:text-slate-100">
            {{ data.summary.total_conversations }}
          </p>
          <p class="text-xs text-slate-400 mt-0.5">
            {{ data.summary.active_conversations }} ativas
          </p>
        </div>
        <div
          class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-4"
        >
          <p class="text-xs text-slate-500 mb-1">Execuções</p>
          <p class="text-2xl font-bold text-slate-800 dark:text-slate-100">
            {{ data.summary.total_executions }}
          </p>
          <p class="text-xs text-emerald-500 mt-0.5">
            {{ data.summary.success_rate }}% sucesso
          </p>
        </div>
        <div
          class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-4"
        >
          <p class="text-xs text-slate-500 mb-1">Tempo médio</p>
          <p class="text-2xl font-bold text-slate-800 dark:text-slate-100">
            {{ formatDuration(data.summary.avg_duration_ms) }}
          </p>
          <p class="text-xs text-slate-400 mt-0.5">por resposta LLM</p>
        </div>
        <div
          class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-4"
        >
          <p class="text-xs text-slate-500 mb-1">Protocolos</p>
          <p class="text-2xl font-bold text-slate-800 dark:text-slate-100">
            {{ data.summary.protocols_triggered }}
          </p>
          <p class="text-xs text-slate-400 mt-0.5">
            {{ data.summary.error_count }} erros
          </p>
        </div>
      </div>

      <!-- Timeline -->
      <div
        class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5"
      >
        <h4
          class="text-xs font-semibold text-slate-500 dark:text-slate-400 mb-4"
        >
          Execuções por dia
        </h4>
        <div
          v-if="data.timeline.length === 0"
          class="text-xs text-slate-400 text-center py-6"
        >
          Sem dados no período.
        </div>
        <div v-else class="flex items-end gap-1 h-28">
          <div
            v-for="entry in data.timeline"
            :key="entry.date"
            class="flex-1 flex flex-col items-center gap-0.5 group"
          >
            <div class="flex flex-col w-full justify-end" style="height: 80px">
              <div
                v-if="entry.error"
                class="w-full bg-red-400 rounded-t"
                :style="{
                  height: `${((entry.error || 0) / maxTimelineCount(data.timeline)) * 76}px`,
                }"
              />
              <div
                class="w-full bg-emerald-400 rounded-t"
                :class="entry.error ? 'rounded-t-none' : ''"
                :style="{
                  height: `${((entry.success || 0) / maxTimelineCount(data.timeline)) * 76}px`,
                }"
              />
            </div>
            <span
              class="text-[10px] text-slate-400 rotate-45 origin-left mt-1 whitespace-nowrap"
            >
              {{ entry.date.slice(5) }}
            </span>
          </div>
        </div>
        <div class="flex items-center gap-3 mt-3">
          <span class="flex items-center gap-1 text-xs text-slate-500">
            <span class="w-2 h-2 rounded-sm bg-emerald-400 inline-block" />
            Sucesso
          </span>
          <span class="flex items-center gap-1 text-xs text-slate-500">
            <span class="w-2 h-2 rounded-sm bg-red-400 inline-block" /> Erro
          </span>
        </div>
      </div>

      <!-- Protocol distribution -->
      <div
        v-if="data.protocols?.length"
        class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5"
      >
        <h4
          class="text-xs font-semibold text-slate-500 dark:text-slate-400 mb-3"
        >
          Protocolos acionados
        </h4>
        <div class="flex flex-col gap-2">
          <div
            v-for="p in data.protocols"
            :key="p.keyword"
            class="flex items-center gap-3"
          >
            <span
              class="text-xs font-mono bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 px-2 py-0.5 rounded w-28 shrink-0"
            >
              {{ p.keyword }}
            </span>
            <div
              class="flex-1 bg-slate-100 dark:bg-slate-700 rounded-full h-2 overflow-hidden"
            >
              <div
                class="h-2 bg-purple-400 rounded-full"
                :style="{
                  width: `${(p.count / data.protocols[0].count) * 100}%`,
                }"
              />
            </div>
            <span class="text-xs text-slate-500 w-6 text-right shrink-0">{{
              p.count
            }}</span>
          </div>
        </div>
      </div>

      <!-- Recent executions -->
      <div
        class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5"
      >
        <h4
          class="text-xs font-semibold text-slate-500 dark:text-slate-400 mb-3"
        >
          Execuções recentes
        </h4>
        <div
          v-if="!data.recent_executions?.length"
          class="text-xs text-slate-400 text-center py-4"
        >
          Nenhuma execução ainda.
        </div>
        <div
          class="flex flex-col divide-y divide-slate-100 dark:divide-slate-700"
        >
          <div
            v-for="exec in data.recent_executions"
            :key="exec.id"
            class="flex items-center gap-3 py-2"
          >
            <span
              class="text-[10px] px-1.5 py-0.5 rounded font-medium shrink-0"
              :class="statusColor(exec.status)"
              >{{ exec.status }}</span
            >
            <span class="text-xs text-slate-400 shrink-0">{{
              formatDuration(exec.duration_ms)
            }}</span>
            <span
              v-if="exec.protocol_triggered"
              class="text-xs font-mono text-purple-500 shrink-0"
            >
              {{ exec.protocol_triggered }}
            </span>
            <span
              v-if="exec.error_message"
              class="text-xs text-red-400 truncate flex-1"
            >
              {{ exec.error_message }}
            </span>
            <span class="text-xs text-slate-400 ml-auto shrink-0">
              {{
                new Date(exec.created_at).toLocaleString('pt-BR', {
                  day: '2-digit',
                  month: '2-digit',
                  hour: '2-digit',
                  minute: '2-digit',
                })
              }}
            </span>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
