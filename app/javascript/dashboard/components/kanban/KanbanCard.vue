<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';

const props = defineProps({
  item: { type: Object, required: true },
  stageColor: { type: String, default: '#6366f1' },
});

const emit = defineEmits(['click']);

const SOURCE_ICONS = {
  website: 'i-lucide-globe',
  whatsapp: 'i-lucide-message-circle',
  instagram: 'i-lucide-camera',
  facebook: 'i-lucide-facebook',
  phone: 'i-lucide-phone-call',
  email: 'i-lucide-mail',
  referral: 'i-lucide-users',
  manual: 'i-lucide-hand',
};

const TEMPERATURE_CONFIG = {
  cold: { emoji: '❄️', label: 'Frio', cls: 'text-blue-500' },
  warm: { emoji: '🌡', label: 'Morno', cls: 'text-yellow-500' },
  hot: { emoji: '🔥', label: 'Quente', cls: 'text-orange-500' },
  very_hot: { emoji: '💥', label: 'Muito Quente', cls: 'text-red-500' },
};

const statusClass = computed(() => {
  if (props.item.status === 'won')
    return 'text-green-700 bg-green-50 border-green-200';
  if (props.item.status === 'lost')
    return 'text-red-700 bg-red-50 border-red-200';
  return null;
});

const formattedValue = computed(() => {
  if (!props.item.value || props.item.value === '0.0') return null;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  }).format(props.item.value);
});

const formattedCloseDate = computed(() => {
  if (!props.item.expected_close_date) return null;
  const d = new Date(props.item.expected_close_date + 'T00:00:00');
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const diff = Math.ceil((d - today) / 86400000);
  if (diff < 0) return { label: `${Math.abs(diff)}d atrasado`, overdue: true };
  if (diff === 0) return { label: 'hoje', overdue: false };
  if (diff <= 7) return { label: `${diff}d`, overdue: false };
  return {
    label: d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' }),
    overdue: false,
  };
});

const sourceIcon = computed(() => SOURCE_ICONS[props.item.source] || null);
const tempCfg = computed(
  () => TEMPERATURE_CONFIG[props.item.temperature] || null
);
const hasTasks = computed(
  () => props.item.pending_tasks_count > 0 || props.item.tasks_count > 0
);
const hasAttachments = computed(() => props.item.attachments_count > 0);

const store = useStore();
const allLabels = computed(() => store.getters['labels/getLabels'] || []);
const conversationLabels = computed(() => {
  const names = props.item.conversation_labels || [];
  return names.map(name => {
    const found = allLabels.value.find(l => l.title === name);
    return { title: name, color: found?.color || '#6366f1' };
  });
});
</script>

<template>
  <div
    class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 select-none hover:shadow-md transition-shadow duration-150 group/card cursor-grab active:cursor-grabbing"
    :style="{ borderLeftColor: stageColor, borderLeftWidth: '3px' }"
    @click="emit('click', item)"
  >
    <!-- Card content -->
    <div class="flex items-start px-2 pt-2.5 pb-0">
      <div class="flex-1 min-w-0 pb-2.5">
        <!-- Title + status badge -->
        <div class="flex items-start justify-between gap-2 mb-1.5">
          <p
            class="text-sm font-medium text-slate-800 dark:text-slate-100 leading-snug line-clamp-2 flex-1"
          >
            {{ item.title }}
          </p>
          <span
            v-if="statusClass"
            class="shrink-0 text-[10px] font-semibold px-1.5 py-0.5 rounded border"
            :class="statusClass"
          >
            {{ item.status === 'won' ? 'Ganho' : 'Perdido' }}
          </span>
        </div>

        <!-- Lost reason badge -->
        <div v-if="item.lost_reason" class="mb-1.5">
          <span
            class="inline-flex items-center gap-1 text-[10px] font-medium px-1.5 py-0.5 rounded bg-red-50 dark:bg-red-900/30 text-red-600 dark:text-red-400 border border-red-200 dark:border-red-800"
          >
            <span class="i-lucide-tag size-2.5" />
            {{ item.lost_reason.name }}
          </span>
        </div>

        <!-- Source + Temperature -->
        <div
          v-if="sourceIcon || tempCfg"
          class="flex items-center gap-2 mb-1.5"
        >
          <span
            v-if="sourceIcon"
            class="flex items-center gap-1 text-xs text-slate-400"
          >
            <span class="size-3" :class="[sourceIcon]" />
            <span class="capitalize">{{ item.source }}</span>
          </span>
          <span
            v-if="tempCfg"
            class="flex items-center gap-1 text-xs"
            :class="tempCfg.cls"
          >
            {{ tempCfg.emoji }} {{ tempCfg.label }}
          </span>
          <span
            v-if="item.probability > 0"
            class="ml-auto text-xs text-slate-400"
            >{{ item.probability }}%</span
          >
        </div>

        <!-- Value + Close date -->
        <div
          v-if="formattedValue || formattedCloseDate"
          class="flex items-center justify-between mb-1.5"
        >
          <span
            v-if="formattedValue"
            class="text-xs font-semibold text-woot-600 dark:text-woot-400"
          >
            {{ formattedValue }}
          </span>
          <span v-else class="flex-1" />
          <span
            v-if="formattedCloseDate"
            class="flex items-center gap-1 text-[10px] font-medium px-1.5 py-0.5 rounded"
            :class="
              formattedCloseDate.overdue
                ? 'text-red-600 bg-red-50 dark:bg-red-900/30'
                : 'text-slate-500 bg-slate-100 dark:bg-slate-700'
            "
          >
            <span class="i-lucide-calendar size-2.5" />
            {{ formattedCloseDate.label }}
          </span>
        </div>

        <!-- Phone -->
        <div v-if="item.contact_phone" class="flex items-center gap-1 mb-1.5">
          <span class="i-lucide-phone size-3 text-slate-400" />
          <span class="text-xs text-slate-500 dark:text-slate-400">{{
            item.contact_phone
          }}</span>
        </div>

        <!-- Conversation labels -->
        <div
          v-if="conversationLabels.length"
          class="flex flex-wrap gap-1 mb-1.5"
        >
          <span
            v-for="label in conversationLabels"
            :key="label.title"
            class="inline-flex items-center text-[9px] font-semibold px-1.5 py-0.5 rounded-full text-white leading-none"
            :style="{ backgroundColor: label.color }"
          >
            {{ label.title }}
          </span>
        </div>

        <!-- Footer: assignee + badges -->
        <div
          class="flex items-center justify-between pt-1.5 border-t border-slate-100 dark:border-slate-700"
        >
          <div v-if="item.assignee" class="flex items-center gap-1.5 min-w-0">
            <img
              v-if="item.assignee.avatar_url"
              :src="item.assignee.avatar_url"
              :alt="item.assignee.name"
              class="size-4 rounded-full object-cover shrink-0"
            />
            <span
              v-else
              class="size-4 rounded-full bg-woot-100 dark:bg-woot-800 flex items-center justify-center text-[9px] font-bold text-woot-600 dark:text-woot-300 shrink-0"
            >
              {{ item.assignee.name?.[0]?.toUpperCase() }}
            </span>
            <span
              class="text-[10px] text-slate-400 dark:text-slate-500 truncate"
              >{{ item.assignee.name }}</span
            >
          </div>
          <span v-else class="flex-1" />

          <div class="flex items-center gap-1.5 shrink-0">
            <span
              v-if="hasTasks"
              class="flex items-center gap-0.5 text-[10px] font-medium"
              :class="
                item.pending_tasks_count > 0
                  ? 'text-amber-600'
                  : 'text-slate-400'
              "
            >
              <span class="i-lucide-check-square size-3" />
              {{ item.pending_tasks_count }}/{{ item.tasks_count }}
            </span>
            <span
              v-if="hasAttachments"
              class="flex items-center gap-0.5 text-[10px] text-slate-400"
            >
              <span class="i-lucide-paperclip size-3" />
              {{ item.attachments_count }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
