<!-- eslint-disable vue/no-bare-strings-in-template, prettier/prettier -->
<script setup>
import { ref, watch, computed, onMounted } from 'vue';
import aiAgentsAPI from '../../api/aiAgents';
import AiAgentAssistant from './AiAgentAssistant.vue';
import AiAgentVersionDiff from './AiAgentVersionDiff.vue';
import AiAgentPlayground from './AiAgentPlayground.vue';

const props = defineProps({ agent: { type: Object, required: true } });
const emit = defineEmits(['updated']);

const saving        = ref(false);
const saved         = ref(false);
const draftSaving   = ref(false);
const draftSaved    = ref(false);
const error         = ref(null);
const showAssistant = ref(false);

const DEFAULT_PROMPT = {
  name: '',
  company: '',
  objectives: [],
  business: { name: '', description: '', target_audience: '' },
  products: [],
  personality: [],
  rules: [],
  flow: [],
};

function deepClone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

function activeSource(a) {
  return a.has_draft && a.prompt_draft && Object.keys(a.prompt_draft).length > 0
    ? a.prompt_draft
    : a.prompt;
}

const form = ref(deepClone({ ...DEFAULT_PROMPT, ...activeSource(props.agent) }));
const hasDraft = computed(() => props.agent.has_draft);

watch(
  () => props.agent,
  a => {
    form.value = deepClone({ ...DEFAULT_PROMPT, ...activeSource(a) });
  }
);

// ── Lists (objectives, personality, rules) ───────────────────────────────────
function addItem(list) {
  list.push('');
}
function removeItem(list, i) {
  list.splice(i, 1);
}

// ── Products ─────────────────────────────────────────────────────────────────
function addProduct() {
  form.value.products.push({
    name: '',
    description: '',
    value: '',
    target_audience: '',
  });
}
function removeProduct(i) {
  form.value.products.splice(i, 1);
}

// ── Flow ─────────────────────────────────────────────────────────────────────
function addStep() {
  form.value.flow.push({
    title: '',
    instruction: '',
    example: '',
    substeps: [],
    branches: [],
  });
}
function removeStep(i) {
  form.value.flow.splice(i, 1);
}
function addSubstep(step) {
  step.substeps.push({ title: '', instruction: '' });
}
function removeSubstep(step, i) {
  step.substeps.splice(i, 1);
}
function addBranch(step) {
  step.branches.push({ condition: '', action: '' });
}
function removeBranch(step, i) {
  step.branches.splice(i, 1);
}

// ── Prompt History ───────────────────────────────────────────────────────────
const versions       = ref([]);
const showHistory    = ref(false);
const diffVersionA   = ref(null);
const showDiff       = ref(false);

async function loadVersions() {
  const { data } = await aiAgentsAPI.getPromptVersions(props.agent.id);
  versions.value = data.payload;
}

function restoreVersion(v) {
  form.value        = deepClone({ ...DEFAULT_PROMPT, ...v.prompt });
  showHistory.value = false;
  showDiff.value    = false;
}

function openDiff(v) {
  diffVersionA.value = v;
  showDiff.value     = true;
  showHistory.value  = false;
}

onMounted(loadVersions);

// ── Save draft ───────────────────────────────────────────────────────────────
async function saveDraft() {
  draftSaving.value = true;
  error.value       = null;
  draftSaved.value  = false;
  try {
    const res = await aiAgentsAPI.saveDraft(props.agent.id, form.value);
    emit('updated', res.data.payload);
    draftSaved.value = true;
    setTimeout(() => { draftSaved.value = false; }, 3000);
  } catch {
    error.value = 'Erro ao salvar rascunho.';
  } finally {
    draftSaving.value = false;
  }
}

// ── Publish ───────────────────────────────────────────────────────────────────
async function save() {
  saving.value = true;
  error.value  = null;
  saved.value  = false;
  try {
    const res = await aiAgentsAPI.publishPrompt(props.agent.id, form.value);
    emit('updated', res.data.payload);
    saved.value = true;
    setTimeout(() => { saved.value = false; }, 3000);
  } catch {
    error.value = 'Erro ao publicar prompt.';
  } finally {
    saving.value = false;
  }
}

// ── Export ───────────────────────────────────────────────────────────────────
async function exportAgent() {
  try {
    const res      = await aiAgentsAPI.exportAgent(props.agent.id);
    const blob     = new Blob([res.data], { type: 'application/json' });
    const url      = URL.createObjectURL(blob);
    const a        = document.createElement('a');
    a.href         = url;
    a.download     = `ai-agent-${props.agent.name.toLowerCase().replace(/\s+/g, '-')}.json`;
    a.click();
    URL.revokeObjectURL(url);
  } catch {
    error.value = 'Erro ao exportar agente.';
  }
}

// ── Import prompt ────────────────────────────────────────────────────────────
const importFileRef = ref(null);

function triggerImportPrompt() {
  importFileRef.value?.click();
}

function onImportFileChange(event) {
  const file = event.target.files?.[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = e => {
    try {
      const json = JSON.parse(e.target.result);
      const promptData = json.agent?.prompt || json.prompt || json;
      form.value = deepClone({ ...DEFAULT_PROMPT, ...promptData });
      error.value = null;
    } catch {
      error.value = 'Arquivo inválido. Use um JSON exportado de um agente.';
    }
  };
  reader.readAsText(file);
  event.target.value = '';
}

// ── Playground section ───────────────────────────────────────────────────────
const showPlayground = ref(false);

const inputClass =
  'w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30';
const textareaClass = inputClass + ' resize-none';
const sectionClass =
  'bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 space-y-4';
const labelClass =
  'text-xs font-semibold text-slate-500 dark:text-slate-400 mb-1.5 block';
const addBtnClass =
  'text-[11px] text-violet-500 hover:underline flex items-center gap-1';
const removeBtnClass =
  'p-1 text-slate-300 hover:text-red-400 transition-colors shrink-0';
</script>

<template>
  <div class="space-y-5">
    <!-- Draft badge -->
    <div
      v-if="hasDraft && !saved"
      class="flex items-center gap-2 px-3 py-2 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg text-xs text-amber-700 dark:text-amber-300"
    >
      <span class="i-lucide-pencil size-3.5" />
      Editando rascunho — não publicado ainda
    </div>

    <!-- Save bar -->
    <div class="flex items-center justify-between">
      <div>
        <p class="text-xs text-slate-400">
          Versão publicada:
          <strong class="text-slate-600 dark:text-slate-300"
            >v{{ agent.prompt_version }}</strong
          >
        </p>
      </div>
      <div class="flex items-center gap-2 flex-wrap justify-end">
        <span
          v-if="saved"
          class="text-xs text-emerald-500 flex items-center gap-1"
        >
          <span class="i-lucide-check size-3.5" /> Publicado como v{{
            agent.prompt_version
          }}
        </span>
        <span
          v-if="draftSaved"
          class="text-xs text-amber-500 flex items-center gap-1"
        >
          <span class="i-lucide-check size-3.5" /> Rascunho salvo
        </span>
        <span v-if="error" class="text-xs text-red-500">{{ error }}</span>

        <!-- Import prompt (hidden file input) -->
        <input
          ref="importFileRef"
          type="file"
          accept=".json,application/json"
          class="hidden"
          @change="onImportFileChange"
        />
        <button
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium border border-slate-200 dark:border-slate-700 text-slate-500 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"
          @click="triggerImportPrompt"
        >
          <span class="i-lucide-upload size-3.5" /> Importar prompt
        </button>

        <!-- Export -->
        <button
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium border border-slate-200 dark:border-slate-700 text-slate-500 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"
          @click="exportAgent"
        >
          <span class="i-lucide-download size-3.5" /> Exportar
        </button>

        <!-- Assistente -->
        <button
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium border border-violet-200 dark:border-violet-800 text-violet-600 dark:text-violet-400 rounded-lg hover:bg-violet-50 dark:hover:bg-violet-900/20 transition-colors"
          @click="showAssistant = true"
        >
          <span class="i-lucide-sparkles size-3.5" /> Analisar
        </button>

        <!-- Histórico -->
        <button
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium border border-slate-200 dark:border-slate-700 text-slate-500 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"
          @click="showHistory = true"
        >
          <span class="i-lucide-history size-3.5" /> Histórico
        </button>

        <!-- Salvar rascunho -->
        <button
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium border border-amber-300 dark:border-amber-700 text-amber-600 dark:text-amber-400 rounded-lg hover:bg-amber-50 dark:hover:bg-amber-900/20 transition-colors disabled:opacity-50"
          :disabled="draftSaving"
          @click="saveDraft"
        >
          <span
            v-if="draftSaving"
            class="i-lucide-loader-2 size-3.5 animate-spin"
          />
          <span v-else class="i-lucide-pencil size-3.5" />
          {{ draftSaving ? 'Salvando...' : 'Rascunho' }}
        </button>

        <!-- Playground toggle -->
        <button
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium border rounded-lg transition-colors"
          :class="
            showPlayground
              ? 'border-emerald-400 text-emerald-600 bg-emerald-50 dark:bg-emerald-900/20 dark:border-emerald-700 dark:text-emerald-400'
              : 'border-slate-200 dark:border-slate-700 text-slate-500 hover:bg-slate-50 dark:hover:bg-slate-800'
          "
          @click="showPlayground = !showPlayground"
        >
          <span class="i-lucide-flask-conical size-3.5" /> Playground
        </button>

        <!-- Publicar -->
        <button
          class="flex items-center gap-1.5 px-4 py-2 text-xs font-semibold bg-violet-600 hover:bg-violet-700 text-white rounded-lg transition-colors disabled:opacity-50"
          :disabled="saving"
          @click="save"
        >
          <span v-if="saving" class="i-lucide-loader-2 size-3.5 animate-spin" />
          <span v-else class="i-lucide-send size-3.5" />
          {{ saving ? 'Publicando...' : 'Publicar' }}
        </button>
      </div>
    </div>

    <!-- Assistente modal -->
    <AiAgentAssistant
      v-if="showAssistant"
      :agent-id="agent.id"
      @close="showAssistant = false"
    />

    <!-- Version diff modal -->
    <AiAgentVersionDiff
      v-if="showDiff && diffVersionA"
      :version-a="diffVersionA"
      :label-a="`v${diffVersionA.version} (selecionada)`"
      :version-b="{
        version: agent.prompt_version,
        prompt: agent.prompt,
        created_by: 'publicada',
        created_at: agent.updated_at,
      }"
      :label-b="`v${agent.prompt_version} (publicada)`"
      @close="showDiff = false"
      @restore="
        v => {
          restoreVersion(v);
          showDiff = false;
        }
      "
    />

    <!-- History modal -->
    <div
      v-if="showHistory"
      class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
      @click.self="showHistory = false"
    >
      <div
        class="bg-white dark:bg-slate-900 rounded-xl shadow-xl w-full max-w-md p-6 flex flex-col gap-3 max-h-[80vh] overflow-y-auto"
      >
        <h3 class="text-base font-semibold text-slate-800 dark:text-slate-100">
          Histórico de versões
        </h3>
        <div
          v-if="versions.length === 0"
          class="text-sm text-slate-400 text-center py-6"
        >
          Nenhuma versão salva ainda.
        </div>
        <div
          v-for="v in versions"
          :key="v.id"
          class="border border-slate-200 dark:border-slate-700 rounded-lg p-3 flex items-center justify-between gap-3"
        >
          <div>
            <p class="text-sm font-medium text-slate-700 dark:text-slate-200">
              v{{ v.version }}
              <span
                v-if="v.version === agent.prompt_version"
                class="ml-1.5 text-[10px] bg-violet-100 dark:bg-violet-900/30 text-violet-600 dark:text-violet-400 px-1.5 py-0.5 rounded-full font-medium"
                >publicada</span
              >
            </p>
            <p class="text-xs text-slate-400">
              {{ v.created_by || 'Sistema' }} —
              {{ new Date(v.created_at).toLocaleString('pt-BR') }}
            </p>
          </div>
          <div class="flex items-center gap-2">
            <button
              class="text-xs px-2.5 py-1.5 rounded border border-slate-200 dark:border-slate-700 text-slate-500 hover:bg-slate-50 dark:hover:bg-slate-800"
              @click="openDiff(v)"
            >
              Comparar
            </button>
            <button
              class="text-xs px-2.5 py-1.5 rounded border border-violet-400 text-violet-600 hover:bg-violet-50 dark:hover:bg-violet-900/20"
              @click="restoreVersion(v)"
            >
              Restaurar
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Identidade -->
    <div :class="sectionClass">
      <h3
        class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
      >
        <span class="i-lucide-user size-4 text-violet-500" /> Identidade
      </h3>
      <div class="grid grid-cols-2 gap-4">
        <div>
          <label :class="labelClass">Nome do agente</label>
          <input
            v-model="form.name"
            type="text"
            placeholder="Sofia"
            :class="inputClass"
          />
        </div>
        <div>
          <label :class="labelClass">Empresa</label>
          <input
            v-model="form.company"
            type="text"
            placeholder="Volponi Advogados"
            :class="inputClass"
          />
        </div>
      </div>

      <!-- Objetivos -->
      <div>
        <label :class="labelClass">Objetivos</label>
        <div
          v-for="(obj, i) in form.objectives"
          :key="i"
          class="flex gap-2 mb-2 items-center"
        >
          <input
            v-model="form.objectives[i]"
            type="text"
            placeholder="Ex: Qualificar leads"
            :class="inputClass"
          />
          <button
            :class="removeBtnClass"
            @click="removeItem(form.objectives, i)"
          >
            <span class="i-lucide-x size-3.5" />
          </button>
        </div>
        <button :class="addBtnClass" @click="addItem(form.objectives)">
          <span class="i-lucide-plus size-3" /> Adicionar objetivo
        </button>
      </div>
    </div>

    <!-- Negócio -->
    <div :class="sectionClass">
      <h3
        class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
      >
        <span class="i-lucide-building-2 size-4 text-violet-500" /> Negócio
      </h3>
      <div>
        <label :class="labelClass">Nome da empresa</label>
        <input
          v-model="form.business.name"
          type="text"
          placeholder="Nome completo da empresa"
          :class="inputClass"
        />
      </div>
      <div>
        <label :class="labelClass">Descrição</label>
        <textarea
          v-model="form.business.description"
          rows="3"
          placeholder="O que a empresa faz..."
          :class="textareaClass"
        />
      </div>
      <div>
        <label :class="labelClass">Público-alvo</label>
        <input
          v-model="form.business.target_audience"
          type="text"
          placeholder="Ex: Pequenas e médias empresas"
          :class="inputClass"
        />
      </div>
    </div>

    <!-- Produtos -->
    <div :class="sectionClass">
      <div class="flex items-center justify-between">
        <h3
          class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
        >
          <span class="i-lucide-package size-4 text-violet-500" /> Produtos /
          Serviços
        </h3>
        <button :class="addBtnClass" @click="addProduct">
          <span class="i-lucide-plus size-3" /> Adicionar
        </button>
      </div>
      <div
        v-for="(product, i) in form.products"
        :key="i"
        class="border border-slate-100 dark:border-slate-700 rounded-lg p-3 space-y-2 relative"
      >
        <button
          class="absolute top-2 right-2"
          :class="[removeBtnClass]"
          @click="removeProduct(i)"
        >
          <span class="i-lucide-x size-3.5" />
        </button>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label :class="labelClass">Nome</label>
            <input
              v-model="product.name"
              type="text"
              placeholder="Nome do produto"
              :class="inputClass"
            />
          </div>
          <div>
            <label :class="labelClass">Valor</label>
            <input
              v-model="product.value"
              type="text"
              placeholder="Ex: R$ 497/mês"
              :class="inputClass"
            />
          </div>
        </div>
        <div>
          <label :class="labelClass">Descrição</label>
          <textarea
            v-model="product.description"
            rows="2"
            placeholder="O que inclui..."
            :class="textareaClass"
          />
        </div>
        <div>
          <label :class="labelClass">Público-alvo</label>
          <input
            v-model="product.target_audience"
            type="text"
            placeholder="Para quem é"
            :class="inputClass"
          />
        </div>
      </div>
      <p v-if="!form.products.length" class="text-xs text-slate-400 italic">
        Nenhum produto adicionado
      </p>
    </div>

    <!-- Personalidade -->
    <div :class="sectionClass">
      <h3
        class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
      >
        <span class="i-lucide-sparkles size-4 text-violet-500" /> Personalidade
      </h3>
      <div
        v-for="(p, i) in form.personality"
        :key="i"
        class="flex gap-2 mb-2 items-center"
      >
        <input
          v-model="form.personality[i]"
          type="text"
          placeholder="Ex: Empática e objetiva"
          :class="inputClass"
        />
        <button
          :class="removeBtnClass"
          @click="removeItem(form.personality, i)"
        >
          <span class="i-lucide-x size-3.5" />
        </button>
      </div>
      <button :class="addBtnClass" @click="addItem(form.personality)">
        <span class="i-lucide-plus size-3" /> Adicionar traço
      </button>
    </div>

    <!-- Regras -->
    <div :class="sectionClass">
      <h3
        class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
      >
        <span class="i-lucide-shield size-4 text-violet-500" /> Regras Gerais
      </h3>
      <div
        v-for="(r, i) in form.rules"
        :key="i"
        class="flex gap-2 mb-2 items-start"
      >
        <textarea
          v-model="form.rules[i]"
          rows="2"
          placeholder="Ex: Nunca mencionar concorrentes"
          :class="textareaClass"
        />
        <button
          class="mt-1"
          :class="[removeBtnClass]"
          @click="removeItem(form.rules, i)"
        >
          <span class="i-lucide-x size-3.5" />
        </button>
      </div>
      <button :class="addBtnClass" @click="addItem(form.rules)">
        <span class="i-lucide-plus size-3" /> Adicionar regra
      </button>
    </div>

    <!-- Fluxo de conversão -->
    <div :class="sectionClass">
      <div class="flex items-center justify-between">
        <h3
          class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
        >
          <span class="i-lucide-git-branch size-4 text-violet-500" /> Fluxo de
          Conversão
        </h3>
        <button :class="addBtnClass" @click="addStep">
          <span class="i-lucide-plus size-3" /> Adicionar etapa
        </button>
      </div>

      <div
        v-for="(step, si) in form.flow"
        :key="si"
        class="border border-slate-200 dark:border-slate-700 rounded-xl p-4 space-y-3"
      >
        <div class="flex items-center justify-between">
          <span class="text-xs font-bold text-violet-500"
            >Etapa {{ si + 1 }}</span
          >
          <button :class="removeBtnClass" @click="removeStep(si)">
            <span class="i-lucide-trash-2 size-3.5" />
          </button>
        </div>

        <div>
          <label :class="labelClass">Título</label>
          <input
            v-model="step.title"
            type="text"
            placeholder="Ex: Identificar interesse"
            :class="inputClass"
          />
        </div>
        <div>
          <label :class="labelClass">Instrução</label>
          <textarea
            v-model="step.instruction"
            rows="3"
            placeholder="O que o agente deve fazer nesta etapa..."
            :class="textareaClass"
          />
        </div>
        <div>
          <label :class="labelClass">Exemplo de mensagem</label>
          <textarea
            v-model="step.example"
            rows="2"
            placeholder="Ex: Olá! Vi que você tem interesse em..."
            :class="textareaClass"
          />
        </div>

        <!-- Subetapas -->
        <div
          class="pl-3 border-l-2 border-violet-100 dark:border-violet-900 space-y-2"
        >
          <div class="flex items-center justify-between">
            <span class="text-[11px] font-semibold text-slate-400"
              >Subetapas</span
            >
            <button :class="addBtnClass" @click="addSubstep(step)">
              <span class="i-lucide-plus size-3" /> Adicionar
            </button>
          </div>
          <div
            v-for="(sub, ssi) in step.substeps"
            :key="ssi"
            class="flex gap-2 items-start"
          >
            <div class="flex-1 space-y-1.5">
              <input
                v-model="sub.title"
                type="text"
                placeholder="Título da subetapa"
                :class="inputClass"
              />
              <textarea
                v-model="sub.instruction"
                rows="2"
                placeholder="Instrução..."
                :class="textareaClass"
              />
            </div>
            <button
              class="mt-1"
              :class="[removeBtnClass]"
              @click="removeSubstep(step, ssi)"
            >
              <span class="i-lucide-x size-3.5" />
            </button>
          </div>
        </div>

        <!-- Ramos -->
        <div
          class="pl-3 border-l-2 border-amber-100 dark:border-amber-900 space-y-2"
        >
          <div class="flex items-center justify-between">
            <span class="text-[11px] font-semibold text-slate-400"
              >Ramos condicionais</span
            >
            <button :class="addBtnClass" @click="addBranch(step)">
              <span class="i-lucide-plus size-3" /> Adicionar
            </button>
          </div>
          <div
            v-for="(branch, bi) in step.branches"
            :key="bi"
            class="flex gap-2 items-start"
          >
            <div class="flex-1 space-y-1.5">
              <input
                v-model="branch.condition"
                type="text"
                placeholder="Se..."
                :class="inputClass"
              />
              <input
                v-model="branch.action"
                type="text"
                placeholder="Então..."
                :class="inputClass"
              />
            </div>
            <button
              class="mt-1"
              :class="[removeBtnClass]"
              @click="removeBranch(step, bi)"
            >
              <span class="i-lucide-x size-3.5" />
            </button>
          </div>
        </div>
      </div>
      <p v-if="!form.flow.length" class="text-xs text-slate-400 italic">
        Nenhuma etapa de conversão definida
      </p>
    </div>

    <!-- Playground section -->
    <div v-if="showPlayground" :class="sectionClass">
      <div class="flex items-center gap-2 mb-3">
        <span class="i-lucide-flask-conical size-4 text-emerald-500" />
        <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200">
          Playground
        </h3>
        <span class="text-[11px] text-slate-400"
          >— teste o agente antes de publicar</span
        >
      </div>
      <AiAgentPlayground :agent="agent" />
    </div>

    <!-- Save bottom -->
    <div class="flex justify-end gap-2 pt-2">
      <button
        class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium border border-amber-300 dark:border-amber-700 text-amber-600 dark:text-amber-400 rounded-lg hover:bg-amber-50 dark:hover:bg-amber-900/20 transition-colors disabled:opacity-50"
        :disabled="draftSaving"
        @click="saveDraft"
      >
        <span
          v-if="draftSaving"
          class="i-lucide-loader-2 size-3.5 animate-spin"
        />
        <span v-else class="i-lucide-pencil size-3.5" />
        {{ draftSaving ? 'Salvando...' : 'Salvar rascunho' }}
      </button>
      <button
        class="flex items-center gap-1.5 px-4 py-2 text-xs font-semibold bg-violet-600 hover:bg-violet-700 text-white rounded-lg transition-colors disabled:opacity-50"
        :disabled="saving"
        @click="save"
      >
        <span v-if="saving" class="i-lucide-loader-2 size-3.5 animate-spin" />
        <span v-else class="i-lucide-send size-3.5" />
        {{ saving ? 'Publicando...' : 'Publicar' }}
      </button>
    </div>
  </div>
</template>
