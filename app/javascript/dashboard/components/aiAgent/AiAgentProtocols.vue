<script setup>
import { ref, onMounted } from 'vue';
import aiAgentsAPI from '../../api/aiAgents';

const props = defineProps({
  agentId: { type: Number, required: true },
});

const protocols = ref([]);
const loading = ref(false);
const showForm = ref(false);
const editingProtocol = ref(null);

const PROTOCOL_TYPES = [
  { value: 'human', label: 'Transferir para humano' },
  { value: 'qualified', label: 'Lead qualificado' },
  { value: 'meeting', label: 'Agendar reunião' },
  { value: 'unqualified', label: 'Lead desqualificado' },
  { value: 'custom', label: 'Personalizado' },
];

const emptyForm = () => ({
  protocol_type: 'human',
  label: '',
  keyword: '',
  phone_number: '',
  auto_summarize: true,
  position: protocols.value.length + 1,
});

const form = ref(emptyForm());

async function load() {
  loading.value = true;
  try {
    const { data } = await aiAgentsAPI.getProtocols(props.agentId);
    protocols.value = data.payload;
  } finally {
    loading.value = false;
  }
}

function openCreate() {
  editingProtocol.value = null;
  form.value = emptyForm();
  showForm.value = true;
}

function openEdit(p) {
  editingProtocol.value = p;
  form.value = { ...p };
  showForm.value = true;
}

async function save() {
  if (!form.value.label.trim() || !form.value.keyword.trim()) return;
  if (editingProtocol.value) {
    await aiAgentsAPI.updateProtocol(
      props.agentId,
      editingProtocol.value.id,
      form.value
    );
  } else {
    await aiAgentsAPI.createProtocol(props.agentId, form.value);
  }
  showForm.value = false;
  await load();
}

async function remove(p) {
  if (!window.confirm('Remover este protocolo?')) return;
  await aiAgentsAPI.deleteProtocol(props.agentId, p.id);
  await load();
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center justify-between">
      <div>
        <h3 class="text-sm font-semibold text-slate-800 dark:text-slate-100">
          Protocolos de Saída
        </h3>
        <p class="text-xs text-slate-500 mt-0.5">
          Palavras-chave que o agente detecta para acionar ações específicas.
        </p>
      </div>
      <button
        class="px-3 py-1.5 text-sm rounded bg-woot-500 hover:bg-woot-600 text-white"
        @click="openCreate"
      >
        + Adicionar
      </button>
    </div>

    <div v-if="loading" class="text-center py-8 text-slate-400">
      Carregando...
    </div>

    <div
      v-else-if="protocols.length === 0"
      class="text-center py-8 text-slate-400"
    >
      Nenhum protocolo configurado.
    </div>

    <div v-else class="flex flex-col gap-2">
      <div
        v-for="p in protocols"
        :key="p.id"
        class="border border-slate-200 dark:border-slate-700 rounded-lg p-4 bg-white dark:bg-slate-800 flex items-start justify-between gap-3"
      >
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2 mb-1 flex-wrap">
            <span
              class="text-xs px-2 py-0.5 rounded-full font-medium bg-purple-100 text-purple-700"
            >
              {{
                PROTOCOL_TYPES.find(t => t.value === p.protocol_type)?.label ||
                p.protocol_type
              }}
            </span>
            <span
              class="text-xs font-mono bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 px-2 py-0.5 rounded"
            >
              "{{ p.keyword }}"
            </span>
          </div>
          <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
            {{ p.label }}
          </p>
          <div class="flex gap-4 mt-1">
            <span v-if="p.phone_number" class="text-xs text-slate-500"
              >📞 {{ p.phone_number }}</span
            >
            <span class="text-xs text-slate-500">
              Resumo automático: {{ p.auto_summarize ? 'sim' : 'não' }}
            </span>
          </div>
        </div>
        <div class="flex gap-2 shrink-0">
          <button
            class="w-8 h-8 flex items-center justify-center rounded hover:bg-slate-100 dark:hover:bg-slate-700 text-slate-500"
            @click="openEdit(p)"
          >
            ✎
          </button>
          <button
            class="w-8 h-8 flex items-center justify-center rounded hover:bg-red-50 dark:hover:bg-red-900/20 text-red-400"
            @click="remove(p)"
          >
            ✕
          </button>
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
          {{ editingProtocol ? 'Editar protocolo' : 'Novo protocolo' }}
        </h3>

        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-slate-600 dark:text-slate-400"
            >Tipo</label
          >
          <select
            v-model="form.protocol_type"
            class="border border-slate-300 dark:border-slate-600 rounded px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
          >
            <option v-for="t in PROTOCOL_TYPES" :key="t.value" :value="t.value">
              {{ t.label }}
            </option>
          </select>
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-slate-600 dark:text-slate-400"
            >Nome do protocolo *</label
          >
          <input
            v-model="form.label"
            type="text"
            placeholder="Ex: Transferir para vendas"
            class="border border-slate-300 dark:border-slate-600 rounded px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
          />
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-slate-600 dark:text-slate-400"
            >Palavra-chave *</label
          >
          <input
            v-model="form.keyword"
            type="text"
            placeholder="Ex: #HUMANO"
            class="border border-slate-300 dark:border-slate-600 rounded px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
          />
          <p class="text-xs text-slate-400">
            O agente deve incluir esta palavra em sua resposta para acionar o
            protocolo.
          </p>
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-slate-600 dark:text-slate-400"
            >Telefone de notificação (opcional)</label
          >
          <input
            v-model="form.phone_number"
            type="text"
            placeholder="+5511999999999"
            class="border border-slate-300 dark:border-slate-600 rounded px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
          />
        </div>

        <div class="flex items-center gap-2">
          <input
            id="proto-summarize"
            v-model="form.auto_summarize"
            type="checkbox"
          />
          <label
            for="proto-summarize"
            class="text-sm text-slate-700 dark:text-slate-300"
          >
            Gerar resumo automático ao acionar
          </label>
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
  </div>
</template>
