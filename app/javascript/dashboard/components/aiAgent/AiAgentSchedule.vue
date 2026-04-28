<script setup>
import { ref, onMounted } from 'vue';
import aiAgentsAPI from '../../api/aiAgents';

const props = defineProps({
  agentId: { type: Number, required: true },
});

const schedule = ref(null);
const loading = ref(false);
const saving = ref(false);
const saved = ref(false);
const slots = ref([]);
const loadingSlots = ref(false);

const WEEKDAYS = [
  { key: 'monday', label: 'Segunda' },
  { key: 'tuesday', label: 'Terça' },
  { key: 'wednesday', label: 'Quarta' },
  { key: 'thursday', label: 'Quinta' },
  { key: 'friday', label: 'Sexta' },
  { key: 'saturday', label: 'Sábado' },
  { key: 'sunday', label: 'Domingo' },
];

const form = ref({
  google_calendar_id: '',
  slot_duration_minutes: 60,
  max_days_in_advance: 30,
  max_concurrent_bookings: 1,
  min_notice_minutes: 60,
  default_subject: '',
  weekly_windows: {},
});

function defaultWindows() {
  const windows = {};
  WEEKDAYS.forEach(d => {
    windows[d.key] = [];
  });
  return windows;
}

function ensureWindows() {
  WEEKDAYS.forEach(d => {
    if (!form.value.weekly_windows[d.key]) {
      form.value.weekly_windows[d.key] = [];
    }
  });
}

async function load() {
  loading.value = true;
  try {
    const { data } = await aiAgentsAPI.getSchedule(props.agentId);
    schedule.value = data.payload;
    form.value = {
      google_calendar_id: data.payload.google_calendar_id || '',
      slot_duration_minutes: data.payload.slot_duration_minutes,
      max_days_in_advance: data.payload.max_days_in_advance,
      max_concurrent_bookings: data.payload.max_concurrent_bookings,
      min_notice_minutes: data.payload.min_notice_minutes,
      default_subject: data.payload.default_subject || '',
      weekly_windows: data.payload.weekly_windows || defaultWindows(),
    };
    ensureWindows();
  } finally {
    loading.value = false;
  }
}

async function save() {
  saving.value = true;
  try {
    const { data } = await aiAgentsAPI.updateSchedule(
      props.agentId,
      form.value
    );
    schedule.value = data.payload;
    saved.value = true;
    setTimeout(() => {
      saved.value = false;
    }, 3000);
  } finally {
    saving.value = false;
  }
}

async function connectGoogle() {
  try {
    const { data } = await aiAgentsAPI.getGoogleAuthUrl(props.agentId);
    const popup = window.open(data.url, 'google_auth', 'width=600,height=700');
    const timer = setInterval(() => {
      if (popup.closed) {
        clearInterval(timer);
        load();
      }
    }, 1000);
  } catch (e) {
    alert('Erro ao obter URL de autenticação.');
  }
}

async function disconnectGoogle() {
  if (!window.confirm('Desconectar o Google Calendar?')) return;
  await aiAgentsAPI.disconnectGoogle(props.agentId);
  await load();
}

async function loadSlots() {
  loadingSlots.value = true;
  try {
    const { data } = await aiAgentsAPI.getAvailableSlots(props.agentId);
    slots.value = data.payload;
  } finally {
    loadingSlots.value = false;
  }
}

function addWindow(dayKey) {
  form.value.weekly_windows[dayKey].push({ start: '09:00', end: '18:00' });
}

function removeWindow(dayKey, index) {
  form.value.weekly_windows[dayKey].splice(index, 1);
}

// Handle ?calendar=connected redirect from OAuth callback
onMounted(() => {
  const params = new URLSearchParams(window.location.search);
  if (params.get('calendar') === 'connected') {
    const url = new URL(window.location.href);
    url.searchParams.delete('calendar');
    window.history.replaceState({}, '', url.toString());
  }
  load();
});

const inputClass =
  'w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30';
const labelClass =
  'text-xs font-semibold text-slate-500 dark:text-slate-400 mb-1.5 block';
const sectionClass =
  'bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 space-y-4';
</script>

<template>
  <div class="space-y-5">
    <div v-if="loading" class="flex justify-center py-12">
      <span class="i-lucide-loader-2 size-6 animate-spin text-slate-400" />
    </div>

    <template v-else>
      <!-- Save bar -->
      <div class="flex items-center justify-end gap-2">
        <span
          v-if="saved"
          class="text-xs text-emerald-500 flex items-center gap-1"
        >
          <span class="i-lucide-check size-3.5" /> Configurações salvas
        </span>
        <button
          class="flex items-center gap-1.5 px-4 py-2 text-xs font-semibold bg-violet-600 hover:bg-violet-700 text-white rounded-lg transition-colors disabled:opacity-50"
          :disabled="saving"
          @click="save"
        >
          <span v-if="saving" class="i-lucide-loader-2 size-3.5 animate-spin" />
          <span v-else class="i-lucide-save size-3.5" />
          {{ saving ? 'Salvando...' : 'Salvar' }}
        </button>
      </div>

      <!-- Google Calendar connection -->
      <div :class="sectionClass">
        <h3
          class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
        >
          <span class="i-lucide-calendar size-4 text-violet-500" /> Google
          Calendar
        </h3>

        <div
          v-if="schedule?.google_connected"
          class="flex items-center justify-between gap-3"
        >
          <div class="flex items-center gap-2">
            <span class="w-2 h-2 rounded-full bg-emerald-400 inline-block" />
            <span
              class="text-sm text-emerald-600 dark:text-emerald-400 font-medium"
              >Conectado</span
            >
          </div>
          <button
            class="text-xs px-3 py-1.5 rounded border border-red-300 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20"
            @click="disconnectGoogle"
          >
            Desconectar
          </button>
        </div>

        <div v-else class="flex items-center gap-3">
          <span class="text-sm text-slate-400">Não conectado</span>
          <button
            class="flex items-center gap-2 px-4 py-2 text-xs font-semibold bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-200 transition-colors"
            @click="connectGoogle"
          >
            <span class="i-lucide-log-in size-3.5" /> Conectar Google Calendar
          </button>
        </div>

        <div v-if="schedule?.google_connected">
          <label :class="labelClass">ID do Calendário</label>
          <input
            v-model="form.google_calendar_id"
            type="text"
            placeholder="primary ou email@gmail.com"
            :class="inputClass"
          />
          <p class="text-xs text-slate-400 mt-1">
            Use "primary" para o calendário principal ou o e-mail do calendário
            compartilhado.
          </p>
        </div>
      </div>

      <!-- Slot settings -->
      <div :class="sectionClass">
        <h3
          class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
        >
          <span class="i-lucide-clock size-4 text-violet-500" /> Configuração de
          Slots
        </h3>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label :class="labelClass">Duração do slot (minutos)</label>
            <input
              v-model.number="form.slot_duration_minutes"
              type="number"
              min="15"
              step="15"
              :class="inputClass"
            />
          </div>
          <div>
            <label :class="labelClass">Antecedência mínima (minutos)</label>
            <input
              v-model.number="form.min_notice_minutes"
              type="number"
              min="0"
              :class="inputClass"
            />
          </div>
          <div>
            <label :class="labelClass">Máx. dias em aberto</label>
            <input
              v-model.number="form.max_days_in_advance"
              type="number"
              min="1"
              max="90"
              :class="inputClass"
            />
          </div>
          <div>
            <label :class="labelClass">Máx. reuniões simultâneas</label>
            <input
              v-model.number="form.max_concurrent_bookings"
              type="number"
              min="1"
              :class="inputClass"
            />
          </div>
        </div>
        <div>
          <label :class="labelClass">Título padrão da reunião</label>
          <input
            v-model="form.default_subject"
            type="text"
            placeholder="Ex: Reunião de apresentação"
            :class="inputClass"
          />
        </div>
      </div>

      <!-- Weekly windows -->
      <div :class="sectionClass">
        <h3
          class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
        >
          <span class="i-lucide-calendar-days size-4 text-violet-500" />
          Disponibilidade Semanal
        </h3>

        <div
          v-for="day in WEEKDAYS"
          :key="day.key"
          class="flex items-start gap-3"
        >
          <div
            class="w-20 pt-1.5 text-xs font-medium text-slate-600 dark:text-slate-400 shrink-0"
          >
            {{ day.label }}
          </div>
          <div class="flex-1 flex flex-col gap-1.5">
            <div
              v-for="(window, idx) in form.weekly_windows[day.key]"
              :key="idx"
              class="flex items-center gap-2"
            >
              <input
                v-model="window.start"
                type="time"
                class="text-xs px-2 py-1.5 rounded border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200"
              />
              <span class="text-xs text-slate-400">até</span>
              <input
                v-model="window.end"
                type="time"
                class="text-xs px-2 py-1.5 rounded border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200"
              />
              <button
                class="text-slate-300 hover:text-red-400 transition-colors"
                @click="removeWindow(day.key, idx)"
              >
                ✕
              </button>
            </div>
            <button
              class="text-xs text-violet-500 hover:underline text-left w-fit"
              @click="addWindow(day.key)"
            >
              + Adicionar janela
            </button>
          </div>
        </div>
      </div>

      <!-- Preview available slots -->
      <div v-if="schedule?.google_connected" :class="sectionClass">
        <div class="flex items-center justify-between">
          <h3
            class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
          >
            <span class="i-lucide-list-checks size-4 text-violet-500" />
            Próximos horários disponíveis
          </h3>
          <button
            class="text-xs text-violet-500 hover:underline flex items-center gap-1"
            :disabled="loadingSlots"
            @click="loadSlots"
          >
            <span
              v-if="loadingSlots"
              class="i-lucide-loader-2 size-3 animate-spin"
            />
            <span v-else class="i-lucide-refresh-cw size-3" />
            Atualizar
          </button>
        </div>

        <div
          v-if="slots.length === 0 && !loadingSlots"
          class="text-xs text-slate-400"
        >
          Clique em "Atualizar" para visualizar os próximos horários
          disponíveis.
        </div>

        <div v-if="loadingSlots" class="text-xs text-slate-400">
          Buscando horários...
        </div>

        <div v-else class="flex flex-wrap gap-2">
          <span
            v-for="slot in slots"
            :key="slot.start"
            class="text-xs px-3 py-1.5 rounded-full bg-violet-50 dark:bg-violet-900/20 text-violet-700 dark:text-violet-300 border border-violet-200 dark:border-violet-700"
          >
            {{ slot.start_label }}
          </span>
        </div>
      </div>
    </template>
  </div>
</template>
