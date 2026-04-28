<!-- eslint-disable vue/no-bare-strings-in-template, prettier/prettier -->
<script setup>
import { ref, nextTick } from 'vue';
import aiAgentsAPI from '../../api/aiAgents';

const props = defineProps({ agent: { type: Object, required: true } });

const messages  = ref([]);
const input     = ref('');
const loading   = ref(false);
const useDraft  = ref(false);
const error     = ref(null);
const chatRef   = ref(null);

function scrollToBottom() {
  nextTick(() => {
    if (chatRef.value) chatRef.value.scrollTop = chatRef.value.scrollHeight;
  });
}

async function send() {
  const text = input.value.trim();
  if (!text || loading.value) return;

  messages.value.push({ role: 'user', content: text });
  input.value = '';
  loading.value = true;
  error.value = null;
  scrollToBottom();

  try {
    const res = await aiAgentsAPI.playground(props.agent.id, messages.value, useDraft.value);
    const reply = res.data?.payload?.response || '';
    messages.value.push({ role: 'assistant', content: reply });
    scrollToBottom();
  } catch (e) {
    error.value = e.response?.data?.error || 'Erro ao conectar com o agente.';
    messages.value.pop();
  } finally {
    loading.value = false;
  }
}

function clearChat() {
  messages.value = [];
  error.value = null;
}

function handleKey(e) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    send();
  }
}
</script>

<template>
  <div
    class="flex flex-col h-[680px] border border-slate-200 dark:border-slate-700 rounded-xl overflow-hidden bg-white dark:bg-slate-900"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between px-4 py-3 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 shrink-0"
    >
      <div class="flex items-center gap-3">
        <div
          class="size-8 rounded-full bg-violet-100 dark:bg-violet-900 flex items-center justify-center"
        >
          <span
            class="i-lucide-bot size-4 text-violet-600 dark:text-violet-400"
          />
        </div>
        <div>
          <p class="text-sm font-semibold text-slate-700 dark:text-slate-200">
            {{ agent.name }}
          </p>
          <p class="text-[11px] text-slate-400">
            Playground · {{ agent.llm_provider }} / {{ agent.llm_model }}
          </p>
        </div>
      </div>
      <div class="flex items-center gap-3">
        <label class="flex items-center gap-1.5 cursor-pointer select-none">
          <button
            class="transition-colors"
            :class="
              useDraft ? 'text-amber-500' : 'text-slate-300 dark:text-slate-600'
            "
            @click="useDraft = !useDraft"
          >
            <span
              :class="
                useDraft
                  ? 'i-lucide-toggle-right size-5'
                  : 'i-lucide-toggle-left size-5'
              "
            />
          </button>
          <span class="text-[11px] text-slate-500 dark:text-slate-400">
            Usar rascunho
            <span
              v-if="useDraft && agent.has_draft"
              class="text-amber-500 font-medium"
              >(ativo)</span
            >
            <span
              v-else-if="useDraft && !agent.has_draft"
              class="text-slate-400"
              >(sem rascunho)</span
            >
          </span>
        </label>
        <button
          class="text-[11px] flex items-center gap-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 transition-colors"
          @click="clearChat"
        >
          <span class="i-lucide-trash-2 size-3.5" /> Limpar
        </button>
      </div>
    </div>

    <!-- Messages -->
    <div ref="chatRef" class="flex-1 overflow-y-auto px-4 py-4 space-y-3">
      <div
        v-if="messages.length === 0"
        class="flex flex-col items-center justify-center h-full text-center gap-3"
      >
        <span
          class="i-lucide-message-square-text size-10 text-slate-200 dark:text-slate-700"
        />
        <p class="text-sm text-slate-400">
          Envie uma mensagem para testar o agente
        </p>
        <p class="text-[11px] text-slate-300 dark:text-slate-600">
          O agente responderá usando o prompt
          {{ useDraft && agent.has_draft ? 'rascunho' : 'publicado' }}
        </p>
      </div>

      <template v-else>
        <div
          v-for="(msg, i) in messages"
          :key="i"
          class="flex"
          :class="msg.role === 'user' ? 'justify-end' : 'justify-start'"
        >
          <div
            class="max-w-[75%] rounded-2xl px-4 py-2.5 text-sm leading-relaxed whitespace-pre-wrap"
            :class="
              msg.role === 'user'
                ? 'bg-violet-600 text-white rounded-br-sm'
                : 'bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-200 rounded-bl-sm'
            "
          >
            {{ msg.content }}
          </div>
        </div>

        <!-- Typing indicator -->
        <div v-if="loading" class="flex justify-start">
          <div
            class="bg-slate-100 dark:bg-slate-800 rounded-2xl rounded-bl-sm px-4 py-3 flex gap-1 items-center"
          >
            <span
              class="size-1.5 bg-slate-400 rounded-full animate-bounce"
              style="animation-delay: 0ms"
            />
            <span
              class="size-1.5 bg-slate-400 rounded-full animate-bounce"
              style="animation-delay: 150ms"
            />
            <span
              class="size-1.5 bg-slate-400 rounded-full animate-bounce"
              style="animation-delay: 300ms"
            />
          </div>
        </div>
      </template>

      <div v-if="error" class="flex justify-center">
        <p
          class="text-xs text-red-500 bg-red-50 dark:bg-red-900/20 px-3 py-1.5 rounded-lg"
        >
          {{ error }}
        </p>
      </div>
    </div>

    <!-- Input -->
    <div
      class="border-t border-slate-200 dark:border-slate-700 px-4 py-3 shrink-0"
    >
      <div class="flex gap-2 items-end">
        <textarea
          v-model="input"
          rows="2"
          placeholder="Escreva uma mensagem... (Enter para enviar)"
          class="flex-1 text-sm px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/30 resize-none"
          :disabled="loading"
          @keydown="handleKey"
        />
        <button
          class="flex items-center justify-center size-10 rounded-xl bg-violet-600 hover:bg-violet-700 text-white transition-colors disabled:opacity-40 shrink-0"
          :disabled="loading || !input.trim()"
          @click="send"
        >
          <span v-if="loading" class="i-lucide-loader-2 size-4 animate-spin" />
          <span v-else class="i-lucide-send size-4" />
        </button>
      </div>
    </div>
  </div>
</template>
