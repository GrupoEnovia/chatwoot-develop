<!-- eslint-disable vue/no-bare-strings-in-template, prettier/prettier -->
<script setup>
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useStore } from 'vuex';
import aiAgentsAPI from '../../../../api/aiAgents';

const importInput = ref(null);
const importErr   = ref(null);

const router = useRouter();
const store = useStore();
const agents = ref([]);
const loading = ref(false);
const showCreate = ref(false);
const creating = ref(false);
const createError = ref(null);

const TIMEZONES = [
  'America/Sao_Paulo',
  'America/Manaus',
  'America/Belem',
  'America/Fortaleza',
  'America/Recife',
  'America/Cuiaba',
  'America/Porto_Velho',
  'America/Rio_Branco',
  'America/Noronha',
  'UTC',
];

const form = ref({
  name: '',
  company: '',
  language: 'pt-BR',
  timezone: 'America/Sao_Paulo',
  inbox_id: null,
  message_buffer_seconds: 20,
});

const inboxes = ref([]);

onMounted(async () => {
  loading.value = true;
  try {
    const [agentsRes] = await Promise.all([
      aiAgentsAPI.getAll(),
      store.dispatch('inboxes/get'),
    ]);
    agents.value = agentsRes.data?.payload || [];
    inboxes.value = store.getters['inboxes/getInboxes'] || [];
  } finally {
    loading.value = false;
  }
});

function openCreate() {
  form.value = {
    name: '',
    company: '',
    language: 'pt-BR',
    timezone: 'America/Sao_Paulo',
    inbox_id: null,
    message_buffer_seconds: 20,
  };
  createError.value = null;
  showCreate.value = true;
}

async function submitCreate() {
  if (!form.value.name.trim()) {
    createError.value = 'Nome é obrigatório.';
    return;
  }
  creating.value = true;
  createError.value = null;
  try {
    const res = await aiAgentsAPI.create(form.value);
    const agent = res.data?.payload;
    agents.value.unshift(agent);
    showCreate.value = false;
    router.push({ name: 'ai_agents_detail', params: { agentId: agent.id } });
  } catch {
    createError.value = 'Erro ao criar agente. Tente novamente.';
  } finally {
    creating.value = false;
  }
}

function goToAgent(id) {
  router.push({ name: 'ai_agents_detail', params: { agentId: id } });
}

async function handleImport(e) {
  const file = e.target.files[0];
  if (!file) return;
  importErr.value = null;
  try {
    const text = await file.text();
    const data = JSON.parse(text);
    const res  = await aiAgentsAPI.importAgent(data);
    const agent = res.data?.payload;
    agents.value.unshift(agent);
    router.push({ name: 'ai_agents_detail', params: { agentId: agent.id } });
  } catch (err) {
    importErr.value = err.response?.data?.error || 'Erro ao importar agente.';
  } finally {
    e.target.value = '';
  }
}

async function toggleActive(agent) {
  try {
    const res = await aiAgentsAPI.update(agent.id, { active: !agent.active });
    const idx = agents.value.findIndex(a => a.id === agent.id);
    if (idx !== -1) agents.value[idx] = res.data.payload;
  } catch {
    /* noop */
  }
}
</script>

<template>
  <div class="p-6 max-w-4xl mx-auto">
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <div>
        <h1 class="text-lg font-semibold text-slate-800 dark:text-slate-100">
          Agentes de IA
        </h1>
        <p class="text-xs text-slate-400 mt-0.5">
          Configure agentes de IA para atendimento automático por inbox
        </p>
      </div>
      <div class="flex items-center gap-2">
        <span v-if="importErr" class="text-xs text-red-500">{{
          importErr
        }}</span>
        <label
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium border border-slate-200 dark:border-slate-700 text-slate-500 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors cursor-pointer"
        >
          <span class="i-lucide-upload size-3.5" /> Importar
          <input
            ref="importInput"
            type="file"
            accept=".json,application/json"
            class="hidden"
            @change="handleImport"
          />
        </label>
        <button
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-semibold bg-violet-600 hover:bg-violet-700 text-white rounded-lg transition-colors"
          @click="openCreate"
        >
          <span class="i-lucide-plus size-3.5" />
          Novo Agente
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <span class="i-lucide-loader-2 size-6 animate-spin text-slate-400" />
    </div>

    <!-- Empty state -->
    <div
      v-else-if="!agents.length"
      class="flex flex-col items-center justify-center py-20 text-center"
    >
      <span
        class="i-lucide-bot size-12 text-slate-200 dark:text-slate-700 mb-3"
      />
      <p class="text-sm font-medium text-slate-500">
        Nenhum agente criado ainda
      </p>
      <p class="text-xs text-slate-400 mt-1 mb-4">
        Crie seu primeiro agente de IA para começar
      </p>
      <button
        class="px-3 py-2 text-xs font-semibold bg-violet-600 hover:bg-violet-700 text-white rounded-lg transition-colors"
        @click="openCreate"
      >
        Criar agente
      </button>
    </div>

    <!-- Agent list -->
    <div v-else class="grid gap-3">
      <div
        v-for="agent in agents"
        :key="agent.id"
        class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-4 flex items-center justify-between hover:shadow-md transition-shadow cursor-pointer"
        @click="goToAgent(agent.id)"
      >
        <div class="flex items-center gap-3">
          <div
            class="w-10 h-10 rounded-full bg-violet-100 dark:bg-violet-900/30 flex items-center justify-center shrink-0"
          >
            <span
              class="i-lucide-bot size-5 text-violet-600 dark:text-violet-400"
            />
          </div>
          <div>
            <div class="flex items-center gap-2">
              <p
                class="text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ agent.name }}
              </p>
              <span
                class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full"
                :class="
                  agent.active
                    ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400'
                    : 'bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-400'
                "
              >
                {{ agent.active ? 'Ativo' : 'Inativo' }}
              </span>
            </div>
            <p class="text-xs text-slate-400 mt-0.5">
              {{ agent.company || 'Sem empresa' }} ·
              {{ agent.inbox?.name || 'Sem inbox' }} ·
              {{ agent.language }}
            </p>
          </div>
        </div>
        <div class="flex items-center gap-2" @click.stop>
          <button
            class="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 transition-colors"
            :title="agent.active ? 'Desativar' : 'Ativar'"
            @click="toggleActive(agent)"
          >
            <span
              :class="
                agent.active
                  ? 'i-lucide-toggle-right size-5 text-emerald-500'
                  : 'i-lucide-toggle-left size-5'
              "
            />
          </button>
          <button
            class="p-1.5 rounded-lg text-slate-400 hover:text-violet-600 transition-colors"
            @click="goToAgent(agent.id)"
          >
            <span class="i-lucide-settings size-4" />
          </button>
        </div>
      </div>
    </div>

    <!-- Create modal -->
    <Teleport to="body">
      <div
        v-if="showCreate"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm"
        @click.self="showCreate = false"
      >
        <div
          class="bg-white dark:bg-slate-900 rounded-2xl shadow-2xl w-full max-w-md mx-4"
        >
          <div
            class="flex items-center justify-between px-5 py-4 border-b border-slate-100 dark:border-slate-800"
          >
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              Novo Agente de IA
            </h3>
            <button
              class="text-slate-400 hover:text-slate-600"
              @click="showCreate = false"
            >
              <span class="i-lucide-x size-4" />
            </button>
          </div>

          <div class="px-5 py-4 space-y-4">
            <div>
              <label class="text-xs font-medium text-slate-500 mb-1.5 block"
                >Nome do agente *</label
              >
              <input
                v-model="form.name"
                type="text"
                placeholder="Ex: Sofia"
                class="w-full text-sm px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
              />
            </div>
            <div>
              <label class="text-xs font-medium text-slate-500 mb-1.5 block"
                >Empresa</label
              >
              <input
                v-model="form.company"
                type="text"
                placeholder="Ex: Volponi Advogados"
                class="w-full text-sm px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
              />
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="text-xs font-medium text-slate-500 mb-1.5 block"
                  >Idioma</label
                >
                <select
                  v-model="form.language"
                  class="w-full text-sm px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
                >
                  <option value="pt-BR">Português (BR)</option>
                  <option value="pt-PT">Português (PT)</option>
                  <option value="en">English</option>
                  <option value="es">Español</option>
                </select>
              </div>
              <div>
                <label class="text-xs font-medium text-slate-500 mb-1.5 block"
                  >Timezone</label
                >
                <select
                  v-model="form.timezone"
                  class="w-full text-sm px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
                >
                  <option v-for="tz in TIMEZONES" :key="tz" :value="tz">
                    {{ tz }}
                  </option>
                </select>
              </div>
            </div>
            <div>
              <label class="text-xs font-medium text-slate-500 mb-1.5 block"
                >Inbox vinculada</label
              >
              <select
                v-model="form.inbox_id"
                class="w-full text-sm px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
              >
                <option :value="null">Sem inbox (configurar depois)</option>
                <option
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  :value="inbox.id"
                >
                  {{ inbox.name }}
                </option>
              </select>
            </div>
            <div>
              <label class="text-xs font-medium text-slate-500 mb-1.5 block">
                Buffer de mensagens (segundos, mínimo 10)
              </label>
              <input
                v-model.number="form.message_buffer_seconds"
                type="number"
                min="10"
                max="300"
                class="w-full text-sm px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
              />
            </div>
            <p v-if="createError" class="text-xs text-red-500">
              {{ createError }}
            </p>
          </div>

          <div
            class="px-5 py-4 border-t border-slate-100 dark:border-slate-800 flex justify-end gap-2"
          >
            <button
              class="px-3 py-2 text-xs text-slate-500 hover:text-slate-700 transition-colors"
              @click="showCreate = false"
            >
              Cancelar
            </button>
            <button
              class="px-4 py-2 text-xs font-semibold bg-violet-600 hover:bg-violet-700 text-white rounded-lg transition-colors disabled:opacity-50"
              :disabled="creating"
              @click="submitCreate"
            >
              {{ creating ? 'Criando...' : 'Criar agente' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
