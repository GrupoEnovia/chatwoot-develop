<!-- eslint-disable vue/no-bare-strings-in-template -->
<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore } from 'vuex';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const store = useStore();
const loading = ref(false);
const enabled = ref(null);

const conversationLabels = computed(
  () =>
    store.getters['conversationLabels/getConversationLabels'](
      props.conversationId
    ) || []
);

function deriveState() {
  if (conversationLabels.value.includes('ia_desligada')) {
    enabled.value = false;
  } else if (conversationLabels.value.includes('ia_ligada')) {
    enabled.value = true;
  } else {
    enabled.value = null;
  }
}

async function toggle() {
  loading.value = true;
  const next = !enabled.value;
  const addLabel = next ? 'ia_ligada' : 'ia_desligada';
  const removeLabel = next ? 'ia_desligada' : 'ia_ligada';
  const current = conversationLabels.value.filter(l => l !== removeLabel);
  if (!current.includes(addLabel)) current.push(addLabel);
  try {
    await store.dispatch('conversationLabels/update', {
      conversationId: props.conversationId,
      labels: current,
    });
    enabled.value = next;
  } catch {
    // ignore
  } finally {
    loading.value = false;
  }
}

watch(conversationLabels, deriveState);
onMounted(deriveState);
</script>

<template>
  <div
    class="flex items-center justify-between px-4 py-2.5 rounded-xl border"
    :class="
      enabled
        ? 'border-violet-200 dark:border-violet-800 bg-violet-50 dark:bg-violet-900/20'
        : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800'
    "
  >
    <div class="flex items-center gap-2">
      <span
        class="size-3.5"
        :class="
          enabled
            ? 'i-lucide-bot text-violet-500'
            : 'i-lucide-bot-off text-slate-400'
        "
      />
      <span class="text-xs font-medium text-slate-700 dark:text-slate-200">
        Agente IA
      </span>
      <span v-if="enabled === null" class="text-[10px] text-slate-400">
        (indefinido)
      </span>
    </div>

    <button
      class="relative inline-flex h-5 w-9 shrink-0 cursor-pointer items-center rounded-full border-2 transition-colors duration-200 focus:outline-none disabled:opacity-50"
      :class="
        enabled
          ? 'border-violet-500 bg-violet-500'
          : 'border-slate-300 dark:border-slate-600 bg-slate-200 dark:bg-slate-600'
      "
      :disabled="loading"
      @click="toggle"
    >
      <span
        class="inline-block size-4 rounded-full bg-white shadow transition-transform duration-200"
        :class="enabled ? 'translate-x-4' : 'translate-x-0'"
      />
    </button>
  </div>
</template>
