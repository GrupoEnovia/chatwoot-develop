<!-- eslint-disable vue/no-bare-strings-in-template, prettier/prettier -->
<script setup>
import { ref } from 'vue';
import aiAgentsAPI from '../../api/aiAgents';

const props = defineProps({ agentId: { type: Number, required: true } });
const emit  = defineEmits(['close']);

const loading = ref(false);
const error   = ref(null);
const result  = ref(null);

async function analyze() {
  loading.value = true;
  error.value   = null;
  result.value  = null;
  try {
    const res    = await aiAgentsAPI.promptAssistant(props.agentId);
    result.value = res.data?.payload;
  } catch (e) {
    error.value = e.response?.data?.error || 'Erro ao analisar o prompt.';
  } finally {
    loading.value = false;
  }
}

const SEVERITY_COLORS = {
  high:   'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 text-red-700 dark:text-red-300',
  medium: 'bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800 text-amber-700 dark:text-amber-300',
  low:    'bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300',
};
const SEVERITY_ICONS = { high: 'i-lucide-alert-circle', medium: 'i-lucide-alert-triangle', low: 'i-lucide-info' };
const SEVERITY_LABELS = { high: 'Alta', medium: 'Média', low: 'Baixa' };

function scoreColor(score) {
  if (score >= 80) return 'text-emerald-500';
  if (score >= 60) return 'text-amber-500';
  return 'text-red-500';
}
function scoreLabel(score) {
  if (score >= 80) return 'Bom';
  if (score >= 60) return 'Regular';
  return 'Precisa melhorar';
}

analyze();
</script>

<template>
  <div
    class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
    @click.self="emit('close')"
  >
    <div
      class="bg-white dark:bg-slate-900 rounded-xl shadow-2xl w-full max-w-2xl max-h-[88vh] flex flex-col overflow-hidden"
    >
      <!-- Header -->
      <div
        class="flex items-center justify-between px-6 py-4 border-b border-slate-200 dark:border-slate-700 shrink-0"
      >
        <div class="flex items-center gap-2">
          <span class="i-lucide-sparkles size-5 text-violet-500" />
          <h3
            class="text-base font-semibold text-slate-800 dark:text-slate-100"
          >
            Assistente de Prompt
          </h3>
        </div>
        <button
          class="p-1 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          @click="emit('close')"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>

      <!-- Body -->
      <div class="flex-1 overflow-y-auto px-6 py-5 space-y-5">
        <!-- Loading -->
        <div
          v-if="loading"
          class="flex flex-col items-center justify-center py-16 gap-4"
        >
          <span class="i-lucide-loader-2 size-8 animate-spin text-violet-500" />
          <p class="text-sm text-slate-500">Analisando o prompt com IA...</p>
          <p class="text-xs text-slate-400">Isso pode levar alguns segundos</p>
        </div>

        <!-- Error -->
        <div v-else-if="error" class="text-center py-10">
          <p class="text-sm text-red-500">{{ error }}</p>
          <button
            class="mt-3 text-xs text-violet-500 hover:underline"
            @click="analyze"
          >
            Tentar novamente
          </button>
        </div>

        <!-- Result -->
        <template v-else-if="result">
          <!-- Score -->
          <div
            class="flex items-center gap-4 p-4 bg-slate-50 dark:bg-slate-800 rounded-xl"
          >
            <div class="text-center shrink-0">
              <p class="text-4xl font-bold" :class="scoreColor(result.score)">
                {{ result.score }}
              </p>
              <p class="text-[11px] text-slate-400 mt-0.5">/ 100</p>
            </div>
            <div>
              <p
                class="text-sm font-semibold"
                :class="scoreColor(result.score)"
              >
                {{ scoreLabel(result.score) }}
              </p>
              <p
                class="text-xs text-slate-500 dark:text-slate-400 mt-1 leading-relaxed"
              >
                {{ result.summary }}
              </p>
            </div>
          </div>

          <!-- Issues -->
          <div v-if="result.issues && result.issues.length > 0">
            <h4
              class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-3"
            >
              Problemas encontrados ({{ result.issues.length }})
            </h4>
            <div class="space-y-2">
              <div
                v-for="(issue, i) in result.issues"
                :key="i"
                class="flex gap-3 p-3 rounded-lg border text-xs"
                :class="SEVERITY_COLORS[issue.severity] || SEVERITY_COLORS.low"
              >
                <span
                  class="size-4 shrink-0 mt-0.5"
                  :class="SEVERITY_ICONS[issue.severity] || 'i-lucide-info'"
                />
                <div>
                  <span class="font-semibold capitalize">{{
                    issue.section
                  }}</span>
                  <span class="text-[10px] opacity-70 ml-2">
                    Prioridade
                    {{ SEVERITY_LABELS[issue.severity] || issue.severity }}
                  </span>
                  <p class="mt-0.5 opacity-90 leading-relaxed">
                    {{ issue.description }}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div
            v-else-if="!loading"
            class="flex items-center gap-2 text-xs text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-900/20 px-3 py-2 rounded-lg border border-emerald-200 dark:border-emerald-800"
          >
            <span class="i-lucide-check-circle size-4" />
            Nenhum problema grave encontrado
          </div>

          <!-- Suggestions -->
          <div v-if="result.suggestions && result.suggestions.length > 0">
            <h4
              class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-3"
            >
              Sugestões de melhoria
            </h4>
            <div class="space-y-3">
              <div
                v-for="(sug, i) in result.suggestions"
                :key="i"
                class="p-3 rounded-lg border border-violet-100 dark:border-violet-900 bg-violet-50/50 dark:bg-violet-900/10"
              >
                <div class="flex items-start gap-2">
                  <span
                    class="i-lucide-lightbulb size-4 text-violet-500 mt-0.5 shrink-0"
                  />
                  <div class="flex-1 space-y-1.5">
                    <p
                      class="text-[11px] font-semibold text-violet-600 dark:text-violet-400 uppercase tracking-wide"
                    >
                      {{ sug.section }}
                    </p>
                    <p
                      class="text-xs text-slate-700 dark:text-slate-300 leading-relaxed"
                    >
                      {{ sug.suggestion }}
                    </p>
                    <div
                      v-if="sug.example"
                      class="text-[11px] text-slate-500 dark:text-slate-400 bg-white dark:bg-slate-800 rounded-md p-2 border border-slate-200 dark:border-slate-700 italic leading-relaxed"
                    >
                      "{{ sug.example }}"
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>

      <!-- Footer -->
      <div
        class="shrink-0 px-6 py-4 border-t border-slate-200 dark:border-slate-700 flex items-center justify-between"
      >
        <button
          v-if="result"
          class="flex items-center gap-1.5 text-xs text-slate-500 hover:text-slate-700 dark:hover:text-slate-300 transition-colors"
          :disabled="loading"
          @click="analyze"
        >
          <span class="i-lucide-refresh-cw size-3.5" /> Reanalisar
        </button>
        <span v-else />
        <button
          class="px-4 py-2 text-xs font-medium bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 rounded-lg hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors"
          @click="emit('close')"
        >
          Fechar
        </button>
      </div>
    </div>
  </div>
</template>
