<!-- eslint-disable vue/no-bare-strings-in-template, prettier/prettier -->
<script setup>
import { computed } from 'vue';

const props = defineProps({
  versionA: { type: Object, required: true },
  versionB: { type: Object, required: true },
  labelA:   { type: String, default: '' },
  labelB:   { type: String, default: '' },
});
const emit = defineEmits(['close', 'restore']);

const DEFAULT_PROMPT = {
  identity:    {},
  business:    {},
  products:    [],
  personality: [],
  rules:       [],
  flow:        [],
};

function normalize(p) {
  return { ...DEFAULT_PROMPT, ...(p || {}) };
}

function eq(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function formatObject(obj) {
  if (!obj || typeof obj !== 'object') return '—';
  const entries = Object.entries(obj).filter(([, v]) => v !== null && v !== undefined && v !== '');
  if (!entries.length) return '—';
  return entries.map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`).join('\n');
}

function formatList(arr, fn) {
  if (!Array.isArray(arr) || arr.length === 0) return '—';
  return arr.map((item, i) => {
    let text;
    if (fn) {
      text = fn(item);
    } else if (typeof item === 'string') {
      text = item;
    } else {
      text = JSON.stringify(item);
    }
    return `${i + 1}. ${text}`;
  }).join('\n');
}

function formatDate(dt) {
  return new Date(dt).toLocaleString('pt-BR');
}

const pa = computed(() => normalize(props.versionA.prompt));
const pb = computed(() => normalize(props.versionB.prompt));

const SECTIONS = computed(() => [
  {
    key:     'identity',
    label:   'Identidade',
    icon:    'i-lucide-user',
    changed: !eq(pa.value.identity, pb.value.identity),
    renderA: formatObject(pa.value.identity),
    renderB: formatObject(pb.value.identity),
  },
  {
    key:     'business',
    label:   'Negócio',
    icon:    'i-lucide-building-2',
    changed: !eq(pa.value.business, pb.value.business),
    renderA: formatObject(pa.value.business),
    renderB: formatObject(pb.value.business),
  },
  {
    key:     'products',
    label:   'Produtos',
    icon:    'i-lucide-package',
    changed: !eq(pa.value.products, pb.value.products),
    renderA: formatList(pa.value.products, p => `${p.name} (${p.value})`),
    renderB: formatList(pb.value.products, p => `${p.name} (${p.value})`),
  },
  {
    key:     'personality',
    label:   'Personalidade',
    icon:    'i-lucide-sparkles',
    changed: !eq(pa.value.personality, pb.value.personality),
    renderA: formatList(pa.value.personality),
    renderB: formatList(pb.value.personality),
  },
  {
    key:     'rules',
    label:   'Regras',
    icon:    'i-lucide-shield',
    changed: !eq(pa.value.rules, pb.value.rules),
    renderA: formatList(pa.value.rules),
    renderB: formatList(pb.value.rules),
  },
  {
    key:     'flow',
    label:   'Fluxo de Conversão',
    icon:    'i-lucide-git-branch',
    changed: !eq(pa.value.flow, pb.value.flow),
    renderA: formatList(pa.value.flow, s => s.title || s.name || '(sem título)'),
    renderB: formatList(pb.value.flow, s => s.title || s.name || '(sem título)'),
  },
]);

const changedCount = computed(() => SECTIONS.value.filter(s => s.changed).length);
</script>

<template>
  <div
    class="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4"
    @click.self="emit('close')"
  >
    <div
      class="bg-white dark:bg-slate-900 rounded-xl shadow-2xl w-full max-w-5xl max-h-[90vh] flex flex-col overflow-hidden"
    >
      <!-- Header -->
      <div
        class="flex items-center justify-between px-6 py-4 border-b border-slate-200 dark:border-slate-700 shrink-0"
      >
        <div class="flex items-center gap-3">
          <span class="i-lucide-diff size-5 text-violet-500" />
          <div>
            <h3
              class="text-base font-semibold text-slate-800 dark:text-slate-100"
            >
              Comparação de versões
            </h3>
            <p class="text-[11px] mt-0.5">
              <span v-if="changedCount === 0" class="text-emerald-500"
                >Versões idênticas</span
              >
              <span v-else class="text-amber-500">
                {{ changedCount }} seção{{
                  changedCount > 1 ? 'ões' : ''
                }}
                alterada{{ changedCount > 1 ? 's' : '' }}
              </span>
            </p>
          </div>
        </div>
        <button
          class="p-1 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          @click="emit('close')"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>

      <!-- Column headers -->
      <div class="grid grid-cols-2 px-6 pt-4 pb-2 shrink-0">
        <div class="pr-3">
          <div class="flex items-center justify-between">
            <div>
              <p
                class="text-sm font-semibold text-violet-600 dark:text-violet-400"
              >
                {{ labelA || `v${versionA.version}` }}
              </p>
              <p class="text-[11px] text-slate-400">
                {{ versionA.created_by || 'Sistema' }} ·
                {{ formatDate(versionA.created_at) }}
              </p>
            </div>
            <button
              class="text-[11px] px-2.5 py-1 rounded border border-violet-300 text-violet-600 hover:bg-violet-50 dark:hover:bg-violet-900/20 transition-colors"
              @click="emit('restore', versionA)"
            >
              Restaurar
            </button>
          </div>
        </div>
        <div class="pl-3 border-l border-slate-200 dark:border-slate-700">
          <div class="flex items-center justify-between">
            <div>
              <p
                class="text-sm font-semibold text-slate-700 dark:text-slate-200"
              >
                {{ labelB || `v${versionB.version}` }}
              </p>
              <p class="text-[11px] text-slate-400">
                {{ versionB.created_by || 'Sistema' }} ·
                {{ formatDate(versionB.created_at) }}
              </p>
            </div>
            <button
              class="text-[11px] px-2.5 py-1 rounded border border-slate-300 text-slate-600 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"
              @click="emit('restore', versionB)"
            >
              Restaurar
            </button>
          </div>
        </div>
      </div>

      <!-- Diff body -->
      <div class="flex-1 overflow-y-auto px-6 pb-6 space-y-3">
        <div
          v-for="section in SECTIONS"
          :key="section.key"
          class="rounded-xl border overflow-hidden"
          :class="
            section.changed
              ? 'border-amber-200 dark:border-amber-800'
              : 'border-slate-200 dark:border-slate-700'
          "
        >
          <!-- Section title -->
          <div
            class="flex items-center gap-2 px-4 py-2 text-xs font-semibold"
            :class="
              section.changed
                ? 'bg-amber-50 dark:bg-amber-900/20 text-amber-700 dark:text-amber-300'
                : 'bg-slate-50 dark:bg-slate-800 text-slate-500 dark:text-slate-400'
            "
          >
            <span class="size-3.5" :class="section.icon" />
            {{ section.label }}
            <span
              v-if="section.changed"
              class="ml-auto text-[10px] font-normal opacity-70"
              >modificado</span
            >
            <span
              v-else
              class="ml-auto text-[10px] font-normal text-emerald-600 dark:text-emerald-400 opacity-80"
              >idêntico</span
            >
          </div>

          <!-- Side-by-side content -->
          <div
            class="grid grid-cols-2 divide-x divide-slate-100 dark:divide-slate-800"
          >
            <div
              class="p-4 text-[11px] font-mono leading-relaxed whitespace-pre-wrap break-words"
              :class="
                section.changed
                  ? 'text-amber-800 dark:text-amber-200 bg-amber-50/40 dark:bg-amber-900/10'
                  : 'text-slate-600 dark:text-slate-400'
              "
            >
              {{ section.renderA }}
            </div>
            <div
              class="p-4 text-[11px] font-mono leading-relaxed whitespace-pre-wrap break-words"
              :class="
                section.changed
                  ? 'text-slate-700 dark:text-slate-300'
                  : 'text-slate-600 dark:text-slate-400'
              "
            >
              {{ section.renderB }}
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
