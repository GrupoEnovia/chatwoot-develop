<!-- eslint-disable vue/no-bare-strings-in-template, vue/max-attributes-per-line, prettier/prettier -->
<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore } from 'vuex';
import { automationsAPI, stagesAPI } from 'dashboard/api/kanban.js';

const props = defineProps({
  pipeline: { type: Object, required: true },
});
const emit = defineEmits(['close']);

const store = useStore();
const pipelines = computed(() => store.getters['kanban/getPipelines'] || []);
const agents = computed(() => store.getters['agents/getAgents'] || []);
const inboxes = computed(() => store.getters['inboxes/getInboxes'] || []);

// Selected pipeline (default to the one passed in)
const selectedPipelineId = ref(props.pipeline.id);

// Stages and automations for selected pipeline
const stages = ref([]);
const automations = ref([]);
const loadingStages = ref(false);
const loadingAutomations = ref(false);

// Action form modal state
const showActionForm = ref(false);
const editingAction = ref(null);
const editingStage = ref(null);
const actionFormSaving = ref(false);
const actionFormError = ref(null);

// Stage stop conditions popover
const stopConditionsStageId = ref(null);
const stopConditionsSaving = ref(false);

const ACTION_TYPES = [
  {
    value: 'send_whatsapp',
    label: 'Enviar WhatsApp',
    icon: 'i-lucide-message-circle',
    color: 'text-emerald-500',
  },
  {
    value: 'send_webhook',
    label: 'Disparar Webhook',
    icon: 'i-lucide-webhook',
    color: 'text-blue-500',
  },
  {
    value: 'create_task',
    label: 'Criar Tarefa',
    icon: 'i-lucide-check-square',
    color: 'text-violet-500',
  },
];

const DELAY_TYPES = [
  { value: 'minutes', label: 'min' },
  { value: 'hours', label: 'h' },
  { value: 'days', label: 'dias' },
  { value: 'business_days', label: 'dias úteis' },
];

const blankActionForm = () => ({
  id: null,
  action_type: 'send_whatsapp',
  delay_minutes: 0,
  delay_type: 'minutes',
  active: true,
  config: {},
});

const actionForm = ref(blankActionForm());

// ─── Data loading ────────────────────────────────────────────────────────────

async function loadStages() {
  loadingStages.value = true;
  try {
    const res = await stagesAPI.list(selectedPipelineId.value);
    stages.value = (res.data.payload || []).sort(
      (a, b) => a.position - b.position
    );
  } finally {
    loadingStages.value = false;
  }
}

async function loadAutomations() {
  loadingAutomations.value = true;
  try {
    const res = await automationsAPI.list({
      pipeline_id: selectedPipelineId.value,
    });
    automations.value = res.data.payload || [];
  } finally {
    loadingAutomations.value = false;
  }
}

async function reload() {
  await Promise.all([loadStages(), loadAutomations()]);
}

watch(selectedPipelineId, reload);
onMounted(reload);

// ─── Stage ↔ Automation helpers ──────────────────────────────────────────────

function automationForStage(stageId) {
  return automations.value.find(a => a.trigger_stage_id === stageId) || null;
}

function actionsForStage(stageId) {
  const auto = automationForStage(stageId);
  if (!auto) return [];
  return [...(auto.actions || [])].sort((a, b) => a.position - b.position);
}

function stopConditionsForStage(stageId) {
  const auto = automationForStage(stageId);
  if (!auto)
    return {
      stop_on_reply: true,
      stop_on_stage_change: true,
      stop_on_human_takeover: false,
    };
  return {
    stop_on_reply: auto.stop_on_reply,
    stop_on_stage_change: auto.stop_on_stage_change,
    stop_on_human_takeover: auto.stop_on_human_takeover,
  };
}

// Ensure an automation exists for the stage (create if needed)
async function ensureAutomation(stage) {
  let auto = automationForStage(stage.id);
  if (!auto) {
    const res = await automationsAPI.create({
      pipeline_id: selectedPipelineId.value,
      trigger_stage_id: stage.id,
      name: stage.name,
      active: true,
      stop_on_reply: true,
      stop_on_stage_change: true,
      stop_on_human_takeover: false,
    });
    auto = res.data;
    automations.value.push(auto);
  }
  return auto;
}

// ─── Action CRUD ──────────────────────────────────────────────────────────────

function openNewAction(stage) {
  editingStage.value = stage;
  editingAction.value = null;
  actionForm.value = {
    ...blankActionForm(),
    position: actionsForStage(stage.id).length,
  };
  actionFormError.value = null;
  showActionForm.value = true;
}

function openEditAction(stage, action) {
  editingStage.value = stage;
  editingAction.value = action;
  actionForm.value = {
    id: action.id,
    action_type: action.action_type,
    delay_minutes: action.delay_minutes,
    delay_type: action.delay_type,
    active: action.active,
    config: { ...action.config },
  };
  actionFormError.value = null;
  showActionForm.value = true;
}

function closeActionForm() {
  showActionForm.value = false;
  editingAction.value = null;
  editingStage.value = null;
}

function onActionTypeChange() {
  actionForm.value.config = {};
}

async function saveAction() {
  actionFormSaving.value = true;
  actionFormError.value = null;
  try {
    const auto = await ensureAutomation(editingStage.value);
    const data = {
      action_type: actionForm.value.action_type,
      delay_minutes: actionForm.value.delay_minutes,
      delay_type: actionForm.value.delay_type,
      active: actionForm.value.active,
      config: actionForm.value.config,
      position: actionForm.value.position || 0,
    };
    if (actionForm.value.id) {
      await automationsAPI.updateAction(auto.id, actionForm.value.id, data);
    } else {
      await automationsAPI.createAction(auto.id, data);
    }
    await loadAutomations();
    closeActionForm();
  } catch {
    actionFormError.value = 'Erro ao salvar. Tente novamente.';
  } finally {
    actionFormSaving.value = false;
  }
}

async function deleteAction(stage, action) {
  if (!window.confirm('Excluir esta ação?')) return;
  try {
    const auto = automationForStage(stage.id);
    if (!auto) return;
    await automationsAPI.deleteAction(auto.id, action.id);
    await loadAutomations();
  } catch {
    // silently ignore
  }
}

async function toggleActionActive(stage, action) {
  try {
    const auto = automationForStage(stage.id);
    if (!auto) return;
    await automationsAPI.updateAction(auto.id, action.id, {
      active: !action.active,
    });
    await loadAutomations();
  } catch {
    // silently ignore
  }
}

// ─── Stop conditions ──────────────────────────────────────────────────────────

async function saveStopConditions(stageId, conditions) {
  stopConditionsSaving.value = true;
  try {
    let auto = automationForStage(stageId);
    const stage = stages.value.find(s => s.id === stageId);
    if (!auto) {
      auto = await ensureAutomation(stage);
    } else {
      await automationsAPI.update(auto.id, conditions);
    }
    await loadAutomations();
  } finally {
    stopConditionsSaving.value = false;
    stopConditionsStageId.value = null;
  }
}

// ─── Display helpers ─────────────────────────────────────────────────────────

function actionTypeInfo(type) {
  return ACTION_TYPES.find(t => t.value === type) || ACTION_TYPES[0];
}

function delayLabel(action) {
  if (!action.delay_minutes) return 'Imediato';
  const unit =
    DELAY_TYPES.find(d => d.value === action.delay_type)?.label ||
    action.delay_type;
  return `+${action.delay_minutes} ${unit}`;
}

function actionSummary(action) {
  const cfg = action.config || {};
  if (action.action_type === 'send_whatsapp') {
    if (cfg.use_ai)
      return cfg.ai_prompt
        ? `IA: ${cfg.ai_prompt.slice(0, 40)}...`
        : 'Mensagem gerada por IA';
    return cfg.message
      ? `"${cfg.message.slice(0, 50)}${cfg.message.length > 50 ? '...' : ''}"`
      : '—';
  }
  if (action.action_type === 'send_webhook') return cfg.url || '—';
  if (action.action_type === 'create_task') return cfg.title || '—';
  return '—';
}

const stopConditionsTemp = ref({});

function openStopConditions(stageId) {
  stopConditionsTemp.value = { ...stopConditionsForStage(stageId) };
  stopConditionsStageId.value = stageId;
}
</script>

<template>
  <div class="fixed inset-0 z-50 flex flex-col bg-white dark:bg-slate-900">
    <!-- Top bar -->
    <div
      class="flex items-center justify-between px-6 py-3 border-b border-slate-100 dark:border-slate-800 shrink-0"
    >
      <div class="flex items-center gap-4">
        <div class="flex items-center gap-2.5">
          <div
            class="w-7 h-7 rounded-lg bg-violet-100 dark:bg-violet-900/30 flex items-center justify-center shrink-0"
          >
            <span
              class="i-lucide-zap size-4 text-violet-600 dark:text-violet-400"
            />
          </div>
          <span class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >Automação de CRM</span
          >
        </div>

        <!-- Pipeline selector -->
        <div class="relative">
          <select
            v-model="selectedPipelineId"
            class="text-xs pl-3 pr-8 py-1.5 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30 appearance-none cursor-pointer"
          >
            <option v-for="p in pipelines" :key="p.id" :value="p.id">
              {{ p.name }}
            </option>
          </select>
          <span
            class="i-lucide-chevron-down size-3.5 text-slate-400 absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none"
          />
        </div>
      </div>

      <button
        class="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        @click="emit('close')"
      >
        <span class="i-lucide-x size-4" />
      </button>
    </div>

    <!-- Loading state -->
    <div
      v-if="loadingStages || loadingAutomations"
      class="flex-1 flex items-center justify-center"
    >
      <span class="i-lucide-loader-2 size-6 text-violet-400 animate-spin" />
    </div>

    <!-- Empty state -->
    <div
      v-else-if="stages.length === 0"
      class="flex-1 flex flex-col items-center justify-center text-center px-4"
    >
      <span
        class="i-lucide-layout-columns size-10 text-slate-300 dark:text-slate-600 mb-3"
      />
      <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
        Nenhuma etapa configurada
      </p>
      <p class="text-xs text-slate-400 mt-1">
        Configure as etapas do funil antes de criar automações.
      </p>
    </div>

    <!-- Columns board -->
    <div v-else class="flex-1 overflow-x-auto overflow-y-hidden">
      <div class="flex gap-0 h-full min-w-max">
        <div
          v-for="stage in stages"
          :key="stage.id"
          class="flex flex-col w-72 shrink-0 border-r border-slate-100 dark:border-slate-800 h-full"
        >
          <!-- Column header -->
          <div
            class="flex items-center justify-between px-4 py-3 border-b border-slate-100 dark:border-slate-800 shrink-0"
          >
            <div class="flex items-center gap-2 min-w-0">
              <span
                class="w-2.5 h-2.5 rounded-full shrink-0"
                :style="stage.color ? `background:${stage.color}` : ''"
                :class="!stage.color ? 'bg-slate-300 dark:bg-slate-600' : ''"
              />
              <span
                class="text-xs font-semibold text-slate-700 dark:text-slate-200 truncate"
                >{{ stage.name }}</span
              >
              <span
                v-if="actionsForStage(stage.id).length"
                class="text-xs bg-violet-100 dark:bg-violet-900/30 text-violet-600 dark:text-violet-400 rounded-full px-1.5 py-0.5 font-medium shrink-0"
              >
                {{ actionsForStage(stage.id).length }}
              </span>
            </div>

            <!-- Stop conditions gear -->
            <div class="relative">
              <button
                class="p-1 rounded text-slate-300 hover:text-slate-500 dark:text-slate-600 dark:hover:text-slate-400 transition-colors"
                :class="
                  automationForStage(stage.id)
                    ? 'text-violet-400 dark:text-violet-500'
                    : ''
                "
                title="Condições de parada"
                @click.stop="openStopConditions(stage.id)"
              >
                <span class="i-lucide-settings-2 size-3.5" />
              </button>

              <!-- Stop conditions popover -->
              <div
                v-if="stopConditionsStageId === stage.id"
                class="absolute top-full right-0 mt-1 z-30 w-52 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-slate-100 dark:border-slate-700 p-3"
                @click.stop
              >
                <p
                  class="text-xs font-semibold text-slate-600 dark:text-slate-300 mb-2"
                >
                  Parar automação quando:
                </p>
                <div class="space-y-2">
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      v-model="stopConditionsTemp.stop_on_reply"
                      type="checkbox"
                      class="rounded border-slate-300 text-violet-600"
                    />
                    <span class="text-xs text-slate-600 dark:text-slate-300"
                      >Lead responder</span
                    >
                  </label>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      v-model="stopConditionsTemp.stop_on_stage_change"
                      type="checkbox"
                      class="rounded border-slate-300 text-violet-600"
                    />
                    <span class="text-xs text-slate-600 dark:text-slate-300"
                      >Mudar de etapa</span
                    >
                  </label>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      v-model="stopConditionsTemp.stop_on_human_takeover"
                      type="checkbox"
                      class="rounded border-slate-300 text-violet-600"
                    />
                    <span class="text-xs text-slate-600 dark:text-slate-300"
                      >Agente assumir</span
                    >
                  </label>
                </div>
                <div class="flex gap-2 mt-3">
                  <button
                    :disabled="stopConditionsSaving"
                    class="flex-1 text-xs py-1.5 rounded-lg bg-violet-600 text-white hover:bg-violet-700 disabled:opacity-50 font-medium"
                    @click="saveStopConditions(stage.id, stopConditionsTemp)"
                  >
                    {{ stopConditionsSaving ? '...' : 'Salvar' }}
                  </button>
                  <button
                    class="text-xs px-2 py-1.5 rounded-lg border border-slate-200 dark:border-slate-700 text-slate-500 hover:bg-slate-50 dark:hover:bg-slate-700"
                    @click="stopConditionsStageId = null"
                  >
                    Cancelar
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- Action cards list -->
          <div class="flex-1 overflow-y-auto px-3 py-3 space-y-2">
            <!-- Empty column -->
            <div
              v-if="actionsForStage(stage.id).length === 0"
              class="flex flex-col items-center justify-center py-8 text-center"
            >
              <span
                class="i-lucide-zap-off size-6 text-slate-200 dark:text-slate-700 mb-1.5"
              />
              <p class="text-xs text-slate-300 dark:text-slate-600">
                Sem automações
              </p>
            </div>

            <!-- Action cards -->
            <div
              v-for="action in actionsForStage(stage.id)"
              :key="action.id"
              class="group relative bg-white dark:bg-slate-800 rounded-xl border border-slate-100 dark:border-slate-700 px-3 py-2.5 hover:border-violet-200 dark:hover:border-violet-700 transition-colors"
              :class="!action.active ? 'opacity-50' : ''"
            >
              <!-- Type + delay row -->
              <div class="flex items-center gap-2 mb-1.5">
                <span
                  class="size-3.5 shrink-0"
                  :class="[
                    actionTypeInfo(action.action_type).icon,
                    actionTypeInfo(action.action_type).color,
                  ]"
                />
                <span
                  class="text-xs font-medium text-slate-700 dark:text-slate-200 flex-1 truncate"
                >
                  {{ actionTypeInfo(action.action_type).label }}
                </span>
                <span
                  class="text-xs font-mono text-violet-500 dark:text-violet-400 bg-violet-50 dark:bg-violet-900/20 px-1.5 py-0.5 rounded-md shrink-0"
                >
                  {{ delayLabel(action) }}
                </span>
              </div>

              <!-- Summary -->
              <p
                class="text-xs text-slate-400 dark:text-slate-500 truncate mb-2"
              >
                {{ actionSummary(action) }}
              </p>

              <!-- Footer row: active toggle + actions -->
              <div class="flex items-center gap-2">
                <button
                  class="flex items-center gap-1 text-xs transition-colors"
                  :class="
                    action.active
                      ? 'text-emerald-500'
                      : 'text-slate-300 dark:text-slate-600'
                  "
                  @click="toggleActionActive(stage, action)"
                >
                  <span
                    :class="
                      action.active
                        ? 'i-lucide-toggle-right size-4'
                        : 'i-lucide-toggle-left size-4'
                    "
                  />
                  <span>{{ action.active ? 'Ativa' : 'Inativa' }}</span>
                </button>
                <div class="flex-1" />
                <button
                  class="p-1 rounded text-slate-300 hover:text-violet-500 dark:text-slate-600 dark:hover:text-violet-400 transition-colors opacity-0 group-hover:opacity-100"
                  @click="openEditAction(stage, action)"
                >
                  <span class="i-lucide-pencil size-3.5" />
                </button>
                <button
                  class="p-1 rounded text-slate-300 hover:text-red-500 dark:text-slate-600 dark:hover:text-red-400 transition-colors opacity-0 group-hover:opacity-100"
                  @click="deleteAction(stage, action)"
                >
                  <span class="i-lucide-trash-2 size-3.5" />
                </button>
              </div>
            </div>
          </div>

          <!-- Add action button -->
          <div
            class="px-3 py-2.5 border-t border-slate-100 dark:border-slate-800 shrink-0"
          >
            <button
              class="w-full flex items-center justify-center gap-1.5 text-xs py-2 rounded-lg border border-dashed border-slate-200 dark:border-slate-700 text-slate-400 dark:text-slate-500 hover:border-violet-300 dark:hover:border-violet-600 hover:text-violet-500 dark:hover:text-violet-400 hover:bg-violet-50 dark:hover:bg-violet-900/10 transition-colors"
              @click="openNewAction(stage)"
            >
              <span class="i-lucide-plus size-3.5" />
              Adicionar atividade
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Backdrop click to close stop conditions -->
    <div
      v-if="stopConditionsStageId"
      class="fixed inset-0 z-20"
      @click="stopConditionsStageId = null"
    />
  </div>

  <!-- ── Action form modal ───────────────────────────────────────────── -->
  <Teleport to="body">
    <div
      v-if="showActionForm"
      class="fixed inset-0 z-[60] flex items-center justify-center bg-black/40 backdrop-blur-sm"
      @click.self="closeActionForm"
    >
      <div
        class="bg-white dark:bg-slate-900 rounded-2xl shadow-2xl w-full max-w-md mx-4 overflow-hidden"
      >
        <!-- Modal header -->
        <div
          class="flex items-center justify-between px-5 py-4 border-b border-slate-100 dark:border-slate-800"
        >
          <div>
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ editingAction ? 'Editar atividade' : 'Nova atividade' }}
            </h3>
            <p class="text-xs text-slate-400 mt-0.5">
              {{ editingStage?.name }}
            </p>
          </div>
          <button
            class="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
            @click="closeActionForm"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>

        <!-- Form body -->
        <div class="px-5 py-4 space-y-4 max-h-[70vh] overflow-y-auto">
          <!-- Error -->
          <div
            v-if="actionFormError"
            class="text-xs text-red-600 bg-red-50 dark:bg-red-900/20 rounded-lg px-3 py-2"
          >
            {{ actionFormError }}
          </div>

          <!-- Action type -->
          <div>
            <label
              class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
              >Tipo de atividade</label
            >
            <div class="grid grid-cols-3 gap-2">
              <button
                v-for="type in ACTION_TYPES"
                :key="type.value"
                class="flex flex-col items-center gap-1.5 py-3 px-2 rounded-xl border-2 transition-all text-center"
                :class="
                  actionForm.action_type === type.value
                    ? 'border-violet-500 bg-violet-50 dark:bg-violet-900/20'
                    : 'border-slate-100 dark:border-slate-700 hover:border-slate-200 dark:hover:border-slate-600'
                "
                @click="
                  actionForm.action_type = type.value;
                  onActionTypeChange();
                "
              >
                <span class="size-5" :class="[type.icon, type.color]" />
                <span
                  class="text-xs font-medium text-slate-600 dark:text-slate-300 leading-tight"
                  >{{ type.label }}</span
                >
              </button>
            </div>
          </div>

          <!-- Delay -->
          <div>
            <label
              class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
              >Executar após</label
            >
            <div class="flex gap-2">
              <input
                v-model.number="actionForm.delay_minutes"
                type="number"
                min="0"
                placeholder="0"
                class="w-24 text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
              />
              <select
                v-model="actionForm.delay_type"
                class="flex-1 text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
              >
                <option value="minutes">Minutos</option>
                <option value="hours">Horas</option>
                <option value="days">Dias</option>
                <option value="business_days">Dias úteis</option>
              </select>
            </div>
            <p
              v-if="!actionForm.delay_minutes"
              class="text-xs text-slate-400 mt-1"
            >
              Executar imediatamente ao entrar na etapa
            </p>
          </div>

          <!-- ─ WhatsApp config ─ -->
          <template v-if="actionForm.action_type === 'send_whatsapp'">
            <div>
              <label
                class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
                >Canal (Inbox)</label
              >
              <select
                v-model="actionForm.config.inbox_id"
                class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
              >
                <option :value="undefined">Qualquer canal disponível</option>
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
              <label class="flex items-center gap-2 cursor-pointer mb-2">
                <input
                  v-model="actionForm.config.use_ai"
                  type="checkbox"
                  class="rounded border-slate-300 text-violet-600 focus:ring-violet-500"
                />
                <span
                  class="text-xs font-medium text-slate-600 dark:text-slate-300"
                  >Gerar mensagem com IA</span
                >
              </label>

              <div v-if="actionForm.config.use_ai">
                <label class="text-xs text-slate-500 mb-1 block"
                  >Instrução para IA</label
                >
                <textarea
                  v-model="actionForm.config.ai_prompt"
                  rows="2"
                  placeholder="Ex: Faça um follow-up gentil sobre a proposta enviada"
                  class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30 resize-none"
                />
              </div>
              <div v-else>
                <label class="text-xs text-slate-500 mb-1 block"
                  >Mensagem</label
                >
                <textarea
                  v-model="actionForm.config.message"
                  rows="4"
                  placeholder="Digite a mensagem... Use {{nome}}, {{telefone}} para variáveis."
                  class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30 resize-none"
                />
              </div>
            </div>

            <div>
              <label
                class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
                >Janela de envio (horário)</label
              >
              <div class="flex items-center gap-2">
                <input
                  v-model="actionForm.config.business_hours_start"
                  type="time"
                  class="flex-1 text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
                />
                <span class="text-xs text-slate-400">até</span>
                <input
                  v-model="actionForm.config.business_hours_end"
                  type="time"
                  class="flex-1 text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
                />
              </div>
              <p class="text-xs text-slate-400 mt-1">
                Deixe vazio para enviar a qualquer hora
              </p>
            </div>
          </template>

          <!-- ─ Webhook config ─ -->
          <template v-if="actionForm.action_type === 'send_webhook'">
            <div>
              <label
                class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
                >URL</label
              >
              <input
                v-model="actionForm.config.url"
                type="url"
                placeholder="https://seu-sistema.com/webhook"
                class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
              />
            </div>

            <div>
              <label
                class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
                >Método</label
              >
              <select
                v-model="actionForm.config.method"
                class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
              >
                <option value="POST">POST</option>
                <option value="GET">GET</option>
                <option value="PUT">PUT</option>
                <option value="PATCH">PATCH</option>
              </select>
            </div>

            <div>
              <label
                class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
                >Payload (JSON)</label
              >
              <textarea
                v-model="actionForm.config.payload"
                rows="4"
                placeholder='{"key": "value"}'
                class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30 resize-none font-mono"
              />
            </div>

            <div>
              <label
                class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
                >Headers (JSON)</label
              >
              <textarea
                v-model="actionForm.config.headers"
                rows="2"
                placeholder='{"Authorization": "Bearer token"}'
                class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30 resize-none font-mono"
              />
            </div>
          </template>

          <!-- ─ Task config ─ -->
          <template v-if="actionForm.action_type === 'create_task'">
            <div>
              <label
                class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
                >Título da tarefa</label
              >
              <input
                v-model="actionForm.config.title"
                type="text"
                placeholder="Ex: Ligar para o cliente"
                class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
              />
            </div>

            <div>
              <label
                class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
                >Descrição</label
              >
              <textarea
                v-model="actionForm.config.description"
                rows="2"
                placeholder="Detalhes da tarefa..."
                class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30 resize-none"
              />
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div>
                <label
                  class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
                  >Responsável</label
                >
                <select
                  v-model="actionForm.config.assignee_id"
                  class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
                >
                  <option :value="undefined">Sem responsável</option>
                  <option
                    v-for="agent in agents"
                    :key="agent.id"
                    :value="agent.id"
                  >
                    {{ agent.name }}
                  </option>
                </select>
              </div>
              <div>
                <label
                  class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
                  >Prioridade</label
                >
                <select
                  v-model="actionForm.config.priority"
                  class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
                >
                  <option value="low">Baixa</option>
                  <option value="medium">Média</option>
                  <option value="high">Alta</option>
                </select>
              </div>
            </div>

            <div>
              <label
                class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5 block"
                >Prazo (horas após entrada na etapa)</label
              >
              <input
                v-model.number="actionForm.config.due_hours"
                type="number"
                min="0"
                placeholder="24"
                class="w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30"
              />
            </div>
          </template>

          <!-- Active toggle -->
          <label class="flex items-center gap-2.5 cursor-pointer pt-1">
            <input
              v-model="actionForm.active"
              type="checkbox"
              class="rounded border-slate-300 text-violet-600 focus:ring-violet-500"
            />
            <span class="text-xs font-medium text-slate-600 dark:text-slate-300"
              >Atividade ativa</span
            >
          </label>
        </div>

        <!-- Footer -->
        <div
          class="flex gap-2 px-5 py-4 border-t border-slate-100 dark:border-slate-800"
        >
          <button
            :disabled="actionFormSaving"
            class="flex-1 text-xs py-2.5 rounded-xl bg-violet-600 text-white hover:bg-violet-700 font-medium transition-colors disabled:opacity-50"
            @click="saveAction"
          >
            {{
              actionFormSaving
                ? 'Salvando...'
                : editingAction
                  ? 'Salvar alterações'
                  : 'Adicionar atividade'
            }}
          </button>
          <button
            class="text-xs px-4 py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"
            @click="closeActionForm"
          >
            Cancelar
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
