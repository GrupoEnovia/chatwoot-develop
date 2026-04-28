<!-- eslint-disable vue/no-bare-strings-in-template, prettier/prettier -->
<script setup>
import { ref, watch, computed } from 'vue';
import { useStore } from 'vuex';
import aiAgentsAPI from '../../api/aiAgents';
import AiAgentProtocols from './AiAgentProtocols.vue';

const props = defineProps({ agent: { type: Object, required: true } });
const emit = defineEmits(['updated']);

const store = useStore();
const saving = ref(false);
const saved = ref(false);
const error = ref(null);

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

const LLM_MODELS_BY_PROVIDER = {
  openai: [
    { value: 'gpt-4o', label: 'GPT-4o' },
    { value: 'gpt-4o-mini', label: 'GPT-4o Mini' },
    { value: 'gpt-4-turbo', label: 'GPT-4 Turbo' },
  ],
  anthropic: [
    { value: 'claude-opus-4-7', label: 'Claude Opus 4' },
    { value: 'claude-sonnet-4-6', label: 'Claude Sonnet 4' },
    { value: 'claude-haiku-4-5-20251001', label: 'Claude Haiku 4.5' },
  ],
  gemini: [
    { value: 'gemini-2.0-flash', label: 'Gemini 2.0 Flash' },
    { value: 'gemini-2.0-flash-lite', label: 'Gemini 2.0 Flash Lite' },
    { value: 'gemini-1.5-pro', label: 'Gemini 1.5 Pro' },
    { value: 'gemini-1.5-flash', label: 'Gemini 1.5 Flash' },
  ],
};

const inboxes = ref(store.getters['inboxes/getInboxes'] || []);

const form = ref({
  name: props.agent.name,
  company: props.agent.company,
  language: props.agent.language,
  timezone: props.agent.timezone,
  inbox_id: props.agent.inbox_id,
  active: props.agent.active,
  message_buffer_seconds: props.agent.message_buffer_seconds,
  llm_provider: props.agent.llm_provider || 'openai',
  llm_model: props.agent.llm_model || 'gpt-4o',
  llm_api_key_encrypted: '',
  tts_enabled: props.agent.tts_enabled,
  tts_voice_id: props.agent.tts_voice_id || '',
  tts_api_key_encrypted: '',
  reactivation_command: props.agent.reactivation_command || '/ia',
  message_chunk_size: props.agent.message_chunk_size || 300,
});

watch(
  () => props.agent,
  a => {
    form.value = {
      name: a.name,
      company: a.company,
      language: a.language,
      timezone: a.timezone,
      inbox_id: a.inbox_id,
      active: a.active,
      message_buffer_seconds: a.message_buffer_seconds,
      llm_provider: a.llm_provider || 'openai',
      llm_model: a.llm_model || 'gpt-4o',
      llm_api_key_encrypted: '',
      tts_enabled: a.tts_enabled,
      tts_voice_id: a.tts_voice_id || '',
      tts_api_key_encrypted: '',
      reactivation_command: a.reactivation_command || '/ia',
      message_chunk_size: a.message_chunk_size || 300,
    };
  }
);

const llmModels = computed(
  () => LLM_MODELS_BY_PROVIDER[form.value.llm_provider] || LLM_MODELS_BY_PROVIDER.openai
);

async function save() {
  saving.value = true;
  error.value = null;
  saved.value = false;
  try {
    const payload = { ...form.value };
    if (!payload.llm_api_key_encrypted) delete payload.llm_api_key_encrypted;
    if (!payload.tts_api_key_encrypted) delete payload.tts_api_key_encrypted;
    const res = await aiAgentsAPI.update(props.agent.id, payload);
    emit('updated', res.data.payload);
    saved.value = true;
    setTimeout(() => {
      saved.value = false;
    }, 3000);
  } catch {
    error.value = 'Erro ao salvar configurações.';
  } finally {
    saving.value = false;
  }
}

const inputClass =
  'w-full text-xs px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30';
const sectionClass =
  'bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 space-y-4';
const labelClass =
  'text-xs font-semibold text-slate-500 dark:text-slate-400 mb-1.5 block';
</script>

<template>
  <div class="space-y-5">
    <!-- Save bar -->
    <div class="flex items-center justify-end gap-2">
      <span
        v-if="saved"
        class="text-xs text-emerald-500 flex items-center gap-1"
      >
        <span class="i-lucide-check size-3.5" /> Configurações salvas
      </span>
      <span v-if="error" class="text-xs text-red-500">{{ error }}</span>
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

    <!-- Geral -->
    <div :class="sectionClass">
      <h3
        class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
      >
        <span class="i-lucide-info size-4 text-violet-500" /> Geral
      </h3>
      <div class="grid grid-cols-2 gap-4">
        <div>
          <label :class="labelClass">Nome do agente</label>
          <input v-model="form.name" type="text" :class="inputClass" />
        </div>
        <div>
          <label :class="labelClass">Empresa</label>
          <input v-model="form.company" type="text" :class="inputClass" />
        </div>
        <div>
          <label :class="labelClass">Idioma</label>
          <select v-model="form.language" :class="inputClass">
            <option value="pt-BR">Português (BR)</option>
            <option value="pt-PT">Português (PT)</option>
            <option value="en">English</option>
            <option value="es">Español</option>
          </select>
        </div>
        <div>
          <label :class="labelClass">Timezone</label>
          <select v-model="form.timezone" :class="inputClass">
            <option v-for="tz in TIMEZONES" :key="tz" :value="tz">
              {{ tz }}
            </option>
          </select>
        </div>
        <div>
          <label :class="labelClass">Inbox vinculada</label>
          <select v-model="form.inbox_id" :class="inputClass">
            <option :value="null">Sem inbox</option>
            <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
              {{ inbox.name }}
            </option>
          </select>
        </div>
        <div>
          <label :class="labelClass">Buffer de mensagens (segundos)</label>
          <input
            v-model.number="form.message_buffer_seconds"
            type="number"
            min="10"
            max="300"
            :class="inputClass"
          />
        </div>
      </div>
      <div class="flex items-center gap-3">
        <label :class="labelClass" class="mb-0">Agente ativo</label>
        <button
          class="transition-colors"
          :class="
            form.active
              ? 'text-emerald-500'
              : 'text-slate-300 dark:text-slate-600'
          "
          @click="form.active = !form.active"
        >
          <span
            :class="
              form.active
                ? 'i-lucide-toggle-right size-6'
                : 'i-lucide-toggle-left size-6'
            "
          />
        </button>
      </div>
    </div>

    <!-- LLM -->
    <div :class="sectionClass">
      <h3
        class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
      >
        <span class="i-lucide-cpu size-4 text-violet-500" /> Modelo de IA
      </h3>
      <div class="grid grid-cols-2 gap-4">
        <div>
          <label :class="labelClass">Provedor</label>
          <select v-model="form.llm_provider" :class="inputClass">
            <option value="openai">OpenAI</option>
            <option value="anthropic">Anthropic</option>
            <option value="gemini">Google Gemini</option>
          </select>
        </div>
        <div>
          <label :class="labelClass">Modelo</label>
          <select v-model="form.llm_model" :class="inputClass">
            <option v-for="m in llmModels" :key="m.value" :value="m.value">
              {{ m.label }}
            </option>
          </select>
        </div>
      </div>
      <div>
        <label :class="labelClass"
          >API Key (deixe em branco para manter a atual)</label
        >
        <input
          v-model="form.llm_api_key_encrypted"
          type="password"
          placeholder="sk-..."
          :class="inputClass"
          autocomplete="off"
        />
      </div>
    </div>

    <!-- Comportamento -->
    <div :class="sectionClass">
      <h3
        class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
      >
        <span class="i-lucide-sliders-horizontal size-4 text-violet-500" />
        Comportamento
      </h3>
      <div class="grid grid-cols-2 gap-4">
        <div>
          <label :class="labelClass">Comando de reativação da IA</label>
          <input
            v-model="form.reactivation_command"
            type="text"
            placeholder="/ia"
            :class="inputClass"
          />
          <p class="text-[11px] text-slate-400 mt-1">
            Operadores enviam este comando para reativar o agente após pausa
            manual.
          </p>
        </div>
        <div>
          <label :class="labelClass"
            >Tamanho do chunk de mensagem (chars)</label
          >
          <input
            v-model.number="form.message_chunk_size"
            type="number"
            min="50"
            max="2000"
            step="50"
            :class="inputClass"
          />
          <p class="text-[11px] text-slate-400 mt-1">
            Mensagens longas são divididas em partes aproximadas deste tamanho.
          </p>
        </div>
      </div>
    </div>

    <!-- Protocols -->
    <div :class="sectionClass">
      <h3
        class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
      >
        <span class="i-lucide-git-branch size-4 text-violet-500" /> Protocolos
      </h3>
      <AiAgentProtocols :agent-id="agent.id" />
    </div>

    <!-- TTS -->
    <div :class="sectionClass">
      <div class="flex items-center gap-3 mb-2">
        <h3
          class="text-sm font-semibold text-slate-700 dark:text-slate-200 flex items-center gap-2"
        >
          <span class="i-lucide-mic size-4 text-violet-500" /> TTS — ElevenLabs
        </h3>
        <button
          class="transition-colors"
          :class="
            form.tts_enabled
              ? 'text-emerald-500'
              : 'text-slate-300 dark:text-slate-600'
          "
          @click="form.tts_enabled = !form.tts_enabled"
        >
          <span
            :class="
              form.tts_enabled
                ? 'i-lucide-toggle-right size-6'
                : 'i-lucide-toggle-left size-6'
            "
          />
        </button>
      </div>
      <template v-if="form.tts_enabled">
        <div>
          <label :class="labelClass">Voice ID</label>
          <input
            v-model="form.tts_voice_id"
            type="text"
            placeholder="Ex: EXAVITQu4vr4xnSDxMaL"
            :class="inputClass"
          />
        </div>
        <div>
          <label :class="labelClass"
            >ElevenLabs API Key (deixe em branco para manter)</label
          >
          <input
            v-model="form.tts_api_key_encrypted"
            type="password"
            placeholder="API Key..."
            :class="inputClass"
            autocomplete="off"
          />
        </div>
      </template>
    </div>
  </div>
</template>
