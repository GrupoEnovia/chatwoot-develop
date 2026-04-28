<!-- eslint-disable vue/no-bare-strings-in-template, prettier/prettier -->
<script setup>
defineProps({
  action: { type: Object, required: true },
  position: { type: Number, default: 0 },
});

const emit = defineEmits(['edit', 'delete', 'toggle-active']);

const TYPE_CONFIG = {
  send_whatsapp: {
    label: 'WhatsApp',
    icon: 'i-lucide-message-circle',
    color: '#10b981',
    bg: 'bg-emerald-50 dark:bg-emerald-900/20',
    text: 'text-emerald-600 dark:text-emerald-400',
    border: '#10b981',
  },
  send_webhook: {
    label: 'Webhook',
    icon: 'i-lucide-webhook',
    color: '#3b82f6',
    bg: 'bg-blue-50 dark:bg-blue-900/20',
    text: 'text-blue-600 dark:text-blue-400',
    border: '#3b82f6',
  },
  create_task: {
    label: 'Criar Tarefa',
    icon: 'i-lucide-check-square',
    color: '#8b5cf6',
    bg: 'bg-violet-50 dark:bg-violet-900/20',
    text: 'text-violet-600 dark:text-violet-400',
    border: '#8b5cf6',
  },
  crm_action: {
    label: 'Ação CRM',
    icon: 'i-lucide-git-branch',
    color: '#f59e0b',
    bg: 'bg-amber-50 dark:bg-amber-900/20',
    text: 'text-amber-600 dark:text-amber-400',
    border: '#f59e0b',
  },
};

const DELAY_LABELS = {
  minutes: 'min',
  hours: 'h',
  days: 'd',
  business_days: 'd úteis',
};

function typeConfig(type) {
  return TYPE_CONFIG[type] || TYPE_CONFIG.send_whatsapp;
}

function delayLabel(action) {
  if (!action.delay_minutes) return 'Imediato';
  const unit = DELAY_LABELS[action.delay_type] || action.delay_type;
  return `+${action.delay_minutes} ${unit}`;
}

function contentPreview(action) {
  const cfg = action.config || {};
  if (action.action_type === 'send_whatsapp') {
    if (cfg.use_ai)
      return cfg.ai_prompt ? `IA: ${cfg.ai_prompt}` : 'Mensagem por IA';
    return cfg.message || '—';
  }
  if (action.action_type === 'send_webhook') return cfg.name || cfg.url || '—';
  if (action.action_type === 'create_task') return cfg.title || '—';
  if (action.action_type === 'crm_action') {
    const actCount = (cfg.crm_actions || []).length;
    const condCount = (cfg.conditions || []).length;
    return `${condCount} cond. → ${actCount} ação(ões)`;
  }
  return '—';
}
</script>

<template>
  <div
    class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 select-none hover:shadow-md transition-shadow duration-150 group/card"
    :style="{
      borderLeftColor: typeConfig(action.action_type).border,
      borderLeftWidth: '3px',
    }"
    :class="!action.active ? 'opacity-60' : ''"
  >
    <div class="px-2.5 pt-2.5 pb-2">
      <!-- Step number + delay -->
      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center gap-1.5">
          <span
            class="text-[10px] font-bold text-slate-400 bg-slate-100 dark:bg-slate-700 rounded-full w-4 h-4 flex items-center justify-center"
          >
            {{ position + 1 }}
          </span>
          <span
            class="text-[10px] font-semibold px-1.5 py-0.5 rounded"
            :class="
              typeConfig(action.action_type).bg +
              ' ' +
              typeConfig(action.action_type).text
            "
          >
            {{ delayLabel(action) }}
          </span>
        </div>
        <!-- Active toggle -->
        <button
          class="flex items-center gap-0.5 text-[10px] transition-colors"
          :class="
            action.active
              ? 'text-emerald-500'
              : 'text-slate-300 dark:text-slate-600'
          "
          @click.stop="emit('toggle-active', action)"
        >
          <span
            :class="
              action.active
                ? 'i-lucide-toggle-right size-4'
                : 'i-lucide-toggle-left size-4'
            "
          />
        </button>
      </div>

      <!-- Type label -->
      <div class="flex items-center gap-1.5 mb-1.5">
        <span
          class="size-3.5 shrink-0"
          :class="[
            typeConfig(action.action_type).icon,
            typeConfig(action.action_type).text,
          ]"
        />
        <span class="text-xs font-semibold text-slate-700 dark:text-slate-200">
          {{ typeConfig(action.action_type).label }}
        </span>
      </div>

      <!-- Content preview -->
      <p
        class="text-xs text-slate-400 dark:text-slate-500 line-clamp-2 leading-relaxed mb-2"
      >
        {{ contentPreview(action) }}
      </p>

      <!-- Footer: edit + delete -->
      <div
        class="flex items-center justify-end gap-1 pt-1.5 border-t border-slate-100 dark:border-slate-700 opacity-0 group-hover/card:opacity-100 transition-opacity"
      >
        <button
          class="p-1 rounded text-slate-400 hover:text-violet-500 dark:hover:text-violet-400 transition-colors"
          @click.stop="emit('edit', action)"
        >
          <span class="i-lucide-pencil size-3.5" />
        </button>
        <button
          class="p-1 rounded text-slate-400 hover:text-red-500 dark:hover:text-red-400 transition-colors"
          @click.stop="emit('delete', action)"
        >
          <span class="i-lucide-trash-2 size-3.5" />
        </button>
      </div>
    </div>
  </div>
</template>
