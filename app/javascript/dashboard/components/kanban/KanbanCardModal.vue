<script setup>
import { ref, computed, watch, reactive } from 'vue';
import { useStore } from 'vuex';
import { useAccount } from 'dashboard/composables/useAccount';
import ContactsAPI from 'dashboard/api/contacts.js';
/* global axios */

const props = defineProps({
  item: { type: Object, default: null },
  pipelineId: { type: Number, required: true },
});

const emit = defineEmits(['close', 'updated']);
const store = useStore();
const { accountId } = useAccount();

// ─── Agents ───────────────────────────────────────────────────────────────────
const agents = computed(() => store.getters['agents/getAgents'] || []);

// ─── Tabs ────────────────────────────────────────────────────────────────────
const TABS = [
  { id: 'activities', label: 'Atividades', icon: 'i-lucide-activity' },
  { id: 'tasks', label: 'Tarefas', icon: 'i-lucide-check-square' },
  { id: 'notes', label: 'Notas', icon: 'i-lucide-sticky-note' },
  { id: 'attachments', label: 'Anexos', icon: 'i-lucide-paperclip' },
  { id: 'whatsapp', label: 'WhatsApp', icon: 'i-lucide-message-circle' },
];
const activeTab = ref('activities');

// ─── Form fields ──────────────────────────────────────────────────────────────
const editingTitle = ref(false);
const titleDraft = ref('');

const form = ref({
  source: '',
  temperature: '',
  expected_close_date: '',
  value: '',
  contact_phone: '',
  score: 0,
  stage_id: null,
  assignee_id: null,
});

const SOURCES = [
  { value: '', label: 'Sem origem' },
  { value: 'website', label: 'Website' },
  { value: 'whatsapp', label: 'WhatsApp' },
  { value: 'instagram', label: 'Instagram' },
  { value: 'facebook', label: 'Facebook' },
  { value: 'phone', label: 'Telefone' },
  { value: 'email', label: 'E-mail' },
  { value: 'referral', label: 'Indicação' },
  { value: 'manual', label: 'Manual' },
];

const TEMPERATURES = [
  { value: '', label: 'Sem temperatura' },
  { value: 'cold', label: '❄️ Frio' },
  { value: 'warm', label: '🌡 Morno' },
  { value: 'hot', label: '🔥 Quente' },
  { value: 'very_hot', label: '💥 Muito Quente' },
];

const PRIORITIES = [
  {
    value: 0,
    label: 'Baixa',
    cls: 'text-slate-400 bg-slate-50 dark:bg-slate-700',
    border: 'border-slate-300',
  },
  {
    value: 1,
    label: 'Média',
    cls: 'text-yellow-600 bg-yellow-50 dark:bg-yellow-900/30',
    border: 'border-yellow-400',
  },
  {
    value: 2,
    label: 'Alta',
    cls: 'text-red-600 bg-red-50 dark:bg-red-900/30',
    border: 'border-red-400',
  },
];

const RECURRENCE_FREQUENCIES = [
  { value: 'daily', label: 'Diária' },
  { value: 'weekly', label: 'Semanal' },
  { value: 'monthly', label: 'Mensal' },
];

const RECURRENCE_LABELS = {
  daily: 'Diária',
  weekly: 'Semanal',
  monthly: 'Mensal',
};

// ─── Store ───────────────────────────────────────────────────────────────────
const stages = computed(() => store.getters['kanban/getStages']);
const tasks = computed(() =>
  props.item ? store.getters['kanban/getTasksForItem'](props.item.id) : []
);
const notes = computed(() =>
  props.item ? store.getters['kanban/getNotesForItem'](props.item.id) : []
);
const activities = computed(() =>
  props.item ? store.getters['kanban/getActivitiesForItem'](props.item.id) : []
);
const attachments = computed(() =>
  props.item ? store.getters['kanban/getAttachmentsForItem'](props.item.id) : []
);

function taskDueMs(task) {
  if (task.due_at) return task.due_at * 1000;
  if (task.due_date) return new Date(task.due_date).getTime();
  return Infinity;
}

const sortedTasks = computed(() =>
  [...tasks.value].sort((a, b) => {
    if (a.completed && !b.completed) return 1;
    if (!a.completed && b.completed) return -1;
    if (a.overdue && !b.overdue) return -1;
    if (!a.overdue && b.overdue) return 1;
    return taskDueMs(a) - taskDueMs(b);
  })
);

const pendingTasks = computed(() =>
  sortedTasks.value.filter(t => !t.completed)
);
const completedTasks = computed(() =>
  sortedTasks.value.filter(t => t.completed)
);

const currentStage = computed(() =>
  stages.value.find(s => s.id === (form.value.stage_id || props.item?.stage_id))
);
const stageProbability = computed(() => currentStage.value?.probability ?? 0);

// ─── Load item data ───────────────────────────────────────────────────────────
watch(
  () => props.item,
  async item => {
    if (!item) return;
    titleDraft.value = item.title;
    form.value = {
      source: item.source || '',
      temperature: item.temperature || '',
      expected_close_date: item.expected_close_date || '',
      value: item.value || '',
      contact_phone: item.contact_phone || '',
      score: item.score || 0,
      stage_id: item.stage_id,
      assignee_id: item.assignee?.id || null,
    };
    activeTab.value = 'activities';

    // Load agents if not loaded
    if (!agents.value.length) {
      store.dispatch('agents/get').catch(() => {});
    }

    await Promise.all([
      store.dispatch('kanban/fetchActivities', {
        pipelineId: props.pipelineId,
        itemId: item.id,
      }),
      store.dispatch('kanban/fetchTasks', {
        pipelineId: props.pipelineId,
        itemId: item.id,
      }),
      store.dispatch('kanban/fetchNotes', {
        pipelineId: props.pipelineId,
        itemId: item.id,
      }),
      store.dispatch('kanban/fetchAttachments', {
        pipelineId: props.pipelineId,
        itemId: item.id,
      }),
    ]);
  },
  { immediate: true }
);

// ─── Title edit ───────────────────────────────────────────────────────────────
async function saveTitle() {
  if (!titleDraft.value.trim() || titleDraft.value === props.item.title) {
    editingTitle.value = false;
    return;
  }
  await store.dispatch('kanban/updateItem', {
    pipelineId: props.pipelineId,
    id: props.item.id,
    title: titleDraft.value.trim(),
  });
  editingTitle.value = false;
}

// ─── Field save ───────────────────────────────────────────────────────────────
async function saveField(field) {
  let val = form.value[field];
  if (field === 'score') val = parseInt(val, 10) || 0;
  if (field === 'assignee_id') val = val || null;
  await store.dispatch('kanban/updateItem', {
    pipelineId: props.pipelineId,
    id: props.item.id,
    [field]: val,
  });
}

// ─── Won / Lost / Delete ─────────────────────────────────────────────────────
const statusLoading = ref(false);
const statusError = ref('');
const showLostPicker = ref(false);
const selectedLostReasonId = ref(null);
const showWonConfirm = ref(false);
const showReopenConfirm = ref(false);

function markWon() {
  showWonConfirm.value = true;
}

async function confirmMarkWon() {
  showWonConfirm.value = false;
  statusLoading.value = true;
  statusError.value = '';
  try {
    const updated = await store.dispatch('kanban/markItemWon', {
      pipelineId: props.pipelineId,
      id: props.item.id,
    });
    store.dispatch('kanban/fetchActivities', {
      pipelineId: props.pipelineId,
      itemId: props.item.id,
    });
    const allStages = store.getters['kanban/getStages'];
    const wonStage = allStages.find(s => s.is_won);
    if (!wonStage) {
      statusError.value =
        'Nenhuma etapa de Ganho configurada neste pipeline. Configure em Configurações > Etapas.';
    } else if (updated.stage_id !== wonStage.id) {
      statusError.value = 'Não foi possível mover para a etapa de Ganho.';
    } else {
      emit('updated');
    }
  } catch (e) {
    statusError.value =
      e?.response?.data?.message || e?.message || 'Erro ao marcar como Ganho.';
  } finally {
    statusLoading.value = false;
  }
}

async function openLostPicker() {
  await store.dispatch('kanban/fetchLostReasons');
  selectedLostReasonId.value = null;
  showLostPicker.value = true;
}

async function confirmMarkLost() {
  showLostPicker.value = false;
  statusLoading.value = true;
  statusError.value = '';
  try {
    const updated = await store.dispatch('kanban/markItemLost', {
      pipelineId: props.pipelineId,
      id: props.item.id,
      lostReasonId: selectedLostReasonId.value || undefined,
    });
    store.dispatch('kanban/fetchActivities', {
      pipelineId: props.pipelineId,
      itemId: props.item.id,
    });
    const allStages = store.getters['kanban/getStages'];
    const lostStage = allStages.find(s => s.is_lost);
    if (!lostStage) {
      statusError.value =
        'Nenhuma etapa de Perdido configurada neste pipeline. Configure em Configurações > Etapas.';
    } else if (updated.stage_id !== lostStage.id) {
      statusError.value = 'Não foi possível mover para a etapa de Perdido.';
    } else {
      emit('updated');
    }
  } catch (e) {
    statusError.value =
      e?.response?.data?.message ||
      e?.message ||
      'Erro ao marcar como Perdido.';
  } finally {
    statusLoading.value = false;
  }
}

function reopenItem() {
  showReopenConfirm.value = true;
}

async function confirmReopen() {
  showReopenConfirm.value = false;
  await store.dispatch('kanban/reopenItem', {
    pipelineId: props.pipelineId,
    id: props.item.id,
  });
  emit('updated');
}
async function deleteItem() {
  if (!window.confirm('Remover este card permanentemente?')) return;
  await store.dispatch('kanban/deleteItem', {
    pipelineId: props.pipelineId,
    id: props.item.id,
  });
  emit('close');
}

// ─── Tasks ───────────────────────────────────────────────────────────────────
const showNewTaskForm = ref(false);
const BLANK_TASK = () => ({
  title: '',
  description: '',
  priority: 1,
  assignee_id: null,
  start_date: '',
  due_at: '',
  is_recurring: false,
  recurrence_frequency: 'weekly',
  recurrence_interval: 1,
  recurrence_end_date: '',
});
const newTask = ref(BLANK_TASK());
const savingTask = ref(false);
const taskError = ref('');
const editingTaskId = ref(null);
const taskEditForm = ref({});

async function createTask() {
  if (!newTask.value.title.trim()) return;
  savingTask.value = true;
  taskError.value = '';
  try {
    await store.dispatch('kanban/createTask', {
      pipelineId: props.pipelineId,
      itemId: props.item.id,
      title: newTask.value.title.trim(),
      description: newTask.value.description || undefined,
      priority: newTask.value.priority,
      assignee_id: newTask.value.assignee_id || undefined,
      start_date: newTask.value.start_date || undefined,
      due_at: newTask.value.due_at || undefined,
      is_recurring: newTask.value.is_recurring,
      recurrence_frequency: newTask.value.is_recurring
        ? newTask.value.recurrence_frequency
        : undefined,
      recurrence_interval: newTask.value.is_recurring
        ? newTask.value.recurrence_interval
        : undefined,
      recurrence_end_date:
        newTask.value.is_recurring && newTask.value.recurrence_end_date
          ? newTask.value.recurrence_end_date
          : undefined,
    });
    newTask.value = BLANK_TASK();
    showNewTaskForm.value = false;
    store.dispatch('kanban/fetchActivities', {
      pipelineId: props.pipelineId,
      itemId: props.item.id,
    });
  } catch (e) {
    taskError.value = e.message || 'Erro ao criar tarefa. Tente novamente.';
  } finally {
    savingTask.value = false;
  }
}

async function toggleTask(task) {
  if (task.completed) {
    await store.dispatch('kanban/updateTask', {
      pipelineId: props.pipelineId,
      itemId: props.item.id,
      id: task.id,
      completed_at: null,
    });
  } else {
    await store.dispatch('kanban/completeTask', {
      pipelineId: props.pipelineId,
      itemId: props.item.id,
      id: task.id,
    });
    store.dispatch('kanban/fetchActivities', {
      pipelineId: props.pipelineId,
      itemId: props.item.id,
    });
  }
}

function startEditTask(task) {
  editingTaskId.value = task.id;
  taskEditForm.value = {
    title: task.title,
    description: task.description || '',
    priority: task.priority,
    assignee_id: task.assignee?.id || null,
    start_date: task.start_date || '',
    due_at: task.due_at
      ? new Date(task.due_at * 1000).toISOString().slice(0, 16)
      : '',
    is_recurring: task.is_recurring || false,
    recurrence_frequency: task.recurrence_frequency || 'weekly',
    recurrence_interval: task.recurrence_interval || 1,
    recurrence_end_date: task.recurrence_end_date || '',
  };
}

async function saveEditTask(task) {
  await store.dispatch('kanban/updateTask', {
    pipelineId: props.pipelineId,
    itemId: props.item.id,
    id: task.id,
    ...taskEditForm.value,
    start_date: taskEditForm.value.start_date || null,
    due_at: taskEditForm.value.due_at || null,
    assignee_id: taskEditForm.value.assignee_id || null,
    recurrence_frequency: taskEditForm.value.is_recurring
      ? taskEditForm.value.recurrence_frequency
      : null,
    recurrence_interval: taskEditForm.value.is_recurring
      ? taskEditForm.value.recurrence_interval
      : null,
    recurrence_end_date:
      taskEditForm.value.is_recurring && taskEditForm.value.recurrence_end_date
        ? taskEditForm.value.recurrence_end_date
        : null,
  });
  editingTaskId.value = null;
}

async function deleteTask(taskId) {
  await store.dispatch('kanban/deleteTask', {
    pipelineId: props.pipelineId,
    itemId: props.item.id,
    id: taskId,
  });
}

function taskStatusInfo(task) {
  if (task.completed) return null;
  const now = Date.now();
  let dueMs;
  if (task.due_at) {
    dueMs = task.due_at * 1000;
  } else if (task.due_date) {
    dueMs = new Date(`${task.due_date}T23:59:59`).getTime();
  } else {
    dueMs = null;
  }
  if (!dueMs) return null;
  const diff = Math.ceil((dueMs - now) / 86400000);
  if (diff < 0)
    return {
      label: `⚠️ ${Math.abs(diff)} dia(s) de atraso`,
      cls: 'border-red-400 bg-red-50 dark:bg-red-900/20',
      badge: 'text-red-600 bg-red-100',
    };
  if (diff === 0)
    return {
      label: 'Vence hoje',
      cls: 'border-yellow-400 bg-yellow-50 dark:bg-yellow-900/20',
      badge: 'text-yellow-600 bg-yellow-100',
    };
  return null;
}

function formatDue(task) {
  if (task.due_at)
    return new Date(task.due_at * 1000).toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  if (task.due_date)
    return new Date(task.due_date + 'T00:00:00').toLocaleDateString('pt-BR');
  return null;
}

function formatDate(dateStr) {
  if (!dateStr) return null;
  return new Date(dateStr + 'T00:00:00').toLocaleDateString('pt-BR');
}

// ─── Notes ───────────────────────────────────────────────────────────────────
const newNoteContent = ref('');
const savingNote = ref(false);

async function addNote() {
  if (!newNoteContent.value.trim()) return;
  savingNote.value = true;
  try {
    await store.dispatch('kanban/createNote', {
      pipelineId: props.pipelineId,
      itemId: props.item.id,
      content: newNoteContent.value.trim(),
    });
    newNoteContent.value = '';
  } finally {
    savingNote.value = false;
  }
}
async function deleteNote(noteId) {
  await store.dispatch('kanban/deleteNote', {
    pipelineId: props.pipelineId,
    itemId: props.item.id,
    id: noteId,
  });
}

// ─── Attachments ─────────────────────────────────────────────────────────────
const fileInput = ref(null);
async function onFileSelected(e) {
  const file = e.target.files?.[0];
  if (!file) return;
  const fd = new FormData();
  fd.append('file', file);
  try {
    await store.dispatch('kanban/createAttachment', {
      pipelineId: props.pipelineId,
      itemId: props.item.id,
      formData: fd,
    });
  } catch {
    /* ignore */
  }
  e.target.value = '';
}
async function deleteAttachment(id) {
  await store.dispatch('kanban/deleteAttachment', {
    pipelineId: props.pipelineId,
    itemId: props.item.id,
    id,
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
const ACTIVITY_ICONS = {
  created: { icon: 'i-lucide-plus-circle', cls: 'text-green-500' },
  moved: { icon: 'i-lucide-arrow-right-circle', cls: 'text-blue-500' },
  assigned: { icon: 'i-lucide-user-check', cls: 'text-woot-500' },
  value_changed: { icon: 'i-lucide-dollar-sign', cls: 'text-yellow-500' },
  note_added: { icon: 'i-lucide-sticky-note', cls: 'text-purple-500' },
  task_created: { icon: 'i-lucide-check-square', cls: 'text-slate-500' },
  task_completed: { icon: 'i-lucide-check-circle-2', cls: 'text-green-500' },
  file_attached: { icon: 'i-lucide-paperclip', cls: 'text-slate-500' },
  won: { icon: 'i-lucide-trophy', cls: 'text-yellow-500' },
  lost: { icon: 'i-lucide-x-circle', cls: 'text-red-500' },
  reopened: { icon: 'i-lucide-rotate-ccw', cls: 'text-blue-400' },
  temperature_changed: { icon: 'i-lucide-thermometer', cls: 'text-orange-500' },
  score_changed: { icon: 'i-lucide-star', cls: 'text-yellow-400' },
  source_changed: { icon: 'i-lucide-tag', cls: 'text-slate-500' },
  conversation_linked: {
    icon: 'i-lucide-message-square',
    cls: 'text-woot-500',
  },
  phone_changed: { icon: 'i-lucide-phone', cls: 'text-slate-500' },
  contact_linked: { icon: 'i-lucide-user', cls: 'text-blue-500' },
};

const ACTIVITY_LABELS = {
  created: 'Lead criado',
  moved: 'Etapa alterada',
  assigned: 'Responsável alterado',
  value_changed: 'Valor alterado',
  note_added: 'Nota adicionada',
  task_created: 'Tarefa criada',
  task_completed: 'Tarefa concluída',
  file_attached: 'Arquivo anexado',
  won: 'Lead ganho',
  lost: 'Lead perdido',
  reopened: 'Lead reaberto',
  temperature_changed: 'Temperatura alterada',
  score_changed: 'Score alterado',
  source_changed: 'Origem alterada',
  conversation_linked: 'Conversa vinculada',
  phone_changed: 'Telefone atualizado',
  contact_linked: 'Contato vinculado',
};

function activityIcon(type) {
  return (
    ACTIVITY_ICONS[type] || { icon: 'i-lucide-circle', cls: 'text-slate-400' }
  );
}
function activityLabel(act) {
  return ACTIVITY_LABELS[act.action_type] || act.action_type.replace(/_/g, ' ');
}
function activityDescription(act) {
  if (act.metadata?.description) return act.metadata.description;
  return null;
}
function formatTs(ts) {
  if (!ts) return '';
  return new Date(ts * 1000).toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}
function formatSize(b) {
  if (!b) return '';
  if (b < 1024) return `${b} B`;
  if (b < 1048576) return `${(b / 1024).toFixed(1)} KB`;
  return `${(b / 1048576).toFixed(1)} MB`;
}

const conversationLink = computed(() => {
  if (!props.item?.conversation_id) return null;
  return `/app/accounts/${accountId.value}/conversations/${props.item.conversation_id}`;
});

// ─── WhatsApp / Start conversation ───────────────────────────────────────────
const inboxes = ref([]);
const showStartConversation = ref(false);
const startConvForm = ref({ inbox_id: null, message: '' });
const startConvLoading = ref(false);
const startConvError = ref('');

async function loadInboxes() {
  try {
    const { data: res } = await axios.get(
      `/api/v1/accounts/${accountId.value}/inboxes`
    );
    inboxes.value = (res.payload || []).filter(i =>
      [
        'Channel::Whatsapp',
        'Channel::Api',
        'Channel::Email',
        'Channel::TwilioSms',
      ].includes(i.channel_type)
    );
    if (inboxes.value.length > 0)
      startConvForm.value.inbox_id = inboxes.value[0].id;
  } catch {
    inboxes.value = [];
  }
}

async function startConversation() {
  if (!startConvForm.value.inbox_id || !startConvForm.value.message.trim())
    return;
  startConvLoading.value = true;
  startConvError.value = '';
  try {
    // 1. Find or create contact by phone
    let contactId = null;
    const phone = props.item.contact_phone;
    if (phone) {
      const { data: searchRes } = await axios.get(
        `/api/v1/accounts/${accountId.value}/contacts/search`,
        { params: { q: phone, include_contacts: true } }
      );
      const found = searchRes?.payload?.contacts?.[0];
      if (found) {
        contactId = found.id;
      } else {
        const { data: newContact } = await axios.post(
          `/api/v1/accounts/${accountId.value}/contacts`,
          { name: props.item.title, phone_number: phone }
        );
        contactId = newContact?.id;
      }
    }

    // 2. Create conversation
    const convPayload = { inbox_id: startConvForm.value.inbox_id };
    if (contactId) convPayload.contact_id = contactId;
    const { data: conv } = await axios.post(
      `/api/v1/accounts/${accountId.value}/conversations`,
      convPayload
    );
    const conversationId = conv?.id;
    if (!conversationId) throw new Error('Conversa não foi criada');

    // 3. Send first message
    await axios.post(
      `/api/v1/accounts/${accountId.value}/conversations/${conversationId}/messages`,
      {
        content: startConvForm.value.message.trim(),
        message_type: 'outgoing',
        private: false,
      }
    );

    // 4. Link conversation to kanban item
    await store.dispatch('kanban/updateItem', {
      pipelineId: props.pipelineId,
      id: props.item.id,
      conversation_id: conversationId,
    });

    showStartConversation.value = false;
    startConvForm.value = {
      inbox_id: inboxes.value[0]?.id || null,
      message: '',
    };
    store.dispatch('kanban/fetchActivities', {
      pipelineId: props.pipelineId,
      itemId: props.item.id,
    });
  } catch (e) {
    startConvError.value =
      e?.response?.data?.message || e.message || 'Erro ao iniciar conversa';
  } finally {
    startConvLoading.value = false;
  }
}

const currentAssignee = computed(
  () =>
    agents.value.find(a => a.id === form.value.assignee_id) ||
    props.item?.assignee ||
    null
);

// ─── Lost reasons (for picker) ───────────────────────────────────────────────
const lostReasons = computed(() => store.getters['kanban/getLostReasons']);

// ─── Mover CRM ───────────────────────────────────────────────────────────────
const pipelines = computed(() => store.getters['kanban/getPipelines']);
const showMoverCRM = ref(false);
const moverPipelineId = ref(null);
const moverStageId = ref(null);
const moverStages = ref([]);
const moverLoading = ref(false);

watch(moverPipelineId, async pid => {
  moverStageId.value = null;
  moverStages.value = [];
  if (!pid) return;
  if (pid === props.pipelineId) {
    moverStages.value = stages.value;
  } else {
    await store.dispatch('kanban/fetchPipelineStages', pid);
    moverStages.value =
      store.getters['kanban/getPipelineStagesCache'](pid) || [];
  }
});

function openMoverCRM() {
  moverPipelineId.value = props.pipelineId;
  moverStageId.value = props.item.stage_id;
  moverStages.value = stages.value;
  showMoverCRM.value = true;
}

async function confirmMoverCRM() {
  if (!moverStageId.value) return;
  moverLoading.value = true;
  try {
    if (moverPipelineId.value === props.pipelineId) {
      await store.dispatch('kanban/moveItem', {
        pipelineId: props.pipelineId,
        id: props.item.id,
        stageId: moverStageId.value,
        position: 0,
      });
    } else {
      await store.dispatch('kanban/transferItem', {
        pipelineId: props.pipelineId,
        id: props.item.id,
        targetPipelineId: moverPipelineId.value,
        stageId: moverStageId.value,
      });
    }
    showMoverCRM.value = false;
    store.dispatch('kanban/fetchActivities', {
      pipelineId: moverPipelineId.value,
      itemId: props.item.id,
    });
    emit('updated');
  } catch (e) {
    statusError.value =
      e?.response?.data?.message || e?.message || 'Erro ao mover card.';
    showMoverCRM.value = false;
  } finally {
    moverLoading.value = false;
  }
}

// ─── Contact section ─────────────────────────────────────────────────────────
const linkedContact = ref(null);
const showContactSearch = ref(false);
const contactSearchQuery = ref('');
const contactSearchResults = ref([]);
const contactSearchLoading = ref(false);

watch(
  () => props.item?.contact_id,
  async cid => {
    if (!cid) {
      linkedContact.value = null;
      return;
    }
    try {
      const { data } = await axios.get(
        `/api/v1/accounts/${accountId.value}/contacts/${cid}`
      );
      linkedContact.value = data;
    } catch {
      linkedContact.value = null;
    }
  },
  { immediate: true }
);

let contactSearchTimeout = null;
watch(contactSearchQuery, q => {
  clearTimeout(contactSearchTimeout);
  if (q.length < 2) {
    contactSearchResults.value = [];
    return;
  }
  contactSearchLoading.value = true;
  contactSearchTimeout = setTimeout(async () => {
    try {
      const { data } = await axios.get(
        `/api/v1/accounts/${accountId.value}/contacts/search`,
        { params: { q, include_contacts: true } }
      );
      contactSearchResults.value = data?.payload?.contacts || [];
    } catch {
      contactSearchResults.value = [];
    } finally {
      contactSearchLoading.value = false;
    }
  }, 300);
});

async function linkContact(contact) {
  await store.dispatch('kanban/updateItem', {
    pipelineId: props.pipelineId,
    id: props.item.id,
    contact_id: contact.id,
  });
  linkedContact.value = contact;
  showContactSearch.value = false;
  contactSearchQuery.value = '';
  store.dispatch('kanban/fetchActivities', {
    pipelineId: props.pipelineId,
    itemId: props.item.id,
  });
}

async function unlinkContact() {
  await store.dispatch('kanban/updateItem', {
    pipelineId: props.pipelineId,
    id: props.item.id,
    contact_id: null,
  });
  linkedContact.value = null;
}

// ─── Edit Lead modal ─────────────────────────────────────────────────────────
const showEditModal = ref(false);
const editLead = reactive({
  title: '',
  phone: '',
  cpf: '',
  gender: '',
  birthdate: '',
  zipCode: '',
  street: '',
  streetNumber: '',
  addressComplement: '',
  neighborhood: '',
  city: '',
  state: '',
  assigneeId: '',
  notes: '',
});
const editCepLoading = ref(false);
const editSaving = ref(false);

function openEditModal() {
  const c = linkedContact.value;
  const a = c?.additional_attributes || {};
  editLead.title = props.item.title || '';
  editLead.phone = props.item.contact_phone || c?.phone_number || '';
  editLead.cpf = a.cpf || '';
  editLead.gender = a.gender || '';
  editLead.birthdate = a.birthdate || '';
  editLead.zipCode = a.zip_code || '';
  editLead.street = a.street || '';
  editLead.streetNumber = a.street_number || '';
  editLead.addressComplement = a.address_complement || '';
  editLead.neighborhood = a.neighborhood || '';
  editLead.city = a.city || '';
  editLead.state = a.state || '';
  editLead.assigneeId = props.item.assignee?.id || '';
  editLead.notes = '';
  showEditModal.value = true;
}

async function lookupEditCep() {
  const clean = editLead.zipCode.replace(/\D/g, '');
  if (clean.length !== 8) return;
  editCepLoading.value = true;
  try {
    const res = await fetch(`https://viacep.com.br/ws/${clean}/json/`);
    const json = await res.json();
    if (!json.erro) {
      editLead.street = json.logradouro || editLead.street;
      editLead.neighborhood = json.bairro || editLead.neighborhood;
      editLead.city = json.localidade || editLead.city;
      editLead.state = json.uf || editLead.state;
    }
  } catch {
    /* ignore */
  } finally {
    editCepLoading.value = false;
  }
}

async function saveEditLead() {
  editSaving.value = true;
  try {
    await store.dispatch('kanban/updateItem', {
      pipelineId: props.pipelineId,
      id: props.item.id,
      title: editLead.title.trim() || undefined,
      contact_phone: editLead.phone.trim() || undefined,
      assignee_id: editLead.assigneeId || null,
    });

    if (linkedContact.value?.id) {
      const additionalAttributes = {};
      if (editLead.cpf !== undefined) additionalAttributes.cpf = editLead.cpf;
      if (editLead.gender !== undefined)
        additionalAttributes.gender = editLead.gender;
      if (editLead.birthdate !== undefined)
        additionalAttributes.birthdate = editLead.birthdate;
      if (editLead.zipCode !== undefined)
        additionalAttributes.zip_code = editLead.zipCode;
      if (editLead.street !== undefined)
        additionalAttributes.street = editLead.street;
      if (editLead.streetNumber !== undefined)
        additionalAttributes.street_number = editLead.streetNumber;
      if (editLead.addressComplement !== undefined)
        additionalAttributes.address_complement = editLead.addressComplement;
      if (editLead.neighborhood !== undefined)
        additionalAttributes.neighborhood = editLead.neighborhood;
      if (editLead.city !== undefined)
        additionalAttributes.city = editLead.city;
      if (editLead.state !== undefined)
        additionalAttributes.state = editLead.state;

      await ContactsAPI.update(linkedContact.value.id, {
        name: editLead.title.trim() || linkedContact.value.name,
        phone_number: editLead.phone.trim() || undefined,
        additional_attributes: additionalAttributes,
      });
    }

    if (editLead.notes.trim()) {
      await store.dispatch('kanban/createNote', {
        pipelineId: props.pipelineId,
        itemId: props.item.id,
        content: editLead.notes.trim(),
      });
    }

    showEditModal.value = false;
    store.dispatch('kanban/fetchActivities', {
      pipelineId: props.pipelineId,
      itemId: props.item.id,
    });
  } catch {
    /* ignore */
  } finally {
    editSaving.value = false;
  }
}
</script>

<template>
  <div
    v-if="item"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-0 sm:p-4"
    @click.self="emit('close')"
  >
    <div
      class="relative bg-white dark:bg-slate-800 w-full h-full sm:rounded-2xl sm:shadow-2xl sm:w-[84vw] sm:max-w-5xl sm:h-[90vh] flex flex-col overflow-hidden"
    >
      <!-- Header -->
      <div
        class="flex items-start gap-3 px-6 py-4 border-b border-slate-200 dark:border-slate-700 shrink-0"
      >
        <div
          class="shrink-0 mt-0.5 size-2.5 rounded-full"
          :style="{ backgroundColor: currentStage?.color || '#6366f1' }"
        />
        <div class="flex-1 min-w-0">
          <div v-if="editingTitle" class="flex items-center gap-2">
            <input
              v-model="titleDraft"
              type="text"
              class="flex-1 text-base font-semibold bg-transparent border-b-2 border-woot-500 focus:outline-none pb-0.5 text-slate-800 dark:text-slate-100"
              autofocus
              @keyup.enter="saveTitle"
              @keyup.escape="editingTitle = false"
            />
            <button
              class="text-xs px-2 py-1 rounded bg-woot-500 text-white"
              @click="saveTitle"
            >
              OK
            </button>
            <button
              class="text-xs px-2 py-1 rounded text-slate-500"
              @click="editingTitle = false"
            >
              ×
            </button>
          </div>
          <h2
            v-else
            class="text-base font-semibold text-slate-800 dark:text-slate-100 cursor-pointer hover:text-woot-500 transition-colors truncate"
            @click="
              editingTitle = true;
              titleDraft = item.title;
            "
          >
            {{ item.title }}
            <span class="i-lucide-pencil size-3.5 ml-1 opacity-40" />
          </h2>
          <div class="flex items-center gap-2 mt-0.5">
            <span
              v-if="item.status !== 'open'"
              class="text-[10px] font-semibold px-1.5 py-0.5 rounded border"
              :class="
                item.status === 'won'
                  ? 'text-green-700 bg-green-50 border-green-200'
                  : 'text-red-700 bg-red-50 border-red-200'
              "
              >{{ item.status === 'won' ? '🏆 Ganho' : '❌ Perdido' }}</span
            >
            <span
              v-if="item.source"
              class="text-[10px] text-slate-500 bg-slate-100 dark:bg-slate-700 px-1.5 py-0.5 rounded capitalize"
              >{{ item.source }}</span
            >
            <span
              v-if="stageProbability > 0"
              class="text-[10px] text-woot-600 bg-woot-50 dark:bg-woot-900/30 px-1.5 py-0.5 rounded font-medium"
            >
              {{ stageProbability }}% (etapa)
            </span>
          </div>
        </div>
        <button
          class="shrink-0 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 transition-colors"
          @click="emit('close')"
        >
          <span class="i-lucide-x size-5" />
        </button>
      </div>

      <!-- Two-column body -->
      <div class="flex-1 flex overflow-hidden min-h-0">
        <!-- LEFT COLUMN -->
        <div
          class="w-64 shrink-0 border-r border-slate-200 dark:border-slate-700 overflow-y-auto p-4 space-y-4 bg-slate-50 dark:bg-slate-900/40"
        >
          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Valor</label
            >
            <input
              v-model="form.value"
              type="number"
              min="0"
              step="0.01"
              class="w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              @change="saveField('value')"
            />
          </div>

          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Etapa atual</label
            >
            <p
              class="text-sm text-slate-700 dark:text-slate-300 font-medium mb-1.5 truncate"
            >
              {{ currentStage?.name || '—' }}
            </p>
            <button
              class="w-full flex items-center justify-center gap-2 text-xs px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 font-medium transition-colors"
              @click="openMoverCRM"
            >
              <span class="i-lucide-move-right size-3.5" />
              Mover CRM
            </button>
          </div>

          <!-- Assignee -->
          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Responsável</label
            >
            <div v-if="currentAssignee" class="flex items-center gap-2 mb-1.5">
              <img
                v-if="currentAssignee.avatar_url"
                :src="currentAssignee.avatar_url"
                class="size-5 rounded-full shrink-0"
              />
              <span
                v-else
                class="size-5 rounded-full bg-woot-100 dark:bg-woot-800 flex items-center justify-center text-[10px] font-bold text-woot-600 shrink-0"
              >
                {{ currentAssignee.name?.[0]?.toUpperCase() }}
              </span>
              <span
                class="text-xs text-slate-700 dark:text-slate-300 truncate"
                >{{ currentAssignee.name }}</span
              >
            </div>
            <select
              v-model="form.assignee_id"
              class="w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              @change="saveField('assignee_id')"
            >
              <option :value="null">Sem responsável</option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
          </div>

          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Origem</label
            >
            <select
              v-model="form.source"
              class="w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              @change="saveField('source')"
            >
              <option v-for="s in SOURCES" :key="s.value" :value="s.value">
                {{ s.label }}
              </option>
            </select>
          </div>

          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Temperatura</label
            >
            <select
              v-model="form.temperature"
              class="w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              @change="saveField('temperature')"
            >
              <option v-for="t in TEMPERATURES" :key="t.value" :value="t.value">
                {{ t.label }}
              </option>
            </select>
          </div>

          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Probabilidade</label
            >
            <p class="text-sm font-semibold text-woot-600 dark:text-woot-400">
              {{ stageProbability }}%
              <span class="text-[10px] text-slate-400 font-normal"
                >(baseada na etapa)</span
              >
            </p>
          </div>

          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Previsão de fechamento</label
            >
            <input
              v-model="form.expected_close_date"
              type="date"
              class="w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              @change="saveField('expected_close_date')"
            />
          </div>

          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Telefone</label
            >
            <div class="flex items-center gap-1.5">
              <input
                v-model="form.contact_phone"
                type="text"
                placeholder="+55..."
                class="flex-1 text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                @change="saveField('contact_phone')"
              />
              <a
                v-if="conversationLink"
                :href="conversationLink"
                target="_blank"
                rel="noopener noreferrer"
                class="text-woot-500 hover:text-woot-600"
                title="Abrir conversa no Chatwoot"
              >
                <span class="i-lucide-message-square size-4" />
              </a>
            </div>
          </div>

          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Score</label
            >
            <div class="flex gap-1">
              <button
                v-for="star in 5"
                :key="star"
                class="transition-colors"
                :class="
                  star <= form.score
                    ? 'text-yellow-400'
                    : 'text-slate-300 hover:text-yellow-300'
                "
                @click="
                  form.score = star;
                  saveField('score');
                "
              >
                <span class="i-lucide-star size-4" />
              </button>
            </div>
          </div>

          <div v-if="item.conversation_id">
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Conversa</label
            >
            <span
              class="inline-flex items-center gap-1 text-sm text-woot-600 dark:text-woot-400"
            >
              <span class="i-lucide-message-square size-3.5" />
              #{{ item.conversation_id }}
            </span>
          </div>

          <!-- Contato CRM -->
          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Contato CRM</label
            >
            <div v-if="linkedContact" class="flex items-center gap-2 mb-1.5">
              <img
                v-if="linkedContact.thumbnail"
                :src="linkedContact.thumbnail"
                class="size-6 rounded-full shrink-0"
              />
              <span
                v-else
                class="size-6 rounded-full bg-blue-100 dark:bg-blue-900/40 flex items-center justify-center text-[10px] font-bold text-blue-600 shrink-0"
              >
                {{ linkedContact.name?.[0]?.toUpperCase() }}
              </span>
              <div class="flex-1 min-w-0">
                <p
                  class="text-xs text-slate-700 dark:text-slate-300 truncate font-medium"
                >
                  {{ linkedContact.name }}
                </p>
                <p
                  v-if="linkedContact.phone_number"
                  class="text-[10px] text-slate-400 truncate"
                >
                  {{ linkedContact.phone_number }}
                </p>
              </div>
              <button
                class="text-slate-400 hover:text-red-500 shrink-0"
                title="Desvincular"
                @click="unlinkContact"
              >
                <span class="i-lucide-x size-3.5" />
              </button>
            </div>
            <button
              class="w-full flex items-center justify-center gap-2 text-xs px-2.5 py-1.5 rounded-lg border border-dashed border-slate-300 dark:border-slate-600 text-slate-500 hover:border-woot-400 hover:text-woot-500 transition-colors"
              @click="showContactSearch = !showContactSearch"
            >
              <span class="i-lucide-user-plus size-3.5" />
              {{ linkedContact ? 'Trocar contato' : 'Vincular contato' }}
            </button>
            <div v-if="showContactSearch" class="mt-2 space-y-1.5">
              <input
                v-model="contactSearchQuery"
                type="text"
                placeholder="Buscar por nome, telefone..."
                class="w-full text-xs border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              />
              <div v-if="contactSearchLoading" class="py-1.5 text-center">
                <span
                  class="i-lucide-loader-2 size-4 animate-spin text-slate-400 mx-auto block"
                />
              </div>
              <div
                v-else-if="contactSearchResults.length"
                class="border border-slate-200 dark:border-slate-700 rounded-lg overflow-hidden"
              >
                <button
                  v-for="c in contactSearchResults.slice(0, 5)"
                  :key="c.id"
                  class="w-full flex items-center gap-2 px-2.5 py-2 text-left hover:bg-slate-50 dark:hover:bg-slate-700 text-xs text-slate-700 dark:text-slate-300 border-b border-slate-100 dark:border-slate-700 last:border-b-0"
                  @click="linkContact(c)"
                >
                  <span
                    class="i-lucide-user size-3.5 text-slate-400 shrink-0"
                  />
                  <span class="flex-1 truncate font-medium">{{ c.name }}</span>
                  <span class="text-[10px] text-slate-400 shrink-0">{{
                    c.phone_number
                  }}</span>
                </button>
              </div>
            </div>
          </div>

          <div class="border-t border-slate-200 dark:border-slate-700 pt-3">
            <p class="text-[10px] text-slate-400">
              Criado: {{ formatTs(item.created_at) }}
            </p>
            <p class="text-[10px] text-slate-400 mt-0.5">
              Atualizado: {{ formatTs(item.updated_at) }}
            </p>
          </div>

          <div class="flex flex-col gap-1.5 pt-1">
            <button
              class="w-full flex items-center justify-center gap-2 text-xs px-3 py-2 rounded-lg bg-woot-50 dark:bg-woot-900/20 text-woot-600 dark:text-woot-400 hover:bg-woot-100 dark:hover:bg-woot-900/40 font-medium transition-colors border border-woot-200 dark:border-woot-700"
              @click="openEditModal"
            >
              <span class="i-lucide-pencil size-3.5" /> Editar Lead
            </button>
            <p
              v-if="statusError"
              class="text-[10px] text-red-600 bg-red-50 rounded-lg px-2 py-1.5 leading-snug"
            >
              {{ statusError }}
            </p>
            <button
              v-if="item.status !== 'won'"
              :disabled="statusLoading"
              class="w-full flex items-center justify-center gap-2 text-xs px-3 py-2 rounded-lg bg-green-100 text-green-700 hover:bg-green-200 font-medium transition-colors disabled:opacity-50"
              @click="markWon"
            >
              <span
                :class="
                  statusLoading
                    ? 'i-lucide-loader-circle animate-spin'
                    : 'i-lucide-trophy'
                "
                class="size-3.5"
              />
              Marcar como Ganho
            </button>
            <button
              v-if="item.status !== 'lost'"
              :disabled="statusLoading"
              class="w-full flex items-center justify-center gap-2 text-xs px-3 py-2 rounded-lg bg-red-50 text-red-600 hover:bg-red-100 font-medium transition-colors disabled:opacity-50"
              @click="openLostPicker"
            >
              <span
                :class="
                  statusLoading
                    ? 'i-lucide-loader-circle animate-spin'
                    : 'i-lucide-x-circle'
                "
                class="size-3.5"
              />
              Marcar como Perdido
            </button>
            <button
              v-if="item.status !== 'open'"
              class="w-full flex items-center justify-center gap-2 text-xs px-3 py-2 rounded-lg bg-slate-100 text-slate-600 hover:bg-slate-200 font-medium transition-colors"
              @click="reopenItem"
            >
              <span class="i-lucide-rotate-ccw size-3.5" /> Reabrir Lead
            </button>
            <button
              class="w-full flex items-center justify-center gap-2 text-xs px-3 py-2 rounded-lg bg-slate-100 text-slate-500 hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-400 dark:hover:bg-slate-600 font-medium transition-colors"
              @click="deleteItem"
            >
              <span class="i-lucide-trash-2 size-3.5" /> Excluir card
            </button>
          </div>
        </div>

        <!-- RIGHT COLUMN — tabs -->
        <div class="flex-1 flex flex-col min-w-0 overflow-hidden">
          <div
            class="flex items-center border-b border-slate-200 dark:border-slate-700 shrink-0 overflow-x-auto"
          >
            <button
              v-for="tab in TABS"
              :key="tab.id"
              class="flex items-center gap-1.5 px-4 py-3 text-xs font-medium whitespace-nowrap border-b-2 transition-colors"
              :class="
                activeTab === tab.id
                  ? 'border-woot-500 text-woot-600 dark:text-woot-400'
                  : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
              "
              @click="activeTab = tab.id"
            >
              <span class="size-3.5" :class="[tab.icon]" />
              {{ tab.label }}
              <span
                v-if="tab.id === 'tasks' && pendingTasks.length > 0"
                class="size-4 rounded-full bg-amber-100 text-amber-700 text-[10px] font-bold flex items-center justify-center"
              >
                {{ pendingTasks.length }}
              </span>
            </button>
          </div>

          <div class="flex-1 overflow-y-auto p-4">
            <!-- ACTIVITIES -->
            <div v-if="activeTab === 'activities'">
              <div
                v-if="activities.length === 0"
                class="flex flex-col items-center py-12 text-slate-400"
              >
                <span class="i-lucide-activity size-10 mb-3 opacity-40" />
                <p class="text-sm">Nenhuma atividade registrada</p>
              </div>
              <div v-else class="relative">
                <div
                  class="absolute left-3.5 top-0 bottom-0 w-px bg-slate-200 dark:bg-slate-700"
                />
                <div class="space-y-4">
                  <div
                    v-for="act in activities"
                    :key="act.id"
                    class="flex gap-3 relative"
                  >
                    <div
                      class="shrink-0 size-7 rounded-full bg-white dark:bg-slate-800 border-2 border-slate-200 dark:border-slate-700 flex items-center justify-center z-10"
                    >
                      <span
                        class="size-3.5"
                        :class="[
                          activityIcon(act.action_type).icon,
                          activityIcon(act.action_type).cls,
                        ]"
                      />
                    </div>
                    <div class="flex-1 pb-1 min-w-0">
                      <p
                        class="text-sm text-slate-700 dark:text-slate-300 font-medium"
                      >
                        {{ activityLabel(act) }}
                      </p>
                      <p
                        v-if="activityDescription(act)"
                        class="text-xs text-slate-500 mt-0.5"
                      >
                        {{ activityDescription(act) }}
                      </p>
                      <p class="text-[10px] text-slate-400 mt-0.5">
                        {{ formatTs(act.created_at) }}
                        <span v-if="act.author?.name" class="ml-1"
                          >· {{ act.author.name }}</span
                        >
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- TASKS -->
            <div v-else-if="activeTab === 'tasks'" class="space-y-3">
              <!-- Progress -->
              <div class="flex items-center justify-between mb-1">
                <span
                  class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >
                  {{ completedTasks.length }} de {{ tasks.length }} tarefas
                  concluídas
                </span>
                <button
                  class="flex items-center gap-1 text-xs text-woot-600 hover:text-woot-700 font-medium"
                  @click="showNewTaskForm = !showNewTaskForm"
                >
                  <span class="i-lucide-plus size-3.5" />
                  Nova Tarefa
                </button>
              </div>
              <div v-if="tasks.length > 0" class="flex items-center gap-2 mb-3">
                <div
                  class="flex-1 h-1.5 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden"
                >
                  <div
                    class="h-full bg-green-500 rounded-full transition-all"
                    :style="{
                      width: `${tasks.length ? (completedTasks.length / tasks.length) * 100 : 0}%`,
                    }"
                  />
                </div>
              </div>

              <!-- New task form -->
              <div
                v-if="showNewTaskForm"
                class="bg-white dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-xl p-4 space-y-3"
              >
                <input
                  v-model="newTask.title"
                  type="text"
                  placeholder="Título da tarefa *"
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  autofocus
                  @keyup.enter="createTask"
                />
                <textarea
                  v-model="newTask.description"
                  rows="2"
                  placeholder="Descrição (opcional)"
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500 resize-none"
                />
                <div class="grid grid-cols-2 gap-2">
                  <div>
                    <label
                      class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                      >Responsável</label
                    >
                    <select
                      v-model="newTask.assignee_id"
                      class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                    >
                      <option :value="null">Ninguém</option>
                      <option v-for="a in agents" :key="a.id" :value="a.id">
                        {{ a.name }}
                      </option>
                    </select>
                  </div>
                  <div>
                    <label
                      class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                      >Prioridade</label
                    >
                    <select
                      v-model="newTask.priority"
                      class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                    >
                      <option
                        v-for="p in PRIORITIES"
                        :key="p.value"
                        :value="p.value"
                      >
                        {{ p.label }}
                      </option>
                    </select>
                  </div>
                </div>
                <div class="grid grid-cols-2 gap-2">
                  <div>
                    <label
                      class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                      >Data início</label
                    >
                    <input
                      v-model="newTask.start_date"
                      type="date"
                      class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                    />
                  </div>
                  <div>
                    <label
                      class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                      >Data limite</label
                    >
                    <input
                      v-model="newTask.due_at"
                      type="datetime-local"
                      class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                    />
                  </div>
                </div>
                <!-- Recurrence toggle -->
                <label
                  class="flex items-center gap-2 cursor-pointer select-none"
                >
                  <input
                    v-model="newTask.is_recurring"
                    type="checkbox"
                    class="size-3.5 rounded border-slate-300 text-woot-500 focus:ring-woot-400"
                  />
                  <span
                    class="text-xs text-slate-600 dark:text-slate-300 font-medium"
                    >Tarefa recorrente</span
                  >
                </label>
                <!-- Recurrence section -->
                <div
                  v-if="newTask.is_recurring"
                  class="border border-purple-200 dark:border-purple-800 bg-purple-50 dark:bg-purple-900/20 rounded-lg p-3 space-y-2"
                >
                  <div class="grid grid-cols-2 gap-2">
                    <div>
                      <label
                        class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                        >Frequência</label
                      >
                      <select
                        v-model="newTask.recurrence_frequency"
                        class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                      >
                        <option
                          v-for="f in RECURRENCE_FREQUENCIES"
                          :key="f.value"
                          :value="f.value"
                        >
                          {{ f.label }}
                        </option>
                      </select>
                    </div>
                    <div>
                      <label
                        class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                        >Intervalo</label
                      >
                      <input
                        v-model.number="newTask.recurrence_interval"
                        type="number"
                        min="1"
                        class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                      />
                    </div>
                  </div>
                  <div>
                    <label
                      class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                      >Até quando</label
                    >
                    <input
                      v-model="newTask.recurrence_end_date"
                      type="date"
                      class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                    />
                  </div>
                </div>
                <p
                  v-if="taskError"
                  class="text-xs text-red-600 bg-red-50 rounded px-2 py-1"
                >
                  {{ taskError }}
                </p>
                <div class="flex gap-2">
                  <button
                    class="text-xs px-3 py-1.5 rounded-lg border border-slate-300 text-slate-600 hover:bg-slate-100 font-medium"
                    @click="
                      showNewTaskForm = false;
                      taskError = '';
                    "
                  >
                    Cancelar
                  </button>
                  <button
                    :disabled="!newTask.title.trim() || savingTask"
                    class="text-xs px-4 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium disabled:opacity-50 flex items-center gap-1.5"
                    @click="createTask"
                  >
                    <span
                      v-if="savingTask"
                      class="i-lucide-loader-2 size-3 animate-spin"
                    />
                    Criar Tarefa
                  </button>
                </div>
              </div>

              <!-- Pending tasks -->
              <div v-if="pendingTasks.length > 0" class="space-y-2">
                <p
                  class="text-[10px] font-semibold text-slate-400 uppercase tracking-wider"
                >
                  Pendentes
                </p>
                <div v-for="task in pendingTasks" :key="task.id">
                  <!-- Edit mode -->
                  <div
                    v-if="editingTaskId === task.id"
                    class="bg-white dark:bg-slate-700 border border-woot-300 dark:border-woot-600 rounded-xl p-3 space-y-2"
                  >
                    <input
                      v-model="taskEditForm.title"
                      type="text"
                      class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                    />
                    <textarea
                      v-model="taskEditForm.description"
                      rows="2"
                      placeholder="Descrição"
                      class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none resize-none"
                    />
                    <div class="grid grid-cols-2 gap-2">
                      <select
                        v-model="taskEditForm.assignee_id"
                        class="text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                      >
                        <option :value="null">Ninguém</option>
                        <option v-for="a in agents" :key="a.id" :value="a.id">
                          {{ a.name }}
                        </option>
                      </select>
                      <select
                        v-model="taskEditForm.priority"
                        class="text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                      >
                        <option
                          v-for="p in PRIORITIES"
                          :key="p.value"
                          :value="p.value"
                        >
                          {{ p.label }}
                        </option>
                      </select>
                    </div>
                    <div class="grid grid-cols-2 gap-2">
                      <div>
                        <label
                          class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                          >Data início</label
                        >
                        <input
                          v-model="taskEditForm.start_date"
                          type="date"
                          class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                        />
                      </div>
                      <div>
                        <label
                          class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                          >Data limite</label
                        >
                        <input
                          v-model="taskEditForm.due_at"
                          type="datetime-local"
                          class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                        />
                      </div>
                    </div>
                    <!-- Recurrence toggle -->
                    <label
                      class="flex items-center gap-2 cursor-pointer select-none"
                    >
                      <input
                        v-model="taskEditForm.is_recurring"
                        type="checkbox"
                        class="size-3.5 rounded border-slate-300 text-woot-500 focus:ring-woot-400"
                      />
                      <span
                        class="text-xs text-slate-600 dark:text-slate-300 font-medium"
                        >Tarefa recorrente</span
                      >
                    </label>
                    <div
                      v-if="taskEditForm.is_recurring"
                      class="border border-purple-200 dark:border-purple-800 bg-purple-50 dark:bg-purple-900/20 rounded-lg p-3 space-y-2"
                    >
                      <div class="grid grid-cols-2 gap-2">
                        <div>
                          <label
                            class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                            >Frequência</label
                          >
                          <select
                            v-model="taskEditForm.recurrence_frequency"
                            class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                          >
                            <option
                              v-for="f in RECURRENCE_FREQUENCIES"
                              :key="f.value"
                              :value="f.value"
                            >
                              {{ f.label }}
                            </option>
                          </select>
                        </div>
                        <div>
                          <label
                            class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                            >Intervalo</label
                          >
                          <input
                            v-model.number="taskEditForm.recurrence_interval"
                            type="number"
                            min="1"
                            class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                          />
                        </div>
                      </div>
                      <div>
                        <label
                          class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                          >Até quando</label
                        >
                        <input
                          v-model="taskEditForm.recurrence_end_date"
                          type="date"
                          class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none"
                        />
                      </div>
                    </div>
                    <div class="flex gap-2">
                      <button
                        class="text-xs px-2 py-1 rounded border border-slate-300 text-slate-600"
                        @click="editingTaskId = null"
                      >
                        Cancelar
                      </button>
                      <button
                        class="text-xs px-3 py-1 rounded bg-woot-500 text-white"
                        @click="saveEditTask(task)"
                      >
                        Salvar
                      </button>
                    </div>
                  </div>

                  <!-- View mode -->
                  <div
                    v-else
                    class="group rounded-xl border-l-4 bg-white dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700 px-3 py-2.5"
                    :class="[taskStatusInfo(task)?.cls || 'border-l-slate-300']"
                    :style="{
                      borderLeftColor: PRIORITIES[task.priority]?.border
                        ? undefined
                        : undefined,
                    }"
                  >
                    <div class="flex items-start gap-2.5">
                      <button
                        class="shrink-0 mt-0.5 size-4 rounded border-2 border-slate-400 dark:border-slate-500 bg-white dark:bg-slate-600 hover:border-green-500 hover:bg-green-50 dark:hover:bg-green-900/20 transition-colors"
                        @click="toggleTask(task)"
                      />
                      <div class="flex-1 min-w-0">
                        <p
                          class="text-sm text-slate-800 dark:text-slate-100 font-medium"
                        >
                          {{ task.title }}
                        </p>
                        <p
                          v-if="task.description"
                          class="text-xs text-slate-500 mt-0.5 line-clamp-2"
                        >
                          {{ task.description }}
                        </p>
                        <div class="flex items-center gap-2 mt-1.5 flex-wrap">
                          <span
                            class="text-[10px] font-medium px-1.5 py-0.5 rounded"
                            :class="PRIORITIES[task.priority]?.cls"
                          >
                            {{ PRIORITIES[task.priority]?.label }}
                          </span>
                          <span
                            v-if="task.assignee"
                            class="flex items-center gap-1 text-[10px] text-slate-500"
                          >
                            <img
                              v-if="task.assignee.avatar_url"
                              :src="task.assignee.avatar_url"
                              class="size-3 rounded-full"
                            />
                            {{ task.assignee.name }}
                          </span>
                          <span
                            v-if="task.start_date"
                            class="text-[10px] text-slate-400 flex items-center gap-0.5"
                          >
                            <span class="i-lucide-play size-3" />
                            {{ formatDate(task.start_date) }}
                          </span>
                          <span
                            v-if="formatDue(task)"
                            class="text-[10px] text-slate-400 flex items-center gap-0.5"
                          >
                            <span class="i-lucide-calendar size-3" />
                            {{ formatDue(task) }}
                          </span>
                          <span
                            v-if="task.is_recurring"
                            class="text-[10px] font-medium px-1.5 py-0.5 rounded bg-purple-100 text-purple-600 dark:bg-purple-900/30 dark:text-purple-400"
                          >
                            ↻
                            {{
                              RECURRENCE_LABELS[task.recurrence_frequency] ||
                              'Recorrente'
                            }}
                          </span>
                          <span
                            v-if="taskStatusInfo(task)"
                            class="text-[10px] font-medium px-1.5 py-0.5 rounded"
                            :class="taskStatusInfo(task)?.badge"
                          >
                            {{ taskStatusInfo(task)?.label }}
                          </span>
                        </div>
                      </div>
                      <div
                        class="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity shrink-0"
                      >
                        <button
                          class="text-slate-400 hover:text-woot-500 p-1"
                          @click="startEditTask(task)"
                        >
                          <span class="i-lucide-pencil size-3.5" />
                        </button>
                        <button
                          class="text-slate-400 hover:text-red-500 p-1"
                          @click="deleteTask(task.id)"
                        >
                          <span class="i-lucide-trash-2 size-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Completed tasks -->
              <div v-if="completedTasks.length > 0" class="space-y-2">
                <p
                  class="text-[10px] font-semibold text-slate-400 uppercase tracking-wider"
                >
                  Concluídas
                </p>
                <div
                  v-for="task in completedTasks"
                  :key="task.id"
                  class="group flex items-center gap-2.5 bg-slate-50 dark:bg-slate-700/30 rounded-xl px-3 py-2 opacity-60"
                >
                  <button
                    class="shrink-0 size-4 rounded border-2 border-green-500 bg-green-500 flex items-center justify-center hover:opacity-70"
                    @click="toggleTask(task)"
                  >
                    <span class="i-lucide-check size-3 text-white" />
                  </button>
                  <span class="flex-1 text-sm text-slate-500 line-through">{{
                    task.title
                  }}</span>
                  <span class="text-[10px] text-slate-400">{{
                    formatTs(task.completed_at)
                  }}</span>
                  <button
                    class="opacity-0 group-hover:opacity-100 text-slate-400 hover:text-red-500"
                    @click="deleteTask(task.id)"
                  >
                    <span class="i-lucide-trash-2 size-3.5" />
                  </button>
                </div>
              </div>

              <div
                v-if="tasks.length === 0 && !showNewTaskForm"
                class="flex flex-col items-center py-8 text-slate-400"
              >
                <span class="i-lucide-check-square size-9 mb-2 opacity-40" />
                <p class="text-sm">Nenhuma tarefa ainda</p>
                <button
                  class="mt-2 text-xs text-woot-600 hover:underline"
                  @click="showNewTaskForm = true"
                >
                  + Criar primeira tarefa
                </button>
              </div>
            </div>

            <!-- NOTES -->
            <div v-else-if="activeTab === 'notes'" class="space-y-3">
              <div class="space-y-2">
                <textarea
                  v-model="newNoteContent"
                  rows="3"
                  placeholder="Escreva uma nota..."
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500 resize-none"
                />
                <div class="flex justify-end">
                  <button
                    :disabled="!newNoteContent.trim() || savingNote"
                    class="flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium disabled:opacity-50"
                    @click="addNote"
                  >
                    <span class="i-lucide-send size-3.5" />Adicionar nota
                  </button>
                </div>
              </div>
              <div
                v-if="notes.length === 0"
                class="flex flex-col items-center py-8 text-slate-400"
              >
                <span class="i-lucide-sticky-note size-9 mb-2 opacity-40" />
                <p class="text-sm">Nenhuma nota ainda</p>
              </div>
              <div v-else class="space-y-3">
                <div
                  v-for="note in notes"
                  :key="note.id"
                  class="group bg-yellow-50 dark:bg-yellow-900/10 border border-yellow-100 dark:border-yellow-900/30 rounded-lg p-3"
                >
                  <p
                    class="text-sm text-slate-700 dark:text-slate-200 whitespace-pre-wrap"
                  >
                    {{ note.content }}
                  </p>
                  <div
                    class="flex items-center justify-between mt-2 pt-2 border-t border-yellow-100 dark:border-yellow-900/30"
                  >
                    <span class="text-[10px] text-slate-400">{{
                      formatTs(note.created_at)
                    }}</span>
                    <button
                      class="opacity-0 group-hover:opacity-100 text-slate-400 hover:text-red-500 transition-all"
                      @click="deleteNote(note.id)"
                    >
                      <span class="i-lucide-trash-2 size-3.5" />
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <!-- ATTACHMENTS -->
            <div v-else-if="activeTab === 'attachments'" class="space-y-3">
              <button
                class="flex items-center gap-2 text-sm px-4 py-2 rounded-lg border-2 border-dashed border-slate-300 dark:border-slate-600 text-slate-500 hover:border-woot-400 hover:text-woot-500 transition-colors font-medium"
                @click="fileInput?.click()"
              >
                <span class="i-lucide-upload size-4" />Enviar arquivo
              </button>
              <input
                ref="fileInput"
                type="file"
                class="hidden"
                @change="onFileSelected"
              />
              <div
                v-if="attachments.length === 0"
                class="flex flex-col items-center py-8 text-slate-400"
              >
                <span class="i-lucide-paperclip size-9 mb-2 opacity-40" />
                <p class="text-sm">Nenhum anexo</p>
              </div>
              <div v-else class="space-y-2">
                <div
                  v-for="att in attachments"
                  :key="att.id"
                  class="group flex items-center gap-3 p-3 rounded-lg bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700"
                >
                  <span class="i-lucide-file size-5 text-slate-400 shrink-0" />
                  <div class="flex-1 min-w-0">
                    <a
                      :href="att.url"
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-sm text-woot-600 dark:text-woot-400 hover:underline truncate block"
                      >{{ att.file_name }}</a
                    >
                    <span class="text-[10px] text-slate-400">{{
                      formatSize(att.file_size)
                    }}</span>
                  </div>
                  <button
                    class="opacity-0 group-hover:opacity-100 text-slate-400 hover:text-red-500"
                    @click="deleteAttachment(att.id)"
                  >
                    <span class="i-lucide-trash-2 size-3.5" />
                  </button>
                </div>
              </div>
            </div>

            <!-- WHATSAPP / CONVERSA -->
            <div v-else-if="activeTab === 'whatsapp'">
              <!-- Conversa já vinculada -->
              <div
                v-if="conversationLink"
                class="flex flex-col items-center py-12 text-center gap-4"
              >
                <span
                  class="i-lucide-message-square size-14 text-woot-500 mb-2 block mx-auto"
                />
                <p
                  class="text-base font-semibold text-slate-700 dark:text-slate-200"
                >
                  Conversa #{{ item.conversation_id }}
                </p>
                <div
                  v-if="item.contact_phone"
                  class="text-sm text-slate-500 flex items-center gap-1.5"
                >
                  <span class="i-lucide-phone size-3.5" />{{
                    item.contact_phone
                  }}
                </div>
                <a
                  :href="conversationLink"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-woot-500 text-white font-semibold text-sm hover:bg-woot-600 transition-colors shadow-md"
                >
                  <span class="i-lucide-message-square size-4" />Abrir no
                  Chatwoot
                </a>
              </div>

              <!-- Sem conversa — iniciar nova -->
              <div v-else class="max-w-sm mx-auto py-8 space-y-4">
                <div class="flex flex-col items-center text-center mb-4">
                  <span
                    class="i-lucide-message-square-off size-12 text-slate-300 mb-3 block"
                  />
                  <p
                    class="text-sm font-medium text-slate-600 dark:text-slate-300"
                  >
                    Nenhuma conversa vinculada
                  </p>
                  <p class="text-xs text-slate-400 mt-1">
                    Inicie uma conversa para vincular a este lead
                  </p>
                </div>

                <button
                  v-if="!showStartConversation"
                  class="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-woot-500 text-white font-semibold text-sm hover:bg-woot-600 transition-colors"
                  @click="
                    showStartConversation = true;
                    loadInboxes();
                  "
                >
                  <span class="i-lucide-send size-4" />Enviar mensagem
                </button>

                <div
                  v-if="showStartConversation"
                  class="bg-white dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-xl p-4 space-y-3"
                >
                  <div>
                    <label
                      class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                      >Caixa de entrada</label
                    >
                    <select
                      v-model="startConvForm.inbox_id"
                      class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                    >
                      <option v-if="inboxes.length === 0" :value="null">
                        Carregando inboxes...
                      </option>
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
                    <label
                      class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
                      >Mensagem inicial</label
                    >
                    <textarea
                      v-model="startConvForm.message"
                      rows="3"
                      placeholder="Digite a mensagem..."
                      class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-600 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500 resize-none"
                    />
                  </div>
                  <p
                    v-if="startConvError"
                    class="text-xs text-red-600 bg-red-50 rounded px-2 py-1"
                  >
                    {{ startConvError }}
                  </p>
                  <div class="flex gap-2">
                    <button
                      class="text-xs px-3 py-1.5 rounded-lg border border-slate-300 text-slate-600 hover:bg-slate-100"
                      @click="
                        showStartConversation = false;
                        startConvError = '';
                      "
                    >
                      Cancelar
                    </button>
                    <button
                      :disabled="
                        !startConvForm.inbox_id ||
                        !startConvForm.message.trim() ||
                        startConvLoading
                      "
                      class="flex-1 flex items-center justify-center gap-1.5 text-xs px-4 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium disabled:opacity-50"
                      @click="startConversation"
                    >
                      <span
                        v-if="startConvLoading"
                        class="i-lucide-loader-2 size-3 animate-spin"
                      />
                      <span v-else class="i-lucide-send size-3" />
                      {{
                        startConvLoading ? 'Enviando...' : 'Enviar e vincular'
                      }}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ── Mover CRM overlay ─────────────────────────────────────────────── -->
      <div
        v-if="showMoverCRM"
        class="absolute inset-0 z-10 flex items-center justify-center bg-black/40 rounded-2xl"
        @click.self="showMoverCRM = false"
      >
        <div
          class="bg-white dark:bg-slate-800 rounded-xl shadow-xl p-5 w-80 space-y-4"
        >
          <div class="flex items-center justify-between">
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              Mover CRM
            </h3>
            <button
              class="text-slate-400 hover:text-slate-600"
              @click="showMoverCRM = false"
            >
              <span class="i-lucide-x size-4" />
            </button>
          </div>
          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Pipeline</label
            >
            <select
              v-model="moverPipelineId"
              class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
            >
              <option v-for="p in pipelines" :key="p.id" :value="p.id">
                {{ p.name }}
              </option>
            </select>
          </div>
          <div>
            <label
              class="block text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1"
              >Etapa</label
            >
            <select
              v-model="moverStageId"
              class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
            >
              <option :value="null">Selecione uma etapa...</option>
              <option v-for="s in moverStages" :key="s.id" :value="s.id">
                {{ s.name }}
              </option>
            </select>
          </div>
          <div class="flex gap-2 pt-1">
            <button
              class="flex-1 px-3 py-2 text-xs rounded-lg border border-slate-300 text-slate-600 hover:bg-slate-100 font-medium"
              @click="showMoverCRM = false"
            >
              Cancelar
            </button>
            <button
              :disabled="!moverStageId || moverLoading"
              class="flex-1 px-3 py-2 text-xs rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium disabled:opacity-50 flex items-center justify-center gap-1.5"
              @click="confirmMoverCRM"
            >
              <span
                v-if="moverLoading"
                class="i-lucide-loader-2 size-3 animate-spin"
              />
              Confirmar
            </button>
          </div>
        </div>
      </div>

      <!-- ── Lost reason picker overlay ────────────────────────────────────── -->
      <div
        v-if="showLostPicker"
        class="absolute inset-0 z-10 flex items-center justify-center bg-black/40 rounded-2xl"
        @click.self="showLostPicker = false"
      >
        <div
          class="bg-white dark:bg-slate-800 rounded-xl shadow-xl p-5 w-80 space-y-4"
        >
          <div class="flex items-center justify-between">
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              Motivo da Perda
            </h3>
            <button
              class="text-slate-400 hover:text-slate-600"
              @click="showLostPicker = false"
            >
              <span class="i-lucide-x size-4" />
            </button>
          </div>
          <div class="space-y-1 max-h-56 overflow-y-auto">
            <button
              class="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm text-left transition-colors"
              :class="
                selectedLostReasonId === null
                  ? 'bg-woot-50 dark:bg-woot-900/30 text-woot-600 dark:text-woot-400 font-medium'
                  : 'text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700'
              "
              @click="selectedLostReasonId = null"
            >
              <span class="i-lucide-minus-circle size-4 text-slate-400" />
              Sem motivo específico
            </button>
            <button
              v-for="reason in lostReasons"
              :key="reason.id"
              class="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm text-left transition-colors"
              :class="
                selectedLostReasonId === reason.id
                  ? 'bg-woot-50 dark:bg-woot-900/30 text-woot-600 dark:text-woot-400 font-medium'
                  : 'text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700'
              "
              @click="selectedLostReasonId = reason.id"
            >
              <span class="i-lucide-x-circle size-4 text-red-400" />
              {{ reason.name }}
            </button>
            <p
              v-if="lostReasons.length === 0"
              class="text-xs text-slate-400 text-center py-3"
            >
              Nenhum motivo cadastrado. Configure em Configurações do Pipeline.
            </p>
          </div>
          <div class="flex gap-2 pt-1">
            <button
              class="flex-1 px-3 py-2 text-xs rounded-lg border border-slate-300 text-slate-600 hover:bg-slate-100 font-medium"
              @click="showLostPicker = false"
            >
              Cancelar
            </button>
            <button
              :disabled="statusLoading"
              class="flex-1 px-3 py-2 text-xs rounded-lg bg-red-500 text-white hover:bg-red-600 font-medium disabled:opacity-50 flex items-center justify-center gap-1.5"
              @click="confirmMarkLost"
            >
              <span
                v-if="statusLoading"
                class="i-lucide-loader-2 size-3 animate-spin"
              />
              Confirmar Perda
            </button>
          </div>
        </div>
      </div>
      <!-- ── Won confirmation overlay ─────────────────────────────────────── -->
      <div
        v-if="showWonConfirm"
        class="absolute inset-0 z-10 flex items-center justify-center bg-black/40 rounded-2xl"
        @click.self="showWonConfirm = false"
      >
        <div
          class="bg-white dark:bg-slate-800 rounded-xl shadow-xl p-5 w-80 space-y-4"
        >
          <div class="flex items-center gap-2.5">
            <span class="i-lucide-trophy size-5 text-green-500 shrink-0" />
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              Marcar como Ganho
            </h3>
          </div>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            Confirmar que
            <span class="font-semibold text-slate-700 dark:text-slate-200">{{
              item.title
            }}</span>
            foi <span class="text-green-600 font-semibold">GANHO</span>? Esta
            ação será registrada nas atividades.
          </p>
          <div class="flex gap-2">
            <button
              class="flex-1 px-3 py-2 text-xs rounded-lg border border-slate-300 text-slate-600 hover:bg-slate-100 font-medium"
              @click="showWonConfirm = false"
            >
              Cancelar
            </button>
            <button
              :disabled="statusLoading"
              class="flex-1 px-3 py-2 text-xs rounded-lg bg-green-500 text-white hover:bg-green-600 font-medium disabled:opacity-50 flex items-center justify-center gap-1.5"
              @click="confirmMarkWon"
            >
              <span
                v-if="statusLoading"
                class="i-lucide-loader-2 size-3 animate-spin"
              />
              Confirmar Ganho
            </button>
          </div>
        </div>
      </div>

      <!-- ── Reopen confirmation overlay ───────────────────────────────────── -->
      <div
        v-if="showReopenConfirm"
        class="absolute inset-0 z-10 flex items-center justify-center bg-black/40 rounded-2xl"
        @click.self="showReopenConfirm = false"
      >
        <div
          class="bg-white dark:bg-slate-800 rounded-xl shadow-xl p-5 w-80 space-y-4"
        >
          <div class="flex items-center gap-2.5">
            <span class="i-lucide-rotate-ccw size-5 text-blue-500 shrink-0" />
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              Reabrir Lead
            </h3>
          </div>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            Reabrir
            <span class="font-semibold text-slate-700 dark:text-slate-200">{{
              item.title
            }}</span>
            e mover de volta para o funil ativo?
          </p>
          <div class="flex gap-2">
            <button
              class="flex-1 px-3 py-2 text-xs rounded-lg border border-slate-300 text-slate-600 hover:bg-slate-100 font-medium"
              @click="showReopenConfirm = false"
            >
              Cancelar
            </button>
            <button
              class="flex-1 px-3 py-2 text-xs rounded-lg bg-blue-500 text-white hover:bg-blue-600 font-medium flex items-center justify-center gap-1.5"
              @click="confirmReopen"
            >
              Confirmar Reabertura
            </button>
          </div>
        </div>
      </div>

      <!-- ── Edit Lead modal overlay ────────────────────────────────────────── -->
      <div
        v-if="showEditModal"
        class="absolute inset-0 z-10 flex items-center justify-center bg-black/50 rounded-2xl"
        @click.self="showEditModal = false"
      >
        <div
          class="bg-white dark:bg-slate-800 rounded-xl shadow-xl w-full max-w-lg mx-4 flex flex-col max-h-[85vh]"
        >
          <div
            class="flex items-center justify-between px-5 py-4 border-b border-slate-100 dark:border-slate-700 shrink-0"
          >
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              Editar Lead
            </h3>
            <button
              class="text-slate-400 hover:text-slate-600"
              @click="showEditModal = false"
            >
              <span class="i-lucide-x size-4" />
            </button>
          </div>

          <div class="overflow-y-auto flex-1 px-5 py-4 space-y-5">
            <!-- Dados básicos -->
            <div>
              <p
                class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2"
              >
                Dados básicos
              </p>
              <div class="grid grid-cols-2 gap-3">
                <div class="col-span-2">
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Nome *</label
                  >
                  <input
                    v-model="editLead.title"
                    type="text"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  />
                </div>
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Telefone</label
                  >
                  <input
                    v-model="editLead.phone"
                    type="text"
                    placeholder="+55 (11) 99999-9999"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  />
                </div>
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >CPF</label
                  >
                  <input
                    v-model="editLead.cpf"
                    type="text"
                    placeholder="000.000.000-00"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  />
                </div>
              </div>
            </div>

            <!-- Dados pessoais -->
            <div>
              <p
                class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2"
              >
                Dados pessoais
              </p>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Sexo</label
                  >
                  <select
                    v-model="editLead.gender"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  >
                    <option value="">Selecionar</option>
                    <option value="male">Masculino</option>
                    <option value="female">Feminino</option>
                    <option value="other">Outro</option>
                  </select>
                </div>
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Data de Nascimento</label
                  >
                  <input
                    v-model="editLead.birthdate"
                    type="date"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  />
                </div>
              </div>
            </div>

            <!-- Endereço -->
            <div>
              <p
                class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2"
              >
                Endereço
              </p>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >CEP</label
                  >
                  <div class="relative">
                    <input
                      v-model="editLead.zipCode"
                      type="text"
                      placeholder="00000-000"
                      class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                      @blur="lookupEditCep"
                    />
                    <span
                      v-if="editCepLoading"
                      class="absolute right-2.5 top-1/2 -translate-y-1/2 i-lucide-loader-circle size-3.5 animate-spin text-woot-500"
                    />
                  </div>
                </div>
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Logradouro</label
                  >
                  <input
                    v-model="editLead.street"
                    type="text"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  />
                </div>
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Número</label
                  >
                  <input
                    v-model="editLead.streetNumber"
                    type="text"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  />
                </div>
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Complemento</label
                  >
                  <input
                    v-model="editLead.addressComplement"
                    type="text"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  />
                </div>
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Bairro</label
                  >
                  <input
                    v-model="editLead.neighborhood"
                    type="text"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  />
                </div>
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Cidade</label
                  >
                  <input
                    v-model="editLead.city"
                    type="text"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  />
                </div>
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Estado</label
                  >
                  <input
                    v-model="editLead.state"
                    type="text"
                    maxlength="2"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  />
                </div>
              </div>
            </div>

            <!-- CRM -->
            <div>
              <p
                class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2"
              >
                CRM
              </p>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Responsável</label
                  >
                  <select
                    v-model="editLead.assigneeId"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  >
                    <option value="">Nenhum</option>
                    <option
                      v-for="agent in agents"
                      :key="agent.id"
                      :value="agent.id"
                    >
                      {{ agent.name }}
                    </option>
                  </select>
                </div>
                <div class="col-span-2">
                  <label
                    class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                    >Nova observação</label
                  >
                  <textarea
                    v-model="editLead.notes"
                    rows="3"
                    placeholder="Adicionar anotação..."
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500 resize-none"
                  />
                </div>
              </div>
            </div>
          </div>

          <div
            class="px-5 py-3 bg-slate-50 dark:bg-slate-900 flex justify-end gap-2 rounded-b-xl border-t border-slate-100 dark:border-slate-700 shrink-0"
          >
            <button
              class="text-xs px-3 py-1.5 rounded-lg border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 font-medium transition-colors"
              @click="showEditModal = false"
            >
              Cancelar
            </button>
            <button
              :disabled="editSaving"
              class="text-xs px-3 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium transition-colors disabled:opacity-50"
              @click="saveEditLead"
            >
              {{ editSaving ? 'Salvando...' : 'Salvar alterações' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
