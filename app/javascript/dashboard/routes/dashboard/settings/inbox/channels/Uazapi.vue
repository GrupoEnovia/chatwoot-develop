<!-- eslint-disable vue/no-bare-strings-in-template, prettier/prettier -->
<script setup>
import { ref, computed, onBeforeUnmount } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const store    = useStore();
const router   = useRouter();
const { accountId } = useAccount();

const instanceName = ref('');
const phoneNumber  = ref('');
const creating     = ref(false);
const inboxId      = ref(null);
const qrCode       = ref(null);
const qrLoading    = ref(false);
const connected    = ref(false);
let pollInterval   = null;

const uiFlags = computed(() => store.getters['inboxes/getUIFlags']);

async function fetchQr() {
  try {
    const { data } = await window.axios.get(
      `/api/v1/accounts/${accountId.value}/inboxes/${inboxId.value}/uazapi_qr`
    );
    return data;
  } catch {
    return null;
  }
}

function stopPolling() {
  if (pollInterval) {
    clearInterval(pollInterval);
    pollInterval = null;
  }
}

async function checkConnection() {
  try {
    const { data } = await window.axios.get(
      `/api/v1/accounts/${accountId.value}/inboxes/${inboxId.value}/uazapi_status`
    );
    if (data?.connection_status === 'connected') {
      connected.value = true;
      stopPolling();
    } else {
      const qrData = await fetchQr();
      if (qrData?.base64) {
        qrCode.value = qrData.base64;
      }
    }
  } catch {
    // ignore
  }
}

function startPolling() {
  pollInterval = setInterval(checkConnection, 8000);
}

async function loadQrCode() {
  qrLoading.value = true;
  try {
    const qrData = await fetchQr();
    if (qrData?.base64) {
      qrCode.value = qrData.base64;
    }
  } finally {
    qrLoading.value = false;
  }
}

async function createChannel() {
  if (!instanceName.value.trim()) {
    useAlert('Nome da instância é obrigatório');
    return;
  }
  creating.value = true;
  try {
    const inbox = await store.dispatch('inboxes/createChannel', {
      name: instanceName.value,
      channel: {
        type: 'uazapi',
        uazapi_instance_name: instanceName.value.trim(),
        phone_number: phoneNumber.value.trim() || undefined,
      },
    });
    inboxId.value = inbox.id;
    await loadQrCode();
    startPolling();
  } catch (err) {
    useAlert(err.message || 'Erro ao criar instância UAZAPI');
  } finally {
    creating.value = false;
  }
}

function goToAgents() {
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: { page: 'new', inbox_id: inboxId.value },
  });
}

onBeforeUnmount(() => stopPolling());
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      header-title="WhatsApp UAZAPI"
      header-content="Conecte uma linha WhatsApp não oficial via UAZAPI. Escaneie o QR code com o celular para ativar."
    />

    <!-- Step 1: Create instance -->
    <div v-if="!inboxId">
      <form
        class="flex flex-wrap flex-col mx-0"
        @submit.prevent="createChannel"
      >
        <div class="flex-shrink-0 flex-grow-0 mb-4">
          <label>
            Nome da instância
            <input
              v-model="instanceName"
              type="text"
              placeholder="ex: empresa-suporte"
              required
            />
          </label>
          <p class="help-text">
            Identificador único para esta instância UAZAPI.
          </p>
        </div>

        <div class="flex-shrink-0 flex-grow-0 mb-4">
          <label>
            Número de telefone (opcional)
            <input
              v-model="phoneNumber"
              type="text"
              placeholder="55119999999999"
            />
          </label>
          <p class="help-text">Número do WhatsApp que será conectado.</p>
        </div>

        <div class="w-full mt-4">
          <NextButton
            :is-loading="uiFlags.isCreating || creating"
            type="submit"
            solid
            blue
            label="Criar e conectar"
          />
        </div>
      </form>
    </div>

    <!-- Step 2: QR Code / connected -->
    <div v-else class="mt-6 flex flex-col items-center gap-6">
      <div v-if="connected" class="flex flex-col items-center gap-4">
        <span class="i-lucide-check-circle size-16 text-emerald-500" />
        <p class="text-base font-semibold text-emerald-600">
          WhatsApp conectado com sucesso!
        </p>
        <NextButton solid blue label="Adicionar agentes" @click="goToAgents" />
      </div>

      <div v-else class="flex flex-col items-center gap-4">
        <p class="text-sm text-slate-600 dark:text-slate-300">
          Escaneie o QR code com o WhatsApp para conectar.
        </p>
        <div
          v-if="qrLoading"
          class="size-48 flex items-center justify-center bg-slate-100 dark:bg-slate-800 rounded-lg"
        >
          <span
            class="i-lucide-loader-circle animate-spin size-8 text-slate-400"
          />
        </div>
        <img
          v-else-if="qrCode"
          :src="qrCode"
          alt="QR Code WhatsApp"
          class="size-48 rounded-lg border border-slate-200"
        />
        <div
          v-else
          class="size-48 flex items-center justify-center bg-slate-100 dark:bg-slate-800 rounded-lg text-slate-400 text-xs text-center px-4"
        >
          QR code não disponível ainda. Aguarde alguns segundos.
        </div>
        <p class="text-[11px] text-slate-400">
          Atualizando a cada 8 segundos...
        </p>
      </div>
    </div>
  </div>
</template>
