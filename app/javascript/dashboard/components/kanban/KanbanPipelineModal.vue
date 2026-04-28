<script setup>
import { ref, watch, computed } from 'vue';
import { useStore } from 'vuex';

const props = defineProps({
  pipeline: { type: Object, default: null },
});
const emit = defineEmits(['close', 'saved']);
const store = useStore();

const uiFlags = computed(() => store.getters['kanban/getUIFlags']);
const pipelines = computed(() => store.getters['kanban/getPipelines']);
const allStages = computed(() => store.getters['kanban/getStages']);

// ── Left panel — pipeline selection ──────────────────────────────────────────
const selectedPipeline = ref(props.pipeline);

watch(
  () => props.pipeline,
  p => {
    selectedPipeline.value = p;
  },
  { immediate: true }
);

const pipelineStages = computed(() =>
  allStages.value
    .filter(s => s.pipeline_id === selectedPipeline.value?.id)
    .sort((a, b) => a.position - b.position)
);

// ── Right panel — tabs ────────────────────────────────────────────────────────
const TABS = [
  { id: 'general', label: 'Geral', icon: 'i-lucide-settings' },
  { id: 'stages', label: 'Etapas', icon: 'i-lucide-columns' },
  { id: 'reasons', label: 'Motivos de Perda', icon: 'i-lucide-x-circle' },
];
const activeTab = ref('general');

// ── General tab form ──────────────────────────────────────────────────────────
const pipelineName = ref('');
const pipelineDescription = ref('');
const pipelineIsDefault = ref(false);
const pipelineIsActive = ref(true);
const autoResolveConversation = ref(false);

watch(
  selectedPipeline,
  p => {
    pipelineName.value = p?.name ?? '';
    pipelineDescription.value = p?.description ?? '';
    pipelineIsDefault.value = p?.is_default ?? false;
    pipelineIsActive.value = p?.is_active ?? true;
    autoResolveConversation.value =
      p?.settings?.auto_resolve_conversation ?? false;
    if (p?.id) {
      store.dispatch('kanban/fetchStages', p.id);
    }
    activeTab.value = 'general';
  },
  { immediate: true }
);

async function savePipelineGeneral() {
  if (!pipelineName.value.trim()) return;
  const d = {
    name: pipelineName.value.trim(),
    description: pipelineDescription.value.trim() || undefined,
    is_default: pipelineIsDefault.value,
    is_active: pipelineIsActive.value,
    settings: { auto_resolve_conversation: autoResolveConversation.value },
  };
  if (!selectedPipeline.value?.id) {
    const created = await store.dispatch('kanban/createPipeline', d);
    await store.dispatch('kanban/setActivePipeline', created.id);
    selectedPipeline.value = created;
  } else {
    await store.dispatch('kanban/updatePipeline', {
      id: selectedPipeline.value.id,
      ...d,
    });
    selectedPipeline.value = { ...selectedPipeline.value, ...d };
  }
  emit('saved');
}

async function deletePipeline() {
  if (
    !window.confirm(
      `Excluir pipeline "${selectedPipeline.value.name}"? Esta ação não pode ser desfeita.`
    )
  )
    return;
  await store.dispatch('kanban/deletePipeline', selectedPipeline.value.id);
  selectedPipeline.value = pipelines.value[0] || null;
}

// ── Stages tab ────────────────────────────────────────────────────────────────
const COLORS = [
  '#6366f1',
  '#0ea5e9',
  '#10b981',
  '#f59e0b',
  '#ef4444',
  '#8b5cf6',
  '#ec4899',
  '#22c55e',
  '#f97316',
  '#64748b',
];
const editingStageId = ref(null);
const stageEditForm = ref({});
const newStage = ref({
  name: '',
  color: '#6366f1',
  probability: 50,
  is_won: false,
  is_lost: false,
});
const saving = ref(false);
const draggingIdx = ref(null);

function startEditStage(stage) {
  editingStageId.value = stage.id;
  stageEditForm.value = { ...stage };
}
function cancelEditStage() {
  editingStageId.value = null;
}

async function saveEditStage() {
  if (!stageEditForm.value.name?.trim()) return;
  saving.value = true;
  try {
    await store.dispatch('kanban/updateStage', {
      pipelineId: selectedPipeline.value.id,
      id: stageEditForm.value.id,
      name: stageEditForm.value.name.trim(),
      color: stageEditForm.value.color,
      probability: parseInt(stageEditForm.value.probability, 10) || 0,
      is_won: stageEditForm.value.is_won,
      is_lost: stageEditForm.value.is_lost,
    });
    editingStageId.value = null;
  } finally {
    saving.value = false;
  }
}

async function deleteStage(stage) {
  if (!window.confirm(`Excluir etapa "${stage.name}"?`)) return;
  await store.dispatch('kanban/deleteStage', {
    pipelineId: selectedPipeline.value.id,
    id: stage.id,
  });
}

async function addNewStage() {
  if (!newStage.value.name.trim()) return;
  if (!selectedPipeline.value?.id) return;
  saving.value = true;
  try {
    await store.dispatch('kanban/createStage', {
      pipelineId: selectedPipeline.value.id,
      name: newStage.value.name.trim(),
      color: newStage.value.color,
      probability: parseInt(newStage.value.probability, 10) || 0,
      position: pipelineStages.value.length,
      is_won: newStage.value.is_won,
      is_lost: newStage.value.is_lost,
    });
    newStage.value = {
      name: '',
      color: '#6366f1',
      probability: 50,
      is_won: false,
      is_lost: false,
    };
  } finally {
    saving.value = false;
  }
}

// drag-to-reorder stages (simple, no lib)
function onStageDragStart(e, idx) {
  draggingIdx.value = idx;
  e.dataTransfer.effectAllowed = 'move';
}
function onStageDragOver(e, idx) {
  e.preventDefault();
  if (draggingIdx.value === null || draggingIdx.value === idx) return;
  const stages = [...pipelineStages.value];
  const dragged = stages.splice(draggingIdx.value, 1)[0];
  stages.splice(idx, 0, dragged);
  draggingIdx.value = idx;
  // reorder positions
  stages.forEach((s, i) => {
    store.dispatch('kanban/updateStage', {
      pipelineId: selectedPipeline.value.id,
      id: s.id,
      position: i,
    });
  });
}
function onStageDragEnd() {
  draggingIdx.value = null;
}

// ── Lost reasons management ───────────────────────────────────────────────────
const lostReasons = computed(() => store.getters['kanban/getLostReasons']);
const newReasonName = ref('');
const savingReason = ref(false);
const editingReasonId = ref(null);
const reasonEditForm = ref({ name: '', active: true });

watch(activeTab, tab => {
  if (tab === 'reasons') store.dispatch('kanban/fetchLostReasons');
});

async function addReason() {
  if (!newReasonName.value.trim()) return;
  savingReason.value = true;
  try {
    await store.dispatch('kanban/createLostReason', {
      name: newReasonName.value.trim(),
    });
    newReasonName.value = '';
  } finally {
    savingReason.value = false;
  }
}

function startEditReason(reason) {
  editingReasonId.value = reason.id;
  reasonEditForm.value = { name: reason.name, active: reason.active };
}

async function saveEditReason() {
  if (!reasonEditForm.value.name?.trim()) return;
  savingReason.value = true;
  try {
    await store.dispatch('kanban/updateLostReason', {
      id: editingReasonId.value,
      name: reasonEditForm.value.name.trim(),
      active: reasonEditForm.value.active,
    });
    editingReasonId.value = null;
  } finally {
    savingReason.value = false;
  }
}

async function deleteReason(id) {
  if (!window.confirm('Excluir este motivo de perda?')) return;
  await store.dispatch('kanban/deleteLostReason', id);
}

// ── Create new pipeline ───────────────────────────────────────────────────────
function createNewPipeline() {
  selectedPipeline.value = null;
  pipelineName.value = '';
  pipelineDescription.value = '';
  pipelineIsDefault.value = false;
  pipelineIsActive.value = true;
  activeTab.value = 'general';
}
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
    @click.self="emit('close')"
  >
    <div
      class="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-4xl h-[88vh] flex overflow-hidden"
    >
      <!-- ═══ LEFT PANEL — pipeline list ═══════════════════════════════════════ -->
      <div
        class="w-60 shrink-0 bg-slate-50 dark:bg-slate-900 border-r border-slate-200 dark:border-slate-700 flex flex-col"
      >
        <div class="px-4 py-4 border-b border-slate-200 dark:border-slate-700">
          <button
            class="w-full flex items-center justify-center gap-2 text-xs px-3 py-2 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium transition-colors"
            @click="createNewPipeline"
          >
            <span class="i-lucide-plus size-3.5" />
            Nova Pipeline
          </button>
        </div>

        <div class="flex-1 overflow-y-auto py-2">
          <button
            v-for="p in pipelines"
            :key="p.id"
            class="w-full flex items-center gap-2.5 px-4 py-2.5 text-sm transition-colors text-left"
            :class="
              selectedPipeline?.id === p.id
                ? 'bg-woot-50 dark:bg-woot-900/30 text-woot-600 dark:text-woot-400 font-medium'
                : 'text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800'
            "
            @click="selectedPipeline = p"
          >
            <span
              class="size-2 rounded-full shrink-0"
              :class="p.is_active ? 'bg-green-500' : 'bg-slate-400'"
            />
            <span class="flex-1 truncate">{{ p.name }}</span>
            <span
              v-if="p.is_default"
              class="text-[10px] text-woot-500 font-semibold"
              >padrão</span
            >
          </button>
          <div
            v-if="!pipelines.length"
            class="px-4 py-3 text-xs text-slate-400"
          >
            Nenhuma pipeline
          </div>
        </div>
      </div>

      <!-- ═══ RIGHT PANEL — edit / create ══════════════════════════════════════ -->
      <div class="flex-1 flex flex-col min-w-0 overflow-hidden">
        <!-- Header -->
        <div
          class="flex items-center justify-between px-6 py-4 border-b border-slate-200 dark:border-slate-700 shrink-0"
        >
          <h2
            class="text-base font-semibold text-slate-800 dark:text-slate-100"
          >
            {{
              selectedPipeline?.id
                ? `Configurar: ${selectedPipeline.name}`
                : 'Nova Pipeline'
            }}
          </h2>
          <button
            class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
            @click="emit('close')"
          >
            <span class="i-lucide-x size-5" />
          </button>
        </div>

        <!-- Tabs -->
        <div
          v-if="selectedPipeline?.id"
          class="flex border-b border-slate-200 dark:border-slate-700 shrink-0"
        >
          <button
            v-for="tab in TABS"
            :key="tab.id"
            class="flex items-center gap-1.5 px-5 py-3 text-sm font-medium border-b-2 transition-colors"
            :class="
              activeTab === tab.id
                ? 'border-woot-500 text-woot-600 dark:text-woot-400'
                : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700'
            "
            @click="activeTab = tab.id"
          >
            <span class="size-4" :class="[tab.icon]" />
            {{ tab.label }}
          </button>
        </div>

        <!-- Content area -->
        <div class="flex-1 overflow-y-auto p-6">
          <!-- ── GENERAL TAB ───────────────────────────────────────────────── -->
          <div v-if="activeTab === 'general'" class="max-w-md space-y-4">
            <div>
              <label
                class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                >Nome *</label
              >
              <input
                v-model="pipelineName"
                type="text"
                placeholder="Ex: Funil de Vendas"
                class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                autofocus
              />
            </div>
            <div>
              <label
                class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                >Descrição</label
              >
              <textarea
                v-model="pipelineDescription"
                rows="2"
                class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500 resize-none"
              />
            </div>
            <div class="flex items-center gap-6">
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  v-model="pipelineIsDefault"
                  type="checkbox"
                  class="rounded accent-woot-500"
                />
                <span class="text-sm text-slate-700 dark:text-slate-200"
                  >Funil padrão</span
                >
              </label>
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  v-model="pipelineIsActive"
                  type="checkbox"
                  class="rounded accent-woot-500"
                />
                <span class="text-sm text-slate-700 dark:text-slate-200"
                  >Ativo</span
                >
              </label>
            </div>
            <div
              class="border border-slate-200 dark:border-slate-700 rounded-lg p-3"
            >
              <p
                class="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2"
              >
                Automações
              </p>
              <label class="flex items-start gap-2.5 cursor-pointer">
                <input
                  v-model="autoResolveConversation"
                  type="checkbox"
                  class="rounded accent-woot-500 mt-0.5 shrink-0"
                />
                <div>
                  <span class="text-sm text-slate-700 dark:text-slate-200"
                    >Resolver conversa ao marcar Ganho/Perdido</span
                  >
                  <p class="text-xs text-slate-400 mt-0.5">
                    Resolve automaticamente a conversa vinculada ao lead
                  </p>
                </div>
              </label>
            </div>

            <div class="flex gap-2 pt-2">
              <button
                :disabled="
                  !pipelineName.trim() ||
                  uiFlags.isCreating ||
                  uiFlags.isUpdating
                "
                class="flex-1 px-4 py-2 rounded-lg bg-woot-500 text-white text-sm font-medium hover:bg-woot-600 disabled:opacity-50 transition-colors"
                @click="savePipelineGeneral"
              >
                {{ selectedPipeline?.id ? 'Salvar' : 'Criar Pipeline' }}
              </button>
            </div>

            <div
              v-if="selectedPipeline?.id"
              class="border-t border-slate-200 dark:border-slate-700 pt-4"
            >
              <button
                class="w-full px-4 py-2 rounded-lg border border-red-300 text-red-600 text-sm font-medium hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                @click="deletePipeline"
              >
                Excluir Funil
              </button>
            </div>
          </div>

          <!-- ── REASONS TAB ───────────────────────────────────────────────── -->
          <div v-else-if="activeTab === 'reasons'" class="max-w-md">
            <p
              class="text-xs text-slate-500 dark:text-slate-400 mb-4 leading-relaxed"
            >
              Motivos de perda são opções que o agente seleciona ao marcar um
              lead como Perdido. Esta lista é compartilhada em todos os funis.
            </p>

            <!-- Existing reasons -->
            <div class="space-y-1.5 mb-4">
              <template v-for="reason in lostReasons" :key="reason.id">
                <!-- Edit mode -->
                <div
                  v-if="editingReasonId === reason.id"
                  class="bg-white dark:bg-slate-700 border border-woot-300 dark:border-woot-600 rounded-xl p-3 space-y-2"
                >
                  <input
                    v-model="reasonEditForm.name"
                    type="text"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                    autofocus
                    @keyup.enter="saveEditReason"
                  />
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      v-model="reasonEditForm.active"
                      type="checkbox"
                      class="rounded accent-woot-500"
                    />
                    <span class="text-sm text-slate-600 dark:text-slate-300"
                      >Ativo</span
                    >
                  </label>
                  <div class="flex gap-2">
                    <button
                      class="px-3 py-1.5 rounded-lg text-xs border border-slate-300 text-slate-600 hover:bg-slate-100 font-medium"
                      @click="editingReasonId = null"
                    >
                      Cancelar
                    </button>
                    <button
                      :disabled="savingReason"
                      class="px-3 py-1.5 rounded-lg text-xs bg-woot-500 text-white hover:bg-woot-600 font-medium disabled:opacity-50"
                      @click="saveEditReason"
                    >
                      Salvar
                    </button>
                  </div>
                </div>

                <!-- Display mode -->
                <div
                  v-else
                  class="group flex items-center gap-2 bg-white dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-2.5"
                >
                  <span
                    class="i-lucide-x-circle size-4 text-red-400 shrink-0"
                  />
                  <span
                    class="flex-1 text-sm text-slate-700 dark:text-slate-200"
                    :class="{ 'opacity-50 line-through': !reason.active }"
                    >{{ reason.name }}</span
                  >
                  <span
                    v-if="!reason.active"
                    class="text-[10px] text-slate-400 bg-slate-100 dark:bg-slate-700 px-1.5 py-0.5 rounded"
                    >inativo</span
                  >
                  <div
                    class="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity"
                  >
                    <button
                      class="p-1 rounded text-slate-400 hover:text-woot-500 transition-colors"
                      @click="startEditReason(reason)"
                    >
                      <span class="i-lucide-pencil size-3.5" />
                    </button>
                    <button
                      class="p-1 rounded text-slate-400 hover:text-red-500 transition-colors"
                      @click="deleteReason(reason.id)"
                    >
                      <span class="i-lucide-trash-2 size-3.5" />
                    </button>
                  </div>
                </div>
              </template>

              <div
                v-if="lostReasons.length === 0"
                class="text-center py-4 text-xs text-slate-400"
              >
                Nenhum motivo cadastrado ainda.
              </div>
            </div>

            <!-- Add new reason -->
            <div
              class="border border-dashed border-slate-300 dark:border-slate-600 rounded-xl p-4 bg-slate-50 dark:bg-slate-900/40"
            >
              <p
                class="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2"
              >
                Adicionar Motivo
              </p>
              <div class="flex gap-2">
                <input
                  v-model="newReasonName"
                  type="text"
                  placeholder="Ex: Preço alto, Concorrente..."
                  class="flex-1 text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  @keyup.enter="addReason"
                />
                <button
                  :disabled="!newReasonName.trim() || savingReason"
                  class="flex items-center gap-1.5 text-sm px-3 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium disabled:opacity-50 transition-colors shrink-0"
                  @click="addReason"
                >
                  <span class="i-lucide-plus size-4" />
                  Adicionar
                </button>
              </div>
            </div>
          </div>

          <!-- ── STAGES TAB ────────────────────────────────────────────────── -->
          <div v-else-if="activeTab === 'stages'">
            <div class="flex items-center justify-between mb-3">
              <h3
                class="text-sm font-semibold text-slate-700 dark:text-slate-200"
              >
                Etapas
              </h3>
              <span class="text-xs text-slate-400 flex items-center gap-1">
                <span class="i-lucide-grip-vertical size-3.5" />
                Arraste para reordenar
              </span>
            </div>

            <!-- Stage list -->
            <div class="space-y-1 mb-4">
              <template v-for="(stage, idx) in pipelineStages" :key="stage.id">
                <!-- Edit mode -->
                <div
                  v-if="editingStageId === stage.id"
                  class="bg-white dark:bg-slate-700 border border-woot-300 dark:border-woot-600 rounded-xl p-4 shadow-sm"
                >
                  <div class="grid grid-cols-2 gap-3 mb-3">
                    <div>
                      <label
                        class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                        >Nome</label
                      >
                      <input
                        v-model="stageEditForm.name"
                        type="text"
                        class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                        autofocus
                      />
                    </div>
                    <div>
                      <label
                        class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                        >Probabilidade %</label
                      >
                      <input
                        v-model="stageEditForm.probability"
                        type="number"
                        min="0"
                        max="100"
                        class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                      />
                    </div>
                  </div>
                  <div class="mb-3">
                    <label
                      class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                      >Cor</label
                    >
                    <div class="flex gap-1.5 flex-wrap">
                      <button
                        v-for="color in COLORS"
                        :key="color"
                        class="size-5 rounded-full border-2 transition-transform hover:scale-110"
                        :style="{
                          backgroundColor: color,
                          borderColor:
                            stageEditForm.color === color
                              ? '#1e293b'
                              : 'transparent',
                        }"
                        @click="stageEditForm.color = color"
                      />
                      <input
                        v-model="stageEditForm.color"
                        type="color"
                        class="size-5 rounded cursor-pointer border border-slate-300"
                        title="Cor personalizada"
                      />
                    </div>
                  </div>
                  <div class="flex gap-4 mb-3">
                    <label class="flex items-center gap-2 cursor-pointer">
                      <input
                        v-model="stageEditForm.is_won"
                        type="checkbox"
                        class="rounded accent-green-500"
                      />
                      <span class="text-sm text-green-600 font-medium"
                        >Ganho</span
                      >
                    </label>
                    <label class="flex items-center gap-2 cursor-pointer">
                      <input
                        v-model="stageEditForm.is_lost"
                        type="checkbox"
                        class="rounded accent-red-500"
                      />
                      <span class="text-sm text-red-600 font-medium"
                        >Perdido</span
                      >
                    </label>
                  </div>
                  <div class="flex gap-2">
                    <button
                      class="px-3 py-1.5 rounded-lg text-xs border border-slate-300 text-slate-600 hover:bg-slate-100 font-medium"
                      @click="cancelEditStage"
                    >
                      Cancelar
                    </button>
                    <button
                      :disabled="saving"
                      class="px-3 py-1.5 rounded-lg text-xs bg-woot-500 text-white hover:bg-woot-600 font-medium disabled:opacity-50"
                      @click="saveEditStage"
                    >
                      Salvar
                    </button>
                  </div>
                </div>

                <!-- Display mode -->
                <div
                  v-else
                  class="flex items-center gap-2 bg-white dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-2.5 cursor-grab active:cursor-grabbing group"
                  draggable="true"
                  @dragstart="onStageDragStart($event, idx)"
                  @dragover="onStageDragOver($event, idx)"
                  @dragend="onStageDragEnd"
                >
                  <span
                    class="i-lucide-grip-vertical size-4 text-slate-400 shrink-0"
                  />
                  <span
                    class="size-3 rounded-full shrink-0"
                    :style="{ backgroundColor: stage.color }"
                  />
                  <div class="flex-1 min-w-0">
                    <span
                      class="text-sm font-medium text-slate-700 dark:text-slate-200"
                      >{{ stage.name }}</span
                    >
                    <span class="ml-2 text-xs text-slate-400"
                      >{{ stage.probability }}% probabilidade</span
                    >
                    <span
                      v-if="stage.is_won"
                      class="ml-1.5 text-[10px] font-semibold text-green-600 bg-green-50 dark:bg-green-900/30 px-1.5 py-0.5 rounded"
                      >Ganho</span
                    >
                    <span
                      v-if="stage.is_lost"
                      class="ml-1.5 text-[10px] font-semibold text-red-600 bg-red-50 dark:bg-red-900/30 px-1.5 py-0.5 rounded"
                      >Perdido</span
                    >
                  </div>
                  <div
                    class="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity"
                  >
                    <button
                      class="p-1 rounded text-slate-400 hover:text-woot-500 transition-colors"
                      @click="startEditStage(stage)"
                    >
                      <span class="i-lucide-pencil size-3.5" />
                    </button>
                    <button
                      class="p-1 rounded text-slate-400 hover:text-red-500 transition-colors"
                      @click="deleteStage(stage)"
                    >
                      <span class="i-lucide-trash-2 size-3.5" />
                    </button>
                  </div>
                </div>
              </template>

              <div
                v-if="pipelineStages.length === 0"
                class="text-center py-4 text-xs text-slate-400"
              >
                Nenhuma etapa ainda.
              </div>
            </div>

            <!-- Add new stage form -->
            <div
              class="border border-dashed border-slate-300 dark:border-slate-600 rounded-xl p-4 bg-slate-50 dark:bg-slate-900/40"
            >
              <p
                class="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3"
              >
                Adicionar Nova Etapa
              </p>
              <div class="grid grid-cols-3 gap-3 mb-3">
                <div class="col-span-2">
                  <input
                    v-model="newStage.name"
                    type="text"
                    placeholder="Nome da etapa..."
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                    @keyup.enter="addNewStage"
                  />
                </div>
                <div>
                  <input
                    v-model="newStage.probability"
                    type="number"
                    min="0"
                    max="100"
                    placeholder="% prob"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  />
                </div>
              </div>
              <div class="flex items-center gap-3 mb-3">
                <div class="flex gap-1.5 flex-wrap">
                  <button
                    v-for="color in COLORS"
                    :key="color"
                    class="size-5 rounded-full border-2 transition-transform hover:scale-110"
                    :style="{
                      backgroundColor: color,
                      borderColor:
                        newStage.color === color ? '#1e293b' : 'transparent',
                    }"
                    @click="newStage.color = color"
                  />
                  <input
                    v-model="newStage.color"
                    type="color"
                    class="size-5 rounded cursor-pointer border border-slate-300"
                  />
                </div>
                <label class="flex items-center gap-1.5 cursor-pointer ml-auto">
                  <input
                    v-model="newStage.is_won"
                    type="checkbox"
                    class="rounded accent-green-500"
                  />
                  <span class="text-xs text-green-600 font-medium">Ganho</span>
                </label>
                <label class="flex items-center gap-1.5 cursor-pointer">
                  <input
                    v-model="newStage.is_lost"
                    type="checkbox"
                    class="rounded accent-red-500"
                  />
                  <span class="text-xs text-red-600 font-medium">Perdido</span>
                </label>
              </div>
              <button
                :disabled="
                  !newStage.name.trim() || !selectedPipeline?.id || saving
                "
                class="flex items-center gap-2 text-sm px-4 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium disabled:opacity-50 transition-colors"
                @click="addNewStage"
              >
                <span class="i-lucide-plus size-4" />
                Adicionar
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
