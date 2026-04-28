<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { gamificationAPI, goalsAPI, badgesAPI } from 'dashboard/api/kanban';

const rankings = ref([]);
const overview = ref(null);
const goals = ref([]);
const badgeDefs = ref([]);
const lastUpdated = ref('');
let interval = null;

const now = new Date();
const currentYear = now.getFullYear();
const currentMonth = now.getMonth() + 1;

const PERIOD_LABEL = computed(() => {
  const d = new Date();
  return d.toLocaleString('pt-BR', { month: 'long', year: 'numeric' });
});

// Podium display: [2nd, 1st, 3rd]
const podiumItems = computed(() => {
  const top = rankings.value.slice(0, 3);
  if (!top.length) return [];
  if (top.length === 1) return [null, top[0], null];
  if (top.length === 2) return [top[1], top[0], null];
  return [top[1], top[0], top[2]];
});
const PODIUM_RANKS = [1, 0, 2];

const goalsMap = computed(() => {
  const m = {};
  goals.value.forEach(g => {
    m[g.assignee_id] = g;
  });
  return m;
});

function evaluateBadge(badge, ranking, rankIdx) {
  const v = badge.condition_value;
  switch (badge.condition_type) {
    case 'won_gte':
      return ranking.stats.won >= v;
    case 'value_gte':
      return ranking.stats.value >= v;
    case 'conversion_rate_gte':
      return ranking.stats.conversion_rate >= v;
    case 'max_deal_gte':
      return ranking.stats.max_deal_value >= v;
    case 'goal_pct_gte': {
      const g = goalsMap.value[ranking.agent.id];
      if (!g || !g.target_value) return false;
      return Math.min(100, (ranking.stats.value / g.target_value) * 100) >= v;
    }
    case 'rank_eq':
      return rankIdx === v;
    default:
      return false;
  }
}

const agentBadges = computed(() => {
  const map = {};
  rankings.value.forEach((r, idx) => {
    map[r.agent.id] = badgeDefs.value.filter(
      b => b.active && evaluateBadge(b, r, idx)
    );
  });
  return map;
});

const teamTotalValue = computed(() =>
  rankings.value.reduce((s, r) => s + r.stats.value, 0)
);
const teamTotalWon = computed(() =>
  rankings.value.reduce((s, r) => s + r.stats.won, 0)
);

async function loadData() {
  try {
    const [rankRes, overRes, goalRes, badgeRes] = await Promise.allSettled([
      gamificationAPI.rankings({ period: 'month' }),
      gamificationAPI.overview({ period: 'month' }),
      goalsAPI.list(currentYear, currentMonth),
      badgesAPI.list(),
    ]);
    if (rankRes.status === 'fulfilled')
      rankings.value = rankRes.value.data?.payload || [];
    if (overRes.status === 'fulfilled')
      overview.value = overRes.value.data?.payload || null;
    if (goalRes.status === 'fulfilled')
      goals.value = goalRes.value.data?.payload || [];
    if (badgeRes.status === 'fulfilled')
      badgeDefs.value = badgeRes.value.data?.payload || [];
    lastUpdated.value = new Date().toLocaleTimeString('pt-BR');
  } catch {
    /* ignore */
  }
}

function fBRL(val) {
  if (!val) return '0';
  return new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 0 }).format(
    val
  );
}

function initials(name) {
  if (!name) return '?';
  return name
    .split(' ')
    .slice(0, 2)
    .map(w => w[0])
    .join('')
    .toUpperCase();
}

onMounted(() => {
  loadData();
  interval = setInterval(loadData, 30000);
});

onUnmounted(() => clearInterval(interval));
</script>

<template>
  <div
    class="fixed inset-0 flex flex-col overflow-hidden select-none"
    style="
      background: radial-gradient(
        ellipse at 50% 0%,
        #3b1068 0%,
        #1a0533 60%,
        #0f0220 100%
      );
    "
  >
    <!-- ── Header ─────────────────────────────────────────────────────────── -->
    <div class="shrink-0 pt-8 pb-4 text-center">
      <p class="text-4xl font-black text-amber-400 tracking-wide">
        🏆 Ranking de Gamificação
      </p>
      <p class="text-white/50 text-sm mt-1 capitalize">{{ PERIOD_LABEL }}</p>
    </div>

    <!-- ── Podium ─────────────────────────────────────────────────────────── -->
    <div
      v-if="podiumItems.length"
      class="shrink-0 flex items-end justify-center gap-8 px-8 pb-6"
    >
      <div
        v-for="(entry, dispIdx) in podiumItems"
        :key="dispIdx"
        class="flex flex-col items-center"
        :class="
          PODIUM_RANKS[dispIdx] === 0 ? 'flex-1 max-w-56' : 'flex-1 max-w-44'
        "
      >
        <template v-if="entry">
          <!-- spacer for non-gold -->
          <div v-if="PODIUM_RANKS[dispIdx] !== 0" class="h-8" />

          <!-- Avatar -->
          <div class="relative mb-3">
            <div
              class="rounded-full shadow-2xl"
              :class="[
                PODIUM_RANKS[dispIdx] === 0
                  ? 'size-28 ring-4'
                  : 'size-20 ring-[3px]',
                PODIUM_RANKS[dispIdx] === 0
                  ? 'ring-amber-300'
                  : PODIUM_RANKS[dispIdx] === 1
                    ? 'ring-slate-300'
                    : 'ring-orange-400',
              ]"
            >
              <img
                v-if="entry.agent.avatar_url"
                :src="entry.agent.avatar_url"
                class="rounded-full object-cover w-full h-full"
              />
              <div
                v-else
                class="rounded-full w-full h-full flex items-center justify-center font-black text-white"
                :class="[
                  PODIUM_RANKS[dispIdx] === 0
                    ? 'text-3xl bg-amber-500'
                    : PODIUM_RANKS[dispIdx] === 1
                      ? 'text-2xl bg-slate-500'
                      : 'text-2xl bg-orange-500',
                ]"
              >
                {{ initials(entry.agent.name) }}
              </div>
            </div>
            <!-- Rank badge -->
            <span
              class="absolute -top-1 -right-1 size-8 rounded-full flex items-center justify-center text-sm font-black border-2 border-purple-900 shadow-lg"
              :class="
                PODIUM_RANKS[dispIdx] === 0
                  ? 'bg-amber-400 text-amber-900'
                  : PODIUM_RANKS[dispIdx] === 1
                    ? 'bg-slate-400 text-white'
                    : 'bg-orange-500 text-white'
              "
              >{{ PODIUM_RANKS[dispIdx] + 1 }}</span
            >
          </div>

          <!-- Name -->
          <p
            class="font-black truncate text-center w-full"
            :class="
              PODIUM_RANKS[dispIdx] === 0
                ? 'text-amber-300 text-xl'
                : 'text-white text-base'
            "
          >
            {{ entry.agent.name.split(' ')[0] }}
          </p>

          <!-- Value -->
          <p
            class="font-black mt-0.5"
            :class="
              PODIUM_RANKS[dispIdx] === 0
                ? 'text-amber-400 text-2xl'
                : 'text-white/80 text-lg'
            "
          >
            {{ fBRL(entry.stats.value) }}
          </p>
          <p class="text-white/50 text-xs">
            {{ entry.stats.won }} negócio{{ entry.stats.won !== 1 ? 's' : '' }}
          </p>

          <!-- Badges -->
          <div
            v-if="agentBadges[entry.agent.id]?.length"
            class="flex gap-0.5 mt-1"
          >
            <span
              v-for="b in agentBadges[entry.agent.id].slice(0, 3)"
              :key="b.id"
              class="text-base"
              >{{ b.icon }}</span
            >
          </div>
        </template>
        <template v-else>
          <div class="h-8" />
          <div
            class="rounded-full bg-white/10 mb-3"
            :class="PODIUM_RANKS[dispIdx] === 0 ? 'size-28' : 'size-20'"
          />
          <p class="text-white/20 text-sm">—</p>
        </template>
      </div>
    </div>

    <!-- ── Ranking list ────────────────────────────────────────────────────── -->
    <div class="flex-1 overflow-y-auto px-8 pb-6">
      <div
        class="rounded-2xl overflow-hidden"
        style="
          background: rgba(255, 255, 255, 0.07);
          border: 1px solid rgba(255, 255, 255, 0.12);
        "
      >
        <div
          v-for="(entry, idx) in rankings"
          :key="entry.agent.id"
          class="flex items-center gap-4 px-6 py-3.5 border-b last:border-b-0"
          style="border-color: rgba(255, 255, 255, 0.06)"
          :class="idx === 0 ? 'bg-amber-400/10' : ''"
        >
          <!-- Position -->
          <span
            class="w-8 text-center font-black text-xl shrink-0"
            :class="
              idx === 0
                ? 'text-amber-400'
                : idx === 1
                  ? 'text-slate-300'
                  : idx === 2
                    ? 'text-orange-400'
                    : 'text-white/40'
            "
            >{{ idx + 1 }}</span
          >

          <!-- Avatar -->
          <img
            v-if="entry.agent.avatar_url"
            :src="entry.agent.avatar_url"
            class="size-10 rounded-full object-cover shrink-0"
            :class="idx === 0 ? 'ring-2 ring-amber-400' : ''"
          />
          <div
            v-else
            class="size-10 rounded-full bg-white/20 flex items-center justify-center text-white font-bold shrink-0"
          >
            {{ initials(entry.agent.name) }}
          </div>

          <!-- Name -->
          <p
            class="flex-1 font-semibold truncate"
            :class="
              idx === 0 ? 'text-amber-300 text-base' : 'text-white text-sm'
            "
          >
            {{ entry.agent.name }}
          </p>

          <!-- Badges -->
          <div class="flex gap-0.5 shrink-0">
            <span
              v-for="b in (agentBadges[entry.agent.id] || []).slice(0, 3)"
              :key="b.id"
              class="text-base"
              >{{ b.icon }}</span
            >
          </div>

          <!-- Stats -->
          <div class="text-right shrink-0 min-w-28">
            <p
              class="font-black"
              :class="
                idx === 0 ? 'text-amber-400 text-lg' : 'text-white/90 text-base'
              "
            >
              {{ fBRL(entry.stats.value) }}
            </p>
            <p class="text-white/40 text-xs">
              {{ entry.stats.won }} negócio{{
                entry.stats.won !== 1 ? 's' : ''
              }}
            </p>
          </div>
        </div>

        <div v-if="!rankings.length" class="py-12 text-center text-white/30">
          Nenhum dado disponível
        </div>
      </div>
    </div>

    <!-- ── KPI footer ─────────────────────────────────────────────────────── -->
    <div
      class="shrink-0 px-8 pb-8 grid grid-cols-2 gap-4 max-w-xl mx-auto w-full"
    >
      <div
        class="rounded-2xl p-4 text-center"
        style="
          background: rgba(255, 255, 255, 0.07);
          border: 1px solid rgba(255, 255, 255, 0.12);
        "
      >
        <p class="text-3xl font-black text-green-400">
          {{ fBRL(teamTotalValue) }}
        </p>
        <p class="text-white/50 text-xs mt-1 uppercase tracking-wide">
          Valor Total
        </p>
      </div>
      <div
        class="rounded-2xl p-4 text-center"
        style="
          background: rgba(255, 255, 255, 0.07);
          border: 1px solid rgba(255, 255, 255, 0.12);
        "
      >
        <p class="text-3xl font-black text-amber-400">{{ teamTotalWon }}</p>
        <p class="text-white/50 text-xs mt-1 uppercase tracking-wide">
          Negócios Totais
        </p>
      </div>
    </div>

    <!-- Live indicator + last updated -->
    <div
      class="shrink-0 text-center pb-4 flex items-center justify-center gap-2"
    >
      <span class="size-1.5 rounded-full bg-green-400 animate-pulse" />
      <span class="text-white/30 text-xs"
        >Ao vivo · atualiza a cada 30s · {{ lastUpdated }}</span
      >
    </div>
  </div>
</template>
