<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
import { useMapGetter, useFunctionGetter } from 'dashboard/composables/store';
import KanbanCardModal from './KanbanCardModal.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

// ─── Current chat contact ─────────────────────────────────────────────────────
const currentChat = useMapGetter('getSelectedChat');
const contactGetter = useFunctionGetter('contacts/getContact');
const contactId = computed(() => currentChat.value?.meta?.sender?.id);
const contact = computed(() =>
  contactId.value ? contactGetter.value(contactId.value) : null
);

const store = useStore();

const loading = ref(false);
const showAddModal = ref(false);
const addForm = ref({
  pipeline_id: null,
  stage_id: null,
  title: '',
  value: '',
  contact_phone: '',
});
const saving = ref(false);

// Per-item action state
const activeAction = ref(null); // { itemId, type: 'move' | 'agent' }
const movingItemId = ref(null);
const assigningItemId = ref(null);
const statusItemId = ref(null);
const selectedAgentId = ref(null);
const localStagesForMove = ref([]); // local copy of stages for move panel

// Detail modal
const detailItem = ref(null);
const showDetailModal = ref(false);

const conversationItems = computed(
  () => store.getters['kanban/getConversationItems']
);
const pipelines = computed(() => store.getters['kanban/getPipelines']);
const allStages = computed(() => store.getters['kanban/getStages']);
const agents = computed(() => store.getters['agents/getAgents'] || []);

const selectedPipelineStages = computed(() => {
  if (!addForm.value.pipeline_id) return [];
  return allStages.value.filter(
    s => s.pipeline_id === addForm.value.pipeline_id
  );
});

function stagesForPipeline() {
  return localStagesForMove.value;
}

async function loadData() {
  loading.value = true;
  try {
    if (!pipelines.value.length) {
      await store.dispatch('kanban/fetchPipelines');
    }
    if (!agents.value.length) {
      await store.dispatch('agents/get');
    }
    await store.dispatch(
      'kanban/fetchItemsByConversation',
      props.conversationId
    );
  } finally {
    loading.value = false;
  }
}

watch(
  () => props.conversationId,
  () => loadData(),
  { immediate: true }
);

watch(
  () => addForm.value.pipeline_id,
  async pid => {
    addForm.value.stage_id = null;
    if (pid) {
      await store.dispatch('kanban/fetchStages', pid);
      const stages = allStages.value.filter(s => s.pipeline_id === pid);
      if (stages.length) addForm.value.stage_id = stages[0].id;
    }
  }
);

// Conversation's current assignee (agent)
const conversationAssignee = computed(
  () => currentChat.value?.meta?.assignee || null
);

function openAddModal() {
  const defaultPipeline =
    pipelines.value.find(p => p.is_default) || pipelines.value[0];
  // Auto-fill from current conversation contact
  const contactName = contact.value?.name || '';
  const contactPhone = contact.value?.phone_number || '';
  addForm.value = {
    pipeline_id: defaultPipeline?.id || null,
    stage_id: null,
    title: contactName,
    value: '',
    contact_phone: contactPhone,
  };
  showAddModal.value = true;
}

async function addToKanban() {
  if (
    !addForm.value.title.trim() ||
    !addForm.value.pipeline_id ||
    !addForm.value.stage_id
  )
    return;
  saving.value = true;
  try {
    await store.dispatch('kanban/createItem', {
      pipelineId: addForm.value.pipeline_id,
      stage_id: addForm.value.stage_id,
      title: addForm.value.title.trim(),
      conversation_id: props.conversationId,
      value: addForm.value.value || undefined,
      contact_phone: addForm.value.contact_phone || undefined,
      // Auto-assign to conversation's current agent
      assignee_id: conversationAssignee.value?.id || undefined,
    });
    showAddModal.value = false;
    await store.dispatch(
      'kanban/fetchItemsByConversation',
      props.conversationId
    );
  } finally {
    saving.value = false;
  }
}

// ─── Move action ───────────────────────────────────────────────────────────────

async function openMovePanel(item) {
  if (
    activeAction.value?.itemId === item.id &&
    activeAction.value?.type === 'move'
  ) {
    activeAction.value = null;
    return;
  }
  activeAction.value = { itemId: item.id, type: 'move' };
  localStagesForMove.value = [];
  await store.dispatch('kanban/fetchStages', item.pipeline_id);
  // Capture immediately after fetch - use store state directly
  localStagesForMove.value = allStages.value.filter(
    s => s.pipeline_id === item.pipeline_id
  );
}

async function moveToStage(item, stageId) {
  if (stageId === item.stage_id) {
    activeAction.value = null;
    return;
  }
  movingItemId.value = item.id;
  try {
    await store.dispatch('kanban/moveItem', {
      pipelineId: item.pipeline_id,
      id: item.id,
      stageId,
    });
    await store.dispatch(
      'kanban/fetchItemsByConversation',
      props.conversationId
    );
  } finally {
    movingItemId.value = null;
    activeAction.value = null;
  }
}

// ─── Agent action ──────────────────────────────────────────────────────────────

function openAgentPanel(item) {
  if (
    activeAction.value?.itemId === item.id &&
    activeAction.value?.type === 'agent'
  ) {
    activeAction.value = null;
    return;
  }
  activeAction.value = { itemId: item.id, type: 'agent' };
  selectedAgentId.value = item.assignee?.id || null;
}

async function assignAgent(item) {
  assigningItemId.value = item.id;
  try {
    await store.dispatch('kanban/updateItem', {
      pipelineId: item.pipeline_id,
      id: item.id,
      assignee_id: selectedAgentId.value || null,
    });
    await store.dispatch(
      'kanban/fetchItemsByConversation',
      props.conversationId
    );
  } finally {
    assigningItemId.value = null;
    activeAction.value = null;
  }
}

// ─── Status action ─────────────────────────────────────────────────────────────

function openStatusMenu(item) {
  statusItemId.value = statusItemId.value === item.id ? null : item.id;
  activeAction.value = null;
}

async function changeStatus(item, action) {
  statusItemId.value = null;
  if (action === 'won') {
    await store.dispatch('kanban/markItemWon', {
      pipelineId: item.pipeline_id,
      id: item.id,
    });
  } else if (action === 'lost') {
    await store.dispatch('kanban/markItemLost', {
      pipelineId: item.pipeline_id,
      id: item.id,
    });
  } else if (action === 'reopen') {
    await store.dispatch('kanban/reopenItem', {
      pipelineId: item.pipeline_id,
      id: item.id,
    });
  }
  await store.dispatch('kanban/fetchItemsByConversation', props.conversationId);
}

// ─── Details modal ─────────────────────────────────────────────────────────────

async function openDetails(item) {
  activeAction.value = null;
  statusItemId.value = null;
  // Fetch full item for the modal
  const full = await store.dispatch('kanban/fetchItem', {
    pipelineId: item.pipeline_id,
    id: item.id,
  });
  detailItem.value = full || item;
  showDetailModal.value = true;
}

function onDetailUpdated() {
  store.dispatch('kanban/fetchItemsByConversation', props.conversationId);
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

function formatValue(val) {
  if (!val || val === '0.0') return null;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  }).format(val);
}

function timeInStage(ts) {
  if (!ts) return null;
  const secs = Math.floor(Date.now() / 1000) - ts;
  if (secs < 3600) return `${Math.floor(secs / 60)}m`;
  if (secs < 86400) return `${Math.floor(secs / 3600)}h`;
  return `${Math.floor(secs / 86400)}d`;
}

const TEMPERATURE_MAP = {
  cold: { emoji: '❄️', label: 'Frio', cls: 'text-blue-500' },
  warm: { emoji: '🌡', label: 'Morno', cls: 'text-amber-500' },
  hot: { emoji: '🔥', label: 'Quente', cls: 'text-orange-500' },
  very_hot: { emoji: '💥', label: 'Muito Quente', cls: 'text-red-500' },
};

const STATUS_LABELS = {
  open: { label: 'Aberto', cls: 'text-slate-500 bg-slate-100' },
  won: { label: '🏆 Ganho', cls: 'text-green-700 bg-green-50' },
  lost: { label: '❌ Perdido', cls: 'text-red-700 bg-red-50' },
};
</script>

<template>
  <div class="p-3 space-y-2">
    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-6">
      <span class="i-lucide-loader-circle size-5 animate-spin text-woot-500" />
    </div>

    <!-- Items list -->
    <template v-else-if="conversationItems.length > 0">
      <div
        v-for="item in conversationItems"
        :key="item.id"
        class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl overflow-hidden"
        :style="{ borderLeftColor: item.stage_color, borderLeftWidth: '3px' }"
      >
        <!-- Card body -->
        <div class="p-3 space-y-2">
          <!-- Title + status -->
          <div class="flex items-start justify-between gap-2">
            <p
              class="text-sm font-semibold text-slate-800 dark:text-slate-100 leading-snug flex-1 min-w-0 truncate"
            >
              {{ item.title }}
            </p>
            <span
              class="shrink-0 text-[10px] font-semibold px-1.5 py-0.5 rounded-full"
              :class="STATUS_LABELS[item.status]?.cls || STATUS_LABELS.open.cls"
            >
              {{ STATUS_LABELS[item.status]?.label || 'Aberto' }}
            </span>
          </div>

          <!-- Funil + Etapa -->
          <div class="flex flex-wrap items-center gap-1.5">
            <span
              class="text-[10px] text-slate-400 dark:text-slate-500 truncate max-w-[80px]"
            >
              {{ item.pipeline_name }}
            </span>
            <span class="text-slate-300 dark:text-slate-600">›</span>
            <span
              class="text-[10px] font-medium px-1.5 py-0.5 rounded text-white shrink-0"
              :style="{ backgroundColor: item.stage_color }"
            >
              {{ item.stage_name }}
            </span>
          </div>

          <!-- Metrics row -->
          <div
            class="flex items-center gap-3 text-[10px] text-slate-500 dark:text-slate-400"
          >
            <!-- Time in stage -->
            <span class="flex items-center gap-0.5">
              <span class="i-lucide-clock size-3" />
              {{ timeInStage(item.stage_changed_at) }}
            </span>
            <!-- Temperature -->
            <span
              v-if="item.temperature && TEMPERATURE_MAP[item.temperature]"
              :class="TEMPERATURE_MAP[item.temperature].cls"
            >
              {{ TEMPERATURE_MAP[item.temperature].emoji }}
              {{ TEMPERATURE_MAP[item.temperature].label }}
            </span>
            <!-- Value -->
            <span
              v-if="formatValue(item.value)"
              class="ml-auto font-semibold text-woot-600 dark:text-woot-400 text-xs"
            >
              {{ formatValue(item.value) }}
            </span>
          </div>

          <!-- Assignee -->
          <div v-if="item.assignee" class="flex items-center gap-1.5">
            <img
              v-if="item.assignee.avatar_url"
              :src="item.assignee.avatar_url"
              class="size-4 rounded-full"
              :alt="item.assignee.name"
            />
            <span v-else class="i-lucide-user size-3 text-slate-400" />
            <span class="text-[10px] text-slate-500 dark:text-slate-400">{{
              item.assignee.name
            }}</span>
          </div>
          <div
            v-else
            class="flex items-center gap-1 text-[10px] text-slate-400 italic"
          >
            <span class="i-lucide-user size-3" /> Sem responsável
          </div>
        </div>

        <!-- Action bar -->
        <div
          class="flex items-center border-t border-slate-100 dark:border-slate-700 divide-x divide-slate-100 dark:divide-slate-700"
        >
          <!-- Move -->
          <button
            class="flex-1 flex items-center justify-center gap-1 py-1.5 text-[10px] font-medium transition-colors"
            :class="
              activeAction?.itemId === item.id && activeAction?.type === 'move'
                ? 'bg-woot-50 text-woot-600 dark:bg-woot-900/30'
                : 'text-slate-500 hover:bg-slate-50 dark:hover:bg-slate-700/50'
            "
            @click="openMovePanel(item)"
          >
            <span class="i-lucide-move-right size-3" />
            Mover
          </button>
          <!-- Responsável -->
          <button
            class="flex-1 flex items-center justify-center gap-1 py-1.5 text-[10px] font-medium transition-colors"
            :class="
              activeAction?.itemId === item.id && activeAction?.type === 'agent'
                ? 'bg-woot-50 text-woot-600 dark:bg-woot-900/30'
                : 'text-slate-500 hover:bg-slate-50 dark:hover:bg-slate-700/50'
            "
            @click="openAgentPanel(item)"
          >
            <span class="i-lucide-user-check size-3" />
            Resp.
          </button>
          <!-- Detalhes -->
          <button
            class="flex-1 flex items-center justify-center gap-1 py-1.5 text-[10px] font-medium text-slate-500 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
            @click="openDetails(item)"
          >
            <span class="i-lucide-external-link size-3" />
            Detalhes
          </button>
          <!-- Status menu -->
          <div class="relative">
            <button
              class="flex items-center justify-center px-2 py-1.5 text-slate-400 hover:text-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
              @click="openStatusMenu(item)"
            >
              <span class="i-lucide-more-vertical size-3" />
            </button>
            <!-- Dropdown -->
            <div
              v-if="statusItemId === item.id"
              class="absolute right-0 bottom-full mb-1 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg shadow-lg z-50 w-36 py-1"
            >
              <button
                v-if="item.status !== 'won'"
                class="w-full text-left px-3 py-1.5 text-xs text-green-700 hover:bg-green-50 dark:hover:bg-green-900/20 flex items-center gap-2"
                @click="changeStatus(item, 'won')"
              >
                <span class="i-lucide-trophy size-3" /> Marcar Ganho
              </button>
              <button
                v-if="item.status !== 'lost'"
                class="w-full text-left px-3 py-1.5 text-xs text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 flex items-center gap-2"
                @click="changeStatus(item, 'lost')"
              >
                <span class="i-lucide-x-circle size-3" /> Marcar Perdido
              </button>
              <button
                v-if="item.status !== 'open'"
                class="w-full text-left px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700/50 flex items-center gap-2"
                @click="changeStatus(item, 'reopen')"
              >
                <span class="i-lucide-rotate-ccw size-3" /> Reabrir
              </button>
            </div>
          </div>
        </div>

        <!-- Move panel -->
        <div
          v-if="
            activeAction?.itemId === item.id && activeAction?.type === 'move'
          "
          class="border-t border-slate-100 dark:border-slate-700 p-2"
        >
          <p
            class="text-[10px] text-slate-400 mb-1.5 font-medium uppercase tracking-wide"
          >
            Mover para etapa
          </p>
          <div class="flex flex-col gap-1">
            <div
              v-if="!localStagesForMove.length"
              class="text-xs text-slate-400 text-center py-2 flex items-center justify-center gap-1.5"
            >
              <span class="i-lucide-loader-circle size-3 animate-spin" />
              Carregando...
            </div>
            <button
              v-for="stage in stagesForPipeline()"
              :key="stage.id"
              class="flex items-center gap-2 px-2 py-1.5 rounded-lg text-xs font-medium transition-colors text-left"
              :class="
                stage.id === item.stage_id
                  ? 'bg-slate-100 dark:bg-slate-700 text-slate-400 cursor-default'
                  : 'hover:bg-slate-50 dark:hover:bg-slate-700/60 text-slate-700 dark:text-slate-300'
              "
              :disabled="stage.id === item.stage_id || movingItemId === item.id"
              @click="moveToStage(item, stage.id)"
            >
              <span
                class="size-2 rounded-full shrink-0"
                :style="{ backgroundColor: stage.color }"
              />
              {{ stage.name }}
              <span
                v-if="stage.id === item.stage_id"
                class="ml-auto text-[10px] text-slate-400"
                >atual</span
              >
              <span
                v-if="movingItemId === item.id && stage.id !== item.stage_id"
                class="ml-auto"
              >
                <span class="i-lucide-loader-circle size-3 animate-spin" />
              </span>
            </button>
          </div>
        </div>

        <!-- Agent panel -->
        <div
          v-if="
            activeAction?.itemId === item.id && activeAction?.type === 'agent'
          "
          class="border-t border-slate-100 dark:border-slate-700 p-2"
        >
          <p
            class="text-[10px] text-slate-400 mb-1.5 font-medium uppercase tracking-wide"
          >
            Responsável
          </p>
          <select
            v-model="selectedAgentId"
            class="w-full text-xs border border-slate-200 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500 mb-2"
          >
            <option :value="null">Sem responsável</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
          <div class="flex gap-1.5 justify-end">
            <button
              class="text-[10px] px-2.5 py-1 rounded-lg border border-slate-300 text-slate-600 hover:bg-slate-50 font-medium"
              @click="activeAction = null"
            >
              Cancelar
            </button>
            <button
              class="text-[10px] px-3 py-1 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium"
              :disabled="assigningItemId === item.id"
              @click="assignAgent(item)"
            >
              {{ assigningItemId === item.id ? '...' : 'Salvar' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Add another -->
      <button
        class="w-full flex items-center justify-center gap-1.5 text-xs px-3 py-2 rounded-lg border border-dashed border-slate-300 dark:border-slate-600 text-slate-500 hover:border-woot-400 hover:text-woot-500 transition-colors font-medium"
        @click="openAddModal"
      >
        <span class="i-lucide-plus size-3.5" />
        Adicionar a outro Kanban
      </button>
    </template>

    <!-- Empty state -->
    <div v-else class="text-center py-4">
      <span
        class="i-lucide-kanban size-8 text-slate-300 dark:text-slate-600 mb-2 block mx-auto"
      />
      <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
        Esta conversa não está no Kanban
      </p>
      <button
        class="w-full flex items-center justify-center gap-2 text-xs px-3 py-2 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium transition-colors"
        @click="openAddModal"
      >
        <span class="i-lucide-plus size-3.5" />
        Adicionar ao Kanban
      </button>
    </div>

    <!-- Add modal -->
    <div
      v-if="showAddModal"
      class="fixed inset-0 z-[60] flex items-center justify-center bg-black/40"
      @click.self="showAddModal = false"
    >
      <div
        class="bg-white dark:bg-slate-800 rounded-xl shadow-xl w-full max-w-sm mx-4 overflow-hidden"
      >
        <div
          class="flex items-center justify-between px-5 py-4 border-b border-slate-100 dark:border-slate-700"
        >
          <h3 class="text-sm font-semibold text-slate-800 dark:text-slate-100">
            Adicionar ao Kanban
          </h3>
          <button
            class="text-slate-400 hover:text-slate-600"
            @click="showAddModal = false"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>
        <div class="px-5 py-4 space-y-3">
          <div>
            <label
              class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
              >Título *</label
            >
            <input
              v-model="addForm.title"
              type="text"
              placeholder="Nome do negócio..."
              class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              autofocus
            />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label
                class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                >Pipeline *</label
              >
              <select
                v-model="addForm.pipeline_id"
                class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              >
                <option :value="null">Selecionar</option>
                <option v-for="p in pipelines" :key="p.id" :value="p.id">
                  {{ p.name }}
                </option>
              </select>
            </div>
            <div>
              <label
                class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                >Etapa *</label
              >
              <select
                v-model="addForm.stage_id"
                class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              >
                <option :value="null">Selecionar</option>
                <option
                  v-for="s in selectedPipelineStages"
                  :key="s.id"
                  :value="s.id"
                >
                  {{ s.name }}
                </option>
              </select>
            </div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label
                class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                >Valor (R$)</label
              >
              <input
                v-model="addForm.value"
                type="number"
                min="0"
                step="0.01"
                placeholder="0,00"
                class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              />
            </div>
            <div>
              <label
                class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                >Telefone</label
              >
              <input
                v-model="addForm.contact_phone"
                type="text"
                placeholder="+55..."
                class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              />
            </div>
          </div>
        </div>
        <div
          class="px-5 py-3 bg-slate-50 dark:bg-slate-900 flex justify-end gap-2"
        >
          <button
            class="text-xs px-3 py-1.5 rounded-lg border border-slate-300 text-slate-600 hover:bg-slate-100 font-medium"
            @click="showAddModal = false"
          >
            Cancelar
          </button>
          <button
            :disabled="
              !addForm.title.trim() ||
              !addForm.pipeline_id ||
              !addForm.stage_id ||
              saving
            "
            class="text-xs px-4 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium disabled:opacity-50"
            @click="addToKanban"
          >
            {{ saving ? 'Adicionando...' : 'Adicionar' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Detail modal -->
    <KanbanCardModal
      v-if="showDetailModal && detailItem"
      :item="detailItem"
      :pipeline-id="detailItem.pipeline_id"
      @close="showDetailModal = false"
      @updated="onDetailUpdated"
    />
  </div>
</template>
