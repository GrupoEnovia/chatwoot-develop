<script setup>
import { ref, computed, watch, onMounted, reactive } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import KanbanColumn from './KanbanColumn.vue';
import KanbanCardModal from './KanbanCardModal.vue';
import KanbanPipelineModal from './KanbanPipelineModal.vue';
import ContactsAPI from 'dashboard/api/contacts.js';

const router = useRouter();

const store = useStore();

// UI state
const selectedItem = ref(null);
const showAddCardModal = ref(false);
const addCardStage = ref(null);
const newCard = reactive({
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
  contactId: null,
});
const contactSearchQuery = ref('');
const contactSearchResults = ref([]);
const contactSearchLoading = ref(false);
const linkedContact = ref(null);
const cepLoading = ref(false);
const showPipelineModal = ref(false);
const editingPipeline = ref(null);
const showPipelineDropdown = ref(false);
const showFilters = ref(false);

// Filters state
const filterSearch = ref('');
const filterSource = ref('');
const filterTemperature = ref('');
const filterStatus = ref('');
const filterCreatedFrom = ref('');
const filterCreatedTo = ref('');
const filterCloseDateFrom = ref('');
const filterCloseDateTo = ref('');
const filterValueMin = ref('');
const filterValueMax = ref('');
const filterLostReason = ref('');

// Pending drag confirmations
const pendingLostDrag = ref(null);
const pendingLostReasonId = ref(null);
const pendingWonDrag = ref(null);

// Store
const pipelines = computed(() => store.getters['kanban/getPipelines']);
const activePipelineId = computed(
  () => store.getters['kanban/getActivePipelineId']
);
const activePipeline = computed(
  () => store.getters['kanban/getActivePipeline']
);
const stages = computed(() => store.getters['kanban/getStages']);
const allItems = computed(() => store.getters['kanban/getItems']);
const uiFlags = computed(() => store.getters['kanban/getUIFlags']);
const agents = computed(() => store.getters['agents/getAgents'] || []);
const lostReasons = computed(
  () => store.getters['kanban/getLostReasons'] || []
);
const isLoading = computed(
  () =>
    uiFlags.value.isFetchingPipelines ||
    uiFlags.value.isFetchingStages ||
    uiFlags.value.isFetchingItems
);

// Pipeline summary stats
const pipelineSummary = computed(() => {
  const open = allItems.value.filter(i => !i.won_at && !i.lost_at);
  const totalValue = open.reduce((s, i) => s + (parseFloat(i.value) || 0), 0);
  const avgTicket = open.length > 0 ? totalValue / open.length : 0;
  return {
    count: open.length,
    totalValue,
    stages: stages.value.length,
    avgTicket,
  };
});

function formatBRL(val) {
  if (!val) return 'R$ 0';
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  }).format(val);
}

const activeFiltersCount = computed(() => {
  let count = 0;
  if (filterSearch.value) count++;
  if (filterSource.value) count++;
  if (filterTemperature.value) count++;
  if (filterStatus.value) count++;
  if (filterCreatedFrom.value) count++;
  if (filterCreatedTo.value) count++;
  if (filterCloseDateFrom.value) count++;
  if (filterCloseDateTo.value) count++;
  if (filterValueMin.value) count++;
  if (filterValueMax.value) count++;
  if (filterLostReason.value) count++;
  return count;
});

async function loadBoard(pipelineId) {
  const filters = {};
  if (filterSearch.value) filters.search = filterSearch.value;
  if (filterSource.value) filters.source = filterSource.value;
  if (filterTemperature.value) filters.temperature = filterTemperature.value;
  if (filterStatus.value) filters.status = filterStatus.value;
  if (filterCreatedFrom.value) filters.created_from = filterCreatedFrom.value;
  if (filterCreatedTo.value) filters.created_to = filterCreatedTo.value;
  if (filterCloseDateFrom.value)
    filters.close_date_from = filterCloseDateFrom.value;
  if (filterCloseDateTo.value) filters.close_date_to = filterCloseDateTo.value;
  if (filterValueMin.value) filters.value_min = filterValueMin.value;
  if (filterValueMax.value) filters.value_max = filterValueMax.value;
  if (filterLostReason.value) filters.lost_reason_id = filterLostReason.value;
  await Promise.all([
    store.dispatch('kanban/fetchStages', pipelineId),
    store.dispatch('kanban/fetchItems', { pipelineId, filters }),
  ]);
}

watch(activePipelineId, id => {
  if (id) loadBoard(id);
});
watch(
  [
    filterSearch,
    filterSource,
    filterTemperature,
    filterStatus,
    filterCreatedFrom,
    filterCreatedTo,
    filterCloseDateFrom,
    filterCloseDateTo,
    filterValueMin,
    filterValueMax,
    filterLostReason,
  ],
  () => {
    if (activePipelineId.value) loadBoard(activePipelineId.value);
  }
);

onMounted(async () => {
  await store.dispatch('kanban/fetchPipelines');
  if (activePipelineId.value) loadBoard(activePipelineId.value);
});

function openAddCard(stage) {
  addCardStage.value = stage;
  Object.assign(newCard, {
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
    contactId: null,
  });
  contactSearchQuery.value = '';
  contactSearchResults.value = [];
  linkedContact.value = null;
  showAddCardModal.value = true;
}

async function searchContacts() {
  const q = contactSearchQuery.value.trim();
  if (!q) {
    contactSearchResults.value = [];
    return;
  }
  contactSearchLoading.value = true;
  try {
    const { data } = await ContactsAPI.search(q, 1);
    contactSearchResults.value = (data.payload || []).slice(0, 5);
  } catch (e) {
    contactSearchResults.value = [];
  } finally {
    contactSearchLoading.value = false;
  }
}

function selectContact(contact) {
  linkedContact.value = contact;
  newCard.contactId = contact.id;
  if (contact.name) newCard.title = contact.name;
  if (contact.phone_number) newCard.phone = contact.phone_number;
  const a = contact.additional_attributes || {};
  if (a.cpf) newCard.cpf = a.cpf;
  if (a.gender) newCard.gender = a.gender;
  if (a.birthdate) newCard.birthdate = a.birthdate;
  if (a.zip_code) newCard.zipCode = a.zip_code;
  if (a.street) newCard.street = a.street;
  if (a.street_number) newCard.streetNumber = a.street_number;
  if (a.address_complement) newCard.addressComplement = a.address_complement;
  if (a.neighborhood) newCard.neighborhood = a.neighborhood;
  if (a.city) newCard.city = a.city;
  if (a.state) newCard.state = a.state;
  contactSearchResults.value = [];
  contactSearchQuery.value = '';
}

function unlinkContact() {
  linkedContact.value = null;
  newCard.contactId = null;
}

async function lookupCep() {
  const clean = newCard.zipCode.replace(/\D/g, '');
  if (clean.length !== 8) return;
  cepLoading.value = true;
  try {
    const res = await fetch(`https://viacep.com.br/ws/${clean}/json/`);
    const json = await res.json();
    if (!json.erro) {
      newCard.street = json.logradouro || newCard.street;
      newCard.neighborhood = json.bairro || newCard.neighborhood;
      newCard.city = json.localidade || newCard.city;
      newCard.state = json.uf || newCard.state;
    }
  } catch (e) {
    // ignore lookup errors
  } finally {
    cepLoading.value = false;
  }
}

async function confirmAddCard() {
  if (!newCard.title.trim()) return;

  let contactId = newCard.contactId;

  if (!contactId && newCard.phone.trim()) {
    try {
      const { data } = await ContactsAPI.search(newCard.phone.trim(), 1);
      const found = (data.payload || []).find(
        c => c.phone_number === newCard.phone.trim()
      );
      if (found) {
        contactId = found.id;
      } else {
        const formData = new FormData();
        formData.append('name', newCard.title.trim());
        formData.append('phone_number', newCard.phone.trim());
        if (newCard.cpf)
          formData.append('additional_attributes[cpf]', newCard.cpf);
        if (newCard.birthdate)
          formData.append(
            'additional_attributes[birthdate]',
            newCard.birthdate
          );
        if (newCard.gender)
          formData.append('additional_attributes[gender]', newCard.gender);
        if (newCard.zipCode)
          formData.append('additional_attributes[zip_code]', newCard.zipCode);
        if (newCard.street)
          formData.append('additional_attributes[street]', newCard.street);
        if (newCard.streetNumber)
          formData.append(
            'additional_attributes[street_number]',
            newCard.streetNumber
          );
        if (newCard.addressComplement)
          formData.append(
            'additional_attributes[address_complement]',
            newCard.addressComplement
          );
        if (newCard.neighborhood)
          formData.append(
            'additional_attributes[neighborhood]',
            newCard.neighborhood
          );
        if (newCard.city)
          formData.append('additional_attributes[city]', newCard.city);
        if (newCard.state)
          formData.append('additional_attributes[state]', newCard.state);
        const res = await ContactsAPI.create(formData);
        contactId = res.data?.payload?.contact?.id;
      }
    } catch (e) {
      // proceed without contact
    }
  }

  const item = await store.dispatch('kanban/createItem', {
    pipelineId: activePipelineId.value,
    stage_id: addCardStage.value.id,
    title: newCard.title.trim(),
    contact_phone: newCard.phone.trim() || undefined,
    contact_id: contactId || undefined,
    assignee_id: newCard.assigneeId || undefined,
  });

  if (item?.id && newCard.notes.trim()) {
    await store.dispatch('kanban/createNote', {
      pipelineId: activePipelineId.value,
      itemId: item.id,
      content: newCard.notes.trim(),
    });
  }

  showAddCardModal.value = false;
}

function selectPipeline(id) {
  store.dispatch('kanban/setActivePipeline', id);
  showPipelineDropdown.value = false;
}

function openCreatePipeline() {
  editingPipeline.value = null;
  showPipelineModal.value = true;
  showPipelineDropdown.value = false;
}

function openEditPipeline() {
  editingPipeline.value = activePipeline.value;
  showPipelineModal.value = true;
}

function clearFilters() {
  filterSearch.value = '';
  filterSource.value = '';
  filterTemperature.value = '';
  filterStatus.value = '';
  filterCreatedFrom.value = '';
  filterCreatedTo.value = '';
  filterCloseDateFrom.value = '';
  filterCloseDateTo.value = '';
  filterValueMin.value = '';
  filterValueMax.value = '';
  filterLostReason.value = '';
}

async function onShowFilters() {
  showFilters.value = !showFilters.value;
  if (showFilters.value && !lostReasons.value.length) {
    await store.dispatch('kanban/fetchLostReasons');
  }
}

async function handlePendingLost(payload) {
  pendingLostReasonId.value = null;
  pendingLostDrag.value = payload;
  await store.dispatch('kanban/fetchLostReasons');
}

function cancelPendingLost() {
  pendingLostDrag.value = null;
  pendingLostReasonId.value = null;
}

async function confirmPendingLost() {
  if (!pendingLostDrag.value) return;
  const { item } = pendingLostDrag.value;
  try {
    await store.dispatch('kanban/markItemLost', {
      pipelineId: activePipelineId.value,
      id: item.id,
      lostReasonId: pendingLostReasonId.value || undefined,
    });
  } catch (e) {
    /* ignore */
  } finally {
    pendingLostDrag.value = null;
    pendingLostReasonId.value = null;
  }
}

function handlePendingWon(payload) {
  pendingWonDrag.value = payload;
}

function cancelPendingWon() {
  pendingWonDrag.value = null;
}

async function confirmPendingWon() {
  if (!pendingWonDrag.value) return;
  const { item } = pendingWonDrag.value;
  try {
    await store.dispatch('kanban/markItemWon', {
      pipelineId: activePipelineId.value,
      id: item.id,
    });
  } catch (e) {
    /* ignore */
  } finally {
    pendingWonDrag.value = null;
  }
}
</script>

<template>
  <div
    class="flex flex-col flex-1 h-full min-h-0 bg-white dark:bg-slate-900 overflow-hidden"
    @click="showPipelineDropdown = false"
  >
    <!-- Top bar -->
    <div
      class="flex items-center gap-3 px-5 py-3 border-b border-slate-200 dark:border-slate-700 shrink-0 flex-wrap"
    >
      <div class="flex items-center gap-2">
        <span class="i-lucide-kanban size-5 text-woot-500" />
        <h1 class="text-base font-semibold text-slate-800 dark:text-slate-100">
          Kanban
        </h1>
      </div>

      <!-- Pipeline dropdown -->
      <div class="relative" @click.stop>
        <button
          class="flex items-center gap-2 text-sm px-3 py-1.5 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:border-woot-400 transition-colors font-medium"
          @click="showPipelineDropdown = !showPipelineDropdown"
        >
          <span class="i-lucide-layers size-3.5 text-woot-500" />
          {{ activePipeline?.name || 'Selecionar Pipeline' }}
          <span class="i-lucide-chevron-down size-3.5 text-slate-400" />
        </button>

        <div
          v-if="showPipelineDropdown"
          class="absolute top-full left-0 mt-1 z-40 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl shadow-xl w-56 overflow-hidden"
        >
          <div v-if="pipelines.length" class="py-1">
            <button
              v-for="p in pipelines"
              :key="p.id"
              class="w-full flex items-center justify-between px-3 py-2 text-sm hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors"
              :class="
                p.id === activePipelineId
                  ? 'text-woot-600 font-medium'
                  : 'text-slate-700 dark:text-slate-200'
              "
              @click="selectPipeline(p.id)"
            >
              <span>{{ p.name }}</span>
              <span
                v-if="p.id === activePipelineId"
                class="i-lucide-check size-3.5 text-woot-500"
              />
            </button>
          </div>
          <div v-else class="px-3 py-2 text-xs text-slate-400">
            Nenhuma pipeline
          </div>
          <div class="border-t border-slate-100 dark:border-slate-700 py-1">
            <button
              class="w-full flex items-center gap-2 px-3 py-2 text-sm text-woot-600 hover:bg-woot-50 dark:hover:bg-woot-900/30 transition-colors font-medium"
              @click="openCreatePipeline"
            >
              <span class="i-lucide-plus size-3.5" />
              Nova Pipeline
            </button>
          </div>
        </div>
      </div>

      <!-- Filter toggle -->
      <button
        class="relative flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg border transition-colors font-medium"
        :class="
          activeFiltersCount > 0
            ? 'border-woot-400 bg-woot-50 dark:bg-woot-900/30 text-woot-600'
            : 'border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-50'
        "
        @click="onShowFilters"
      >
        <span class="i-lucide-filter size-3.5" />
        Filtros
        <span
          v-if="activeFiltersCount > 0"
          class="size-4 rounded-full bg-woot-500 text-white text-[10px] font-bold flex items-center justify-center"
        >
          {{ activeFiltersCount }}
        </span>
      </button>

      <!-- Actions right -->
      <div class="ml-auto flex items-center gap-2">
        <span
          v-if="isLoading"
          class="i-lucide-loader-circle size-4 animate-spin text-woot-500"
        />
        <button
          class="flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-amber-50 dark:bg-amber-900/20 text-amber-600 dark:text-amber-400 hover:bg-amber-100 dark:hover:bg-amber-900/40 font-medium transition-colors border border-amber-200 dark:border-amber-700"
          @click="router.push({ name: 'kanban_gamification' })"
        >
          <span class="i-lucide-trophy size-3.5" />
          Ranking
        </button>
        <button
          class="flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-violet-50 dark:bg-violet-900/20 text-violet-600 dark:text-violet-400 hover:bg-violet-100 dark:hover:bg-violet-900/40 font-medium transition-colors border border-violet-200 dark:border-violet-700"
          @click="router.push({ name: 'kanban_automation' })"
        >
          <span class="i-lucide-zap size-3.5" />
          Automação de CRM
        </button>
        <button
          v-if="activePipeline"
          class="flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700 font-medium transition-colors"
          @click="openEditPipeline"
        >
          <span class="i-lucide-settings size-3.5" />
          Configurações
        </button>
      </div>
    </div>

    <!-- Filter panel -->
    <div
      v-if="showFilters"
      class="border-b border-slate-100 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/50"
    >
      <!-- Search -->
      <div class="px-5 pt-3 pb-2">
        <div class="relative">
          <span
            class="absolute left-3 top-1/2 -translate-y-1/2 i-lucide-search size-4 text-slate-400"
          />
          <input
            v-model="filterSearch"
            type="text"
            placeholder="Buscar por nome ou telefone..."
            class="w-full text-sm pl-9 pr-3 py-2 border border-slate-300 dark:border-slate-600 rounded-xl bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-woot-500"
          />
        </div>
      </div>

      <!-- Filter rows -->
      <div class="px-5 pb-3 grid grid-cols-2 md:grid-cols-4 gap-2">
        <select
          v-model="filterSource"
          class="text-xs border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-woot-500"
        >
          <option value="">Origem: todas</option>
          <option value="whatsapp">WhatsApp</option>
          <option value="instagram">Instagram</option>
          <option value="facebook">Facebook</option>
          <option value="website">Website</option>
          <option value="phone">Telefone</option>
          <option value="email">E-mail</option>
          <option value="referral">Indicação</option>
          <option value="manual">Manual</option>
        </select>

        <select
          v-model="filterTemperature"
          class="text-xs border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-woot-500"
        >
          <option value="">Temperatura: todas</option>
          <option value="cold">❄️ Frio</option>
          <option value="warm">🌡 Morno</option>
          <option value="hot">🔥 Quente</option>
          <option value="very_hot">💥 Muito Quente</option>
        </select>

        <select
          v-model="filterStatus"
          class="text-xs border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-woot-500"
        >
          <option value="">Status: todos</option>
          <option value="open">Aberto</option>
          <option value="won">Ganho</option>
          <option value="lost">Perdido</option>
        </select>

        <select
          v-model="filterLostReason"
          class="text-xs border border-slate-300 dark:border-slate-600 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-woot-500"
        >
          <option value="">Motivo perda: todos</option>
          <option v-for="r in lostReasons" :key="r.id" :value="r.id">
            {{ r.name }}
          </option>
        </select>

        <div class="flex gap-1.5">
          <input
            v-model="filterValueMin"
            type="number"
            min="0"
            placeholder="Valor mín"
            class="flex-1 text-xs border border-slate-300 dark:border-slate-600 rounded-lg px-2 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-woot-500"
          />
          <input
            v-model="filterValueMax"
            type="number"
            min="0"
            placeholder="Valor máx"
            class="flex-1 text-xs border border-slate-300 dark:border-slate-600 rounded-lg px-2 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-woot-500"
          />
        </div>

        <div>
          <p class="text-[10px] text-slate-400 mb-1">Criado de</p>
          <input
            v-model="filterCreatedFrom"
            type="date"
            class="w-full text-xs border border-slate-300 dark:border-slate-600 rounded-lg px-2 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
          />
        </div>
        <div>
          <p class="text-[10px] text-slate-400 mb-1">Criado até</p>
          <input
            v-model="filterCreatedTo"
            type="date"
            class="w-full text-xs border border-slate-300 dark:border-slate-600 rounded-lg px-2 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
          />
        </div>
        <div>
          <p class="text-[10px] text-slate-400 mb-1">Fechamento de</p>
          <input
            v-model="filterCloseDateFrom"
            type="date"
            class="w-full text-xs border border-slate-300 dark:border-slate-600 rounded-lg px-2 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
          />
        </div>
        <div>
          <p class="text-[10px] text-slate-400 mb-1">Fechamento até</p>
          <input
            v-model="filterCloseDateTo"
            type="date"
            class="w-full text-xs border border-slate-300 dark:border-slate-600 rounded-lg px-2 py-1.5 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none"
          />
        </div>
      </div>

      <div
        v-if="activeFiltersCount > 0"
        class="px-5 pb-2.5 flex items-center gap-2"
      >
        <span class="text-xs text-slate-500"
          >{{ activeFiltersCount }} filtro(s) ativo(s)</span
        >
        <button
          class="flex items-center gap-1 text-xs text-red-500 hover:text-red-700 font-medium"
          @click="clearFilters"
        >
          <span class="i-lucide-x size-3" />
          Limpar tudo
        </button>
      </div>
    </div>

    <!-- Pipeline Summary Bar -->
    <div
      v-if="stages.length && allItems.length > 0"
      class="flex items-stretch divide-x divide-slate-200 dark:divide-slate-700 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50 shrink-0"
    >
      <div class="flex flex-col px-5 py-2.5">
        <span class="text-[10px] text-slate-400 uppercase tracking-wide mb-0.5"
          >Negócios no Funil</span
        >
        <span class="text-lg font-bold text-slate-800 dark:text-slate-100">{{
          pipelineSummary.count
        }}</span>
      </div>
      <div class="flex flex-col px-5 py-2.5">
        <span class="text-[10px] text-slate-400 uppercase tracking-wide mb-0.5"
          >Valor Total</span
        >
        <span class="text-lg font-bold text-woot-600 dark:text-woot-400">{{
          formatBRL(pipelineSummary.totalValue)
        }}</span>
      </div>
      <div class="flex flex-col px-5 py-2.5">
        <span class="text-[10px] text-slate-400 uppercase tracking-wide mb-0.5"
          >Etapas</span
        >
        <span class="text-lg font-bold text-slate-800 dark:text-slate-100">{{
          pipelineSummary.stages
        }}</span>
      </div>
      <div class="flex flex-col px-5 py-2.5">
        <span class="text-[10px] text-slate-400 uppercase tracking-wide mb-0.5"
          >Ticket Médio</span
        >
        <span class="text-lg font-bold text-green-600 dark:text-green-400">{{
          formatBRL(pipelineSummary.avgTicket)
        }}</span>
      </div>
    </div>

    <!-- Board -->
    <div class="flex-1 min-h-0 overflow-x-auto overflow-y-hidden">
      <!-- Columns -->
      <div v-if="stages.length" class="flex gap-3 p-4 h-full items-stretch">
        <KanbanColumn
          v-for="stage in stages"
          :key="stage.id"
          :stage="stage"
          :pipeline-id="activePipelineId"
          @card-click="selectedItem = $event"
          @add-card="openAddCard"
          @pending-lost="handlePendingLost"
          @pending-won="handlePendingWon"
        />
      </div>

      <!-- Empty: has pipeline but no stages -->
      <div
        v-else-if="!isLoading && activePipeline"
        class="flex flex-col items-center justify-center h-full text-center px-6"
      >
        <span
          class="i-lucide-layout-dashboard size-14 text-slate-300 dark:text-slate-600 mb-4"
        />
        <p
          class="text-sm font-semibold text-slate-700 dark:text-slate-200 mb-1"
        >
          Nenhuma etapa em "{{ activePipeline.name }}"
        </p>
        <p class="text-xs text-slate-400 dark:text-slate-500 mb-4">
          Configure as etapas do seu pipeline para começar a usar o Kanban.
        </p>
        <button
          class="flex items-center gap-2 text-sm px-4 py-2 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium transition-colors shadow-sm"
          @click="openEditPipeline"
        >
          <span class="i-lucide-settings size-4" />
          Configurar etapas
        </button>
      </div>

      <!-- Empty: no pipelines at all -->
      <div
        v-else-if="!isLoading && !pipelines.length"
        class="flex flex-col items-center justify-center h-full text-center px-6"
      >
        <span
          class="i-lucide-kanban size-16 text-slate-300 dark:text-slate-600 mb-4"
        />
        <p
          class="text-base font-semibold text-slate-700 dark:text-slate-200 mb-1"
        >
          Bem-vindo ao Kanban
        </p>
        <p class="text-sm text-slate-400 dark:text-slate-500 mb-6 max-w-sm">
          Organize seus leads e oportunidades em pipelines visuais. Crie sua
          primeira pipeline para começar.
        </p>
        <button
          class="flex items-center gap-2 text-sm px-5 py-2.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-semibold transition-colors shadow-md"
          @click="openCreatePipeline"
        >
          <span class="i-lucide-plus size-4" />
          Criar primeira Pipeline
        </button>
      </div>
    </div>

    <!-- Card detail modal -->
    <KanbanCardModal
      :item="selectedItem"
      :pipeline-id="activePipelineId"
      @close="selectedItem = null"
      @updated="selectedItem = null"
    />

    <!-- Pipeline create/edit modal -->
    <KanbanPipelineModal
      v-if="showPipelineModal"
      :pipeline="editingPipeline"
      @close="showPipelineModal = false"
      @saved="showPipelineModal = false"
    />

    <!-- Lost reason picker dialog -->
    <div
      v-if="pendingLostDrag"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
      @click.self="cancelPendingLost"
    >
      <div
        class="bg-white dark:bg-slate-800 rounded-xl shadow-xl w-full max-w-sm mx-4 overflow-hidden"
      >
        <div
          class="flex items-center gap-2.5 px-5 py-4 border-b border-slate-100 dark:border-slate-700"
        >
          <span class="i-lucide-x-circle size-5 text-red-500 shrink-0" />
          <h3 class="text-sm font-semibold text-slate-800 dark:text-slate-100">
            Marcar como Perdido
          </h3>
        </div>
        <div class="px-5 py-4 space-y-3">
          <p class="text-xs text-slate-500 dark:text-slate-400">
            <span class="font-semibold text-slate-700 dark:text-slate-200">{{
              pendingLostDrag.item?.title
            }}</span>
            será marcado como perdido. Selecione o motivo:
          </p>
          <select
            v-model="pendingLostReasonId"
            class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-red-400"
          >
            <option :value="null">— Sem motivo —</option>
            <option v-for="r in lostReasons" :key="r.id" :value="r.id">
              {{ r.name }}
            </option>
          </select>
        </div>
        <div
          class="px-5 py-3 bg-slate-50 dark:bg-slate-900 flex justify-end gap-2 rounded-b-xl border-t border-slate-100 dark:border-slate-700"
        >
          <button
            class="text-xs px-3 py-1.5 rounded-lg border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 font-medium transition-colors"
            @click="cancelPendingLost"
          >
            Cancelar
          </button>
          <button
            class="text-xs px-3 py-1.5 rounded-lg bg-red-500 text-white hover:bg-red-600 font-medium transition-colors"
            @click="confirmPendingLost"
          >
            Confirmar Perdido
          </button>
        </div>
      </div>
    </div>

    <!-- Won confirmation dialog -->
    <div
      v-if="pendingWonDrag"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
      @click.self="cancelPendingWon"
    >
      <div
        class="bg-white dark:bg-slate-800 rounded-xl shadow-xl w-full max-w-sm mx-4 overflow-hidden"
      >
        <div
          class="flex items-center gap-2.5 px-5 py-4 border-b border-slate-100 dark:border-slate-700"
        >
          <span class="i-lucide-trophy size-5 text-green-500 shrink-0" />
          <h3 class="text-sm font-semibold text-slate-800 dark:text-slate-100">
            Marcar como Ganho
          </h3>
        </div>
        <div class="px-5 py-4">
          <p class="text-xs text-slate-500 dark:text-slate-400">
            Confirmar que
            <span class="font-semibold text-slate-700 dark:text-slate-200">{{
              pendingWonDrag.item?.title
            }}</span>
            foi <span class="text-green-600 font-semibold">GANHO</span>?
          </p>
        </div>
        <div
          class="px-5 py-3 bg-slate-50 dark:bg-slate-900 flex justify-end gap-2 rounded-b-xl border-t border-slate-100 dark:border-slate-700"
        >
          <button
            class="text-xs px-3 py-1.5 rounded-lg border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 font-medium transition-colors"
            @click="cancelPendingWon"
          >
            Cancelar
          </button>
          <button
            class="text-xs px-3 py-1.5 rounded-lg bg-green-500 text-white hover:bg-green-600 font-medium transition-colors"
            @click="confirmPendingWon"
          >
            Confirmar Ganho
          </button>
        </div>
      </div>
    </div>

    <!-- Add card modal -->
    <div
      v-if="showAddCardModal"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
      @click.self="showAddCardModal = false"
    >
      <div
        class="bg-white dark:bg-slate-800 rounded-xl shadow-xl w-full max-w-2xl mx-4 flex flex-col max-h-[90vh]"
      >
        <!-- Header -->
        <div
          class="flex items-center justify-between px-5 py-4 border-b border-slate-100 dark:border-slate-700 shrink-0"
        >
          <h3 class="text-sm font-semibold text-slate-800 dark:text-slate-100">
            Novo lead em
            <span class="text-woot-500">{{ addCardStage?.name }}</span>
          </h3>
          <button
            class="text-slate-400 hover:text-slate-600"
            @click="showAddCardModal = false"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>

        <!-- Body (scrollable) -->
        <div class="overflow-y-auto flex-1 px-5 py-4 space-y-5">
          <!-- Contact search -->
          <div>
            <p
              class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-2"
            >
              Contato existente
            </p>
            <div
              v-if="linkedContact"
              class="flex items-center gap-3 p-2.5 rounded-lg bg-woot-50 dark:bg-woot-900/30 border border-woot-200 dark:border-woot-700"
            >
              <span class="i-lucide-user-check size-4 text-woot-500 shrink-0" />
              <div class="flex-1 min-w-0">
                <p
                  class="text-sm font-medium text-slate-800 dark:text-slate-100 truncate"
                >
                  {{ linkedContact.name }}
                </p>
                <p
                  v-if="linkedContact.phone_number"
                  class="text-xs text-slate-500"
                >
                  {{ linkedContact.phone_number }}
                </p>
              </div>
              <button
                class="text-xs text-red-500 hover:text-red-700 font-medium"
                @click="unlinkContact"
              >
                Desvincular
              </button>
            </div>
            <div v-else class="relative">
              <div class="flex items-center gap-2">
                <div class="relative flex-1">
                  <span
                    class="absolute left-2.5 top-1/2 -translate-y-1/2 i-lucide-search size-3.5 text-slate-400"
                  />
                  <input
                    v-model="contactSearchQuery"
                    type="text"
                    placeholder="Buscar por nome ou telefone..."
                    class="w-full text-sm pl-8 pr-3 py-2 border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                    @input="searchContacts"
                  />
                </div>
                <span
                  v-if="contactSearchLoading"
                  class="i-lucide-loader-circle size-4 animate-spin text-woot-500 shrink-0"
                />
              </div>
              <div
                v-if="contactSearchResults.length"
                class="absolute z-10 mt-1 w-full bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl shadow-lg overflow-hidden"
              >
                <button
                  v-for="c in contactSearchResults"
                  :key="c.id"
                  class="w-full flex items-center gap-2.5 px-3 py-2 hover:bg-slate-50 dark:hover:bg-slate-700 text-left transition-colors"
                  @click="selectContact(c)"
                >
                  <span
                    class="i-lucide-user size-3.5 text-slate-400 shrink-0"
                  />
                  <div class="min-w-0">
                    <p
                      class="text-sm font-medium text-slate-800 dark:text-slate-100 truncate"
                    >
                      {{ c.name }}
                    </p>
                    <p
                      v-if="c.phone_number"
                      class="text-xs text-slate-400 truncate"
                    >
                      {{ c.phone_number }}
                    </p>
                  </div>
                </button>
              </div>
            </div>
          </div>

          <!-- Basic info -->
          <div>
            <p
              class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-2"
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
                  v-model="newCard.title"
                  type="text"
                  placeholder="Nome do lead ou oportunidade"
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                  autofocus
                />
              </div>
              <div>
                <label
                  class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                  >Telefone</label
                >
                <input
                  v-model="newCard.phone"
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
                  v-model="newCard.cpf"
                  type="text"
                  placeholder="000.000.000-00"
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                />
              </div>
            </div>
          </div>

          <!-- Personal data -->
          <div>
            <p
              class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-2"
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
                  v-model="newCard.gender"
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
                  v-model="newCard.birthdate"
                  type="date"
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                />
              </div>
            </div>
          </div>

          <!-- Address -->
          <div>
            <p
              class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-2"
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
                    v-model="newCard.zipCode"
                    type="text"
                    placeholder="00000-000"
                    class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                    @blur="lookupCep"
                  />
                  <span
                    v-if="cepLoading"
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
                  v-model="newCard.street"
                  type="text"
                  placeholder="Rua, Av., Praça..."
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                />
              </div>
              <div>
                <label
                  class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                  >Número</label
                >
                <input
                  v-model="newCard.streetNumber"
                  type="text"
                  placeholder="123"
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                />
              </div>
              <div>
                <label
                  class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                  >Complemento</label
                >
                <input
                  v-model="newCard.addressComplement"
                  type="text"
                  placeholder="Apto, sala..."
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                />
              </div>
              <div>
                <label
                  class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                  >Bairro</label
                >
                <input
                  v-model="newCard.neighborhood"
                  type="text"
                  placeholder="Bairro"
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                />
              </div>
              <div>
                <label
                  class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                  >Cidade</label
                >
                <input
                  v-model="newCard.city"
                  type="text"
                  placeholder="Cidade"
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                />
              </div>
              <div>
                <label
                  class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1"
                  >Estado</label
                >
                <input
                  v-model="newCard.state"
                  type="text"
                  placeholder="SP"
                  maxlength="2"
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
                />
              </div>
            </div>
          </div>

          <!-- CRM -->
          <div>
            <p
              class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-2"
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
                  v-model="newCard.assigneeId"
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
                  >Observações</label
                >
                <textarea
                  v-model="newCard.notes"
                  placeholder="Anotações sobre este lead..."
                  rows="3"
                  class="w-full text-sm border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500 resize-none"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div
          class="px-5 py-3 bg-slate-50 dark:bg-slate-900 flex justify-end gap-2 rounded-b-xl border-t border-slate-100 dark:border-slate-700 shrink-0"
        >
          <button
            class="text-xs px-3 py-1.5 rounded-lg border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 font-medium transition-colors"
            @click="showAddCardModal = false"
          >
            Cancelar
          </button>
          <button
            :disabled="!newCard.title.trim() || uiFlags.isCreating"
            class="text-xs px-3 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 font-medium transition-colors disabled:opacity-50"
            @click="confirmAddCard"
          >
            {{ uiFlags.isCreating ? 'Criando...' : 'Criar lead' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
