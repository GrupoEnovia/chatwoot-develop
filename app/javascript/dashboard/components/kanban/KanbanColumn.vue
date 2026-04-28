<script setup>
import { computed, ref, watch } from 'vue';
import { useStore } from 'vuex';
import draggable from 'vuedraggable';
import KanbanCard from './KanbanCard.vue';

const props = defineProps({
  stage: { type: Object, required: true },
  pipelineId: { type: Number, required: true },
});

const emit = defineEmits([
  'card-click',
  'add-card',
  'pendingLost',
  'pendingWon',
]);
const store = useStore();

// ── Local items ref (required — vuedraggable can't mutate Vuex computed) ──
const storeItems = computed(() =>
  store.getters['kanban/getItemsByStage'](props.stage.id)
);
const items = ref([]);

// isDragging guards the SOURCE column's watch during an active drag so that
// websocket / background updates don't disrupt the card while it's in flight.
// It must NOT be set on the destination column — vuedraggable fires @end on
// both source and destination, which would race and prematurely unlock the guard.
const isDragging = ref(false);

watch(
  storeItems,
  val => {
    if (!isDragging.value) {
      items.value = val.map(i => ({ ...i }));
    }
  },
  { immediate: true }
);

const totalValue = computed(() => {
  const sum = storeItems.value.reduce(
    (acc, item) => acc + (parseFloat(item.value) || 0),
    0
  );
  if (sum === 0) return null;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  }).format(sum);
});

// ── Stage type badges ─────────────────────────────────────────────────
const stageLabel = computed(() => {
  if (props.stage.is_won)
    return {
      text: 'Ganho',
      cls: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
    };
  if (props.stage.is_lost)
    return {
      text: 'Perdido',
      cls: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
    };
  return null;
});

// ── Drag event handlers ───────────────────────────────────────────────
// @start fires only on the SOURCE column — lock it so background updates
// don't reorder cards while the user is dragging.
function onDragStart() {
  isDragging.value = true;
}

// @end fires on source (and sometimes destination in SortableJS).
// On the source this correctly unlocks. On the destination isDragging is
// already false so this is a no-op.
function onDragEnd() {
  isDragging.value = false;
}

// @change fires on the destination column with event.added when a card is
// dropped here from another column.
// DO NOT set isDragging = true here: the store optimistic update runs
// synchronously inside moveItem, so storeItems already reflects the new
// position by the time the watcher fires (next microtask). The watcher
// running freely is correct and desired.
function onChange(event) {
  if (!event.added) return;
  const { element, newIndex } = event.added;

  if (props.stage.is_lost) {
    emit('pendingLost', { item: element, stageId: props.stage.id, newIndex });
    return;
  }

  if (props.stage.is_won) {
    emit('pendingWon', { item: element, stageId: props.stage.id, newIndex });
    return;
  }

  store
    .dispatch('kanban/moveItem', {
      pipelineId: props.pipelineId,
      id: element.id,
      stageId: props.stage.id,
      position: newIndex,
    })
    .catch(() => {});
}
</script>

<template>
  <div
    class="flex flex-col w-64 shrink-0 rounded-xl border border-slate-200 dark:border-slate-700 h-full"
    :class="
      stage.is_won
        ? 'bg-green-50 dark:bg-green-950/20 border-green-200 dark:border-green-800'
        : stage.is_lost
          ? 'bg-red-50 dark:bg-red-950/20 border-red-200 dark:border-red-800'
          : 'bg-slate-50 dark:bg-slate-900'
    "
  >
    <!-- Column header -->
    <div
      class="flex items-center justify-between px-3 py-2.5 border-b border-slate-200 dark:border-slate-700 shrink-0"
      :style="{
        borderTopColor: stage.color,
        borderTopWidth: '3px',
        borderTopStyle: 'solid',
      }"
    >
      <div class="flex items-center gap-2 min-w-0">
        <span
          class="size-2 rounded-full shrink-0"
          :style="{ backgroundColor: stage.color }"
        />
        <h3
          class="text-sm font-semibold text-slate-700 dark:text-slate-200 truncate"
        >
          {{ stage.name }}
        </h3>
        <span
          class="shrink-0 text-xs font-medium bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-300 rounded-full px-1.5 py-0.5 leading-none"
        >
          {{ items.length }}
        </span>
        <span
          v-if="stageLabel"
          class="text-[9px] font-semibold px-1.5 py-0.5 rounded-full"
          :class="stageLabel.cls"
        >
          {{ stageLabel.text }}
        </span>
      </div>
      <button
        class="shrink-0 text-slate-400 hover:text-woot-500 transition-colors"
        title="Adicionar card"
        @click="emit('add-card', stage)"
      >
        <span class="i-lucide-plus size-4" />
      </button>
    </div>

    <!-- Value summary -->
    <div
      v-if="totalValue"
      class="flex items-center justify-between px-3 py-1.5 border-b border-slate-100 dark:border-slate-800 shrink-0"
    >
      <span class="text-xs font-semibold text-woot-600 dark:text-woot-400">{{
        totalValue
      }}</span>
      <span v-if="stage.probability > 0" class="text-[10px] text-slate-400"
        >{{ stage.probability }}%</span
      >
    </div>

    <!-- Drop zone hint (is_won / is_lost) -->
    <div
      v-if="(stage.is_won || stage.is_lost) && items.length === 0"
      class="mx-2 mt-2 py-3 rounded-lg border-2 border-dashed text-center text-[10px] shrink-0"
      :class="
        stage.is_won
          ? 'border-green-300 dark:border-green-700 text-green-500 dark:text-green-600'
          : 'border-red-300 dark:border-red-700 text-red-400 dark:text-red-600'
      "
    >
      {{
        stage.is_won
          ? '🏆 Arraste aqui para marcar como Ganho'
          : '❌ Arraste aqui para marcar como Perdido'
      }}
    </div>

    <!-- Cards list (Sortable) -->
    <draggable
      v-model="items"
      item-key="id"
      group="kanban"
      :animation="200"
      :force-fallback="false"
      ghost-class="opacity-40"
      class="flex-1 overflow-y-auto p-2 space-y-2"
      :class="items.length === 0 ? 'min-h-[80px]' : ''"
      @start="onDragStart"
      @end="onDragEnd"
      @change="onChange"
    >
      <template #item="{ element }">
        <div class="select-none">
          <KanbanCard
            :item="element"
            :stage-color="stage.color"
            @click="emit('card-click', element)"
          />
        </div>
      </template>

      <!-- Empty drop target -->
      <template #footer>
        <div
          v-if="items.length === 0"
          class="min-h-[60px] rounded-lg border-2 border-dashed border-slate-200 dark:border-slate-700 flex items-center justify-center"
        >
          <p class="text-[10px] text-slate-300 dark:text-slate-600">
            Soltar aqui
          </p>
        </div>
      </template>
    </draggable>
  </div>
</template>
