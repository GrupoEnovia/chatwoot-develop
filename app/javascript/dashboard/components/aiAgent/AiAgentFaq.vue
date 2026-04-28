<script setup>
import { ref, computed, onMounted } from 'vue';
import aiAgentsAPI from '../../api/aiAgents';

const props = defineProps({
  agentId: { type: Number, required: true },
});

const faqs = ref([]);
const loading = ref(false);
const search = ref('');
const activeCategory = ref('all');
const showForm = ref(false);
const editingFaq = ref(null);
const importText = ref('');
const showImport = ref(false);

const CATEGORIES = [
  { value: 'faq', label: 'FAQ' },
  { value: 'objection', label: 'Objeção' },
  { value: 'context', label: 'Contexto' },
];

const form = ref({
  category: 'faq',
  situation: '',
  question: '',
  answer: '',
  active: true,
});

const filtered = computed(() => {
  let list = faqs.value;
  if (activeCategory.value !== 'all')
    list = list.filter(f => f.category === activeCategory.value);
  if (search.value.trim()) {
    const q = search.value.toLowerCase();
    list = list.filter(
      f =>
        f.question.toLowerCase().includes(q) ||
        f.answer.toLowerCase().includes(q)
    );
  }
  return list;
});

async function load() {
  loading.value = true;
  try {
    const { data } = await aiAgentsAPI.getFaqs(props.agentId);
    faqs.value = data.payload;
  } finally {
    loading.value = false;
  }
}

function openCreate() {
  editingFaq.value = null;
  form.value = {
    category: 'faq',
    situation: '',
    question: '',
    answer: '',
    active: true,
  };
  showForm.value = true;
}

function openEdit(faq) {
  editingFaq.value = faq;
  form.value = { ...faq };
  showForm.value = true;
}

async function save() {
  if (!form.value.question.trim() || !form.value.answer.trim()) return;
  if (editingFaq.value) {
    await aiAgentsAPI.updateFaq(props.agentId, editingFaq.value.id, form.value);
  } else {
    await aiAgentsAPI.createFaq(props.agentId, form.value);
  }
  showForm.value = false;
  await load();
}

async function remove(faq) {
  if (!window.confirm('Remover este item?')) return;
  await aiAgentsAPI.deleteFaq(props.agentId, faq.id);
  await load();
}

async function toggleActive(faq) {
  await aiAgentsAPI.updateFaq(props.agentId, faq.id, { active: !faq.active });
  faq.active = !faq.active;
}

async function runImport() {
  let rows;
  try {
    rows = JSON.parse(importText.value);
    if (!Array.isArray(rows)) throw new Error();
  } catch {
    alert('JSON inválido. Espera um array de objetos com question e answer.');
    return;
  }
  const { data } = await aiAgentsAPI.importFaqs(props.agentId, rows);
  alert(`${data.payload.imported} itens importados.`);
  showImport.value = false;
  importText.value = '';
  await load();
}

onMounted(load);

const importPlaceholder =
  '[{"question":"Qual o preço?","answer":"R$ 97/mês","category":"faq"}]';
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div class="flex gap-2">
        <button
          v-for="cat in [{ value: 'all', label: 'Todos' }, ...CATEGORIES]"
          :key="cat.value"
          class="px-3 py-1 rounded-full text-xs font-medium border transition-colors"
          :class="
            activeCategory === cat.value
              ? 'bg-woot-500 text-white border-woot-500'
              : 'bg-white dark:bg-slate-800 border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300'
          "
          @click="activeCategory = cat.value"
        >
          {{ cat.label }}
        </button>
      </div>
      <div class="flex gap-2">
        <input
          v-model="search"
          type="text"
          placeholder="Buscar..."
          class="border border-slate-300 dark:border-slate-600 rounded px-3 py-1.5 text-sm bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 w-48"
        />
        <button
          class="px-3 py-1.5 text-sm rounded border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-50"
          @click="showImport = true"
        >
          Importar JSON
        </button>
        <button
          class="px-3 py-1.5 text-sm rounded bg-woot-500 hover:bg-woot-600 text-white"
          @click="openCreate"
        >
          + Adicionar
        </button>
      </div>
    </div>

    <div v-if="loading" class="text-center py-8 text-slate-400">
      Carregando...
    </div>

    <div
      v-else-if="filtered.length === 0"
      class="text-center py-8 text-slate-400"
    >
      Nenhum item encontrado.
    </div>

    <div v-else class="flex flex-col gap-2">
      <div
        v-for="faq in filtered"
        :key="faq.id"
        class="border border-slate-200 dark:border-slate-700 rounded-lg p-4 bg-white dark:bg-slate-800"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-1">
              <span
                class="text-xs px-2 py-0.5 rounded-full font-medium"
                :class="{
                  'bg-blue-100 text-blue-700': faq.category === 'faq',
                  'bg-orange-100 text-orange-700': faq.category === 'objection',
                  'bg-green-100 text-green-700': faq.category === 'context',
                }"
                >{{
                  CATEGORIES.find(c => c.value === faq.category)?.label ||
                  faq.category
                }}</span
              >
              <span v-if="faq.situation" class="text-xs text-slate-400">{{
                faq.situation
              }}</span>
            </div>
            <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
              {{ faq.question }}
            </p>
            <p
              class="text-sm text-slate-500 dark:text-slate-400 mt-1 whitespace-pre-wrap"
            >
              {{ faq.answer }}
            </p>
          </div>
          <div class="flex items-center gap-2 shrink-0">
            <button
              :title="faq.active ? 'Desativar' : 'Ativar'"
              class="w-8 h-8 flex items-center justify-center rounded hover:bg-slate-100 dark:hover:bg-slate-700"
              @click="toggleActive(faq)"
            >
              <span :class="faq.active ? 'text-green-500' : 'text-slate-300'"
                >●</span
              >
            </button>
            <button
              title="Editar"
              class="w-8 h-8 flex items-center justify-center rounded hover:bg-slate-100 dark:hover:bg-slate-700 text-slate-500"
              @click="openEdit(faq)"
            >
              ✎
            </button>
            <button
              title="Remover"
              class="w-8 h-8 flex items-center justify-center rounded hover:bg-red-50 dark:hover:bg-red-900/20 text-red-400"
              @click="remove(faq)"
            >
              ✕
            </button>
          </div>
        </div>
      </div>
    </div>

    <div
      v-if="showForm"
      class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
      @click.self="showForm = false"
    >
      <div
        class="bg-white dark:bg-slate-900 rounded-xl shadow-xl w-full max-w-lg p-6 flex flex-col gap-4"
      >
        <h3 class="text-base font-semibold text-slate-800 dark:text-slate-100">
          {{ editingFaq ? 'Editar item' : 'Novo item' }}
        </h3>

        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-slate-600 dark:text-slate-400"
            >Categoria</label
          >
          <select
            v-model="form.category"
            class="border border-slate-300 dark:border-slate-600 rounded px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
          >
            <option
              v-for="cat in CATEGORIES"
              :key="cat.value"
              :value="cat.value"
            >
              {{ cat.label }}
            </option>
          </select>
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-slate-600 dark:text-slate-400"
            >Situação (opcional)</label
          >
          <input
            v-model="form.situation"
            type="text"
            placeholder="Ex: quando o cliente pergunta sobre preço"
            class="border border-slate-300 dark:border-slate-600 rounded px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
          />
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-slate-600 dark:text-slate-400"
            >Pergunta / Objeção *</label
          >
          <input
            v-model="form.question"
            type="text"
            placeholder="Ex: Qual o preço?"
            class="border border-slate-300 dark:border-slate-600 rounded px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
          />
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-slate-600 dark:text-slate-400"
            >Resposta *</label
          >
          <textarea
            v-model="form.answer"
            rows="4"
            placeholder="Resposta que o agente deve dar..."
            class="border border-slate-300 dark:border-slate-600 rounded px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 resize-none"
          />
        </div>

        <div class="flex items-center gap-2">
          <input id="faq-active" v-model="form.active" type="checkbox" />
          <label
            for="faq-active"
            class="text-sm text-slate-700 dark:text-slate-300"
            >Ativo</label
          >
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <button
            class="px-4 py-2 text-sm rounded border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300"
            @click="showForm = false"
          >
            Cancelar
          </button>
          <button
            class="px-4 py-2 text-sm rounded bg-woot-500 hover:bg-woot-600 text-white"
            @click="save"
          >
            Salvar
          </button>
        </div>
      </div>
    </div>

    <div
      v-if="showImport"
      class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
      @click.self="showImport = false"
    >
      <div
        class="bg-white dark:bg-slate-900 rounded-xl shadow-xl w-full max-w-lg p-6 flex flex-col gap-4"
      >
        <h3 class="text-base font-semibold text-slate-800 dark:text-slate-100">
          Importar FAQ via JSON
        </h3>
        <p class="text-xs text-slate-500">
          Cole um array JSON com os campos: <code>question</code>,
          <code>answer</code>, <code>category</code> (opcional),
          <code>situation</code> (opcional).
        </p>
        <textarea
          v-model="importText"
          rows="8"
          :placeholder="importPlaceholder"
          class="border border-slate-300 dark:border-slate-600 rounded px-3 py-2 text-xs font-mono bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 resize-none"
        />
        <div class="flex justify-end gap-2">
          <button
            class="px-4 py-2 text-sm rounded border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300"
            @click="showImport = false"
          >
            Cancelar
          </button>
          <button
            class="px-4 py-2 text-sm rounded bg-woot-500 hover:bg-woot-600 text-white"
            @click="runImport"
          >
            Importar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
