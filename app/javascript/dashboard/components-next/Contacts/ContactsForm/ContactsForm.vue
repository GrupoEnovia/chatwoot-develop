<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { splitName } from '@chatwoot/utils';
import countries from 'shared/constants/countries.js';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PhoneNumberInput from 'dashboard/components-next/phonenumberinput/PhoneNumberInput.vue';

const props = defineProps({
  contactData: {
    type: Object,
    default: null,
  },
  isDetailsView: {
    type: Boolean,
    default: false,
  },
  isNewContact: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update']);

const { t } = useI18n();

const FORM_CONFIG = {
  FIRST_NAME: { field: 'firstName' },
  LAST_NAME: { field: 'lastName' },
  EMAIL_ADDRESS: { field: 'email' },
  PHONE_NUMBER: { field: 'phoneNumber' },
  COUNTRY: { field: 'additionalAttributes.countryCode' },
  BIO: { field: 'additionalAttributes.description' },
  COMPANY_NAME: { field: 'additionalAttributes.companyName' },
};

const PERSONAL_CONFIG = {
  CPF: { field: 'additionalAttributes.cpf' },
  BIRTHDATE: { field: 'additionalAttributes.birthdate', type: 'date' },
  GENDER: { field: 'additionalAttributes.gender', type: 'select' },
};

const ADDRESS_CONFIG = {
  ZIP_CODE: { field: 'additionalAttributes.zipCode' },
  STREET: { field: 'additionalAttributes.street' },
  STREET_NUMBER: { field: 'additionalAttributes.streetNumber' },
  ADDRESS_COMPLEMENT: { field: 'additionalAttributes.addressComplement' },
  NEIGHBORHOOD: { field: 'additionalAttributes.neighborhood' },
  CITY: { field: 'additionalAttributes.city' },
  STATE: { field: 'additionalAttributes.state' },
};

const GENDER_OPTIONS = [
  { value: 'male', label: 'Masculino' },
  { value: 'female', label: 'Feminino' },
  { value: 'other', label: 'Outro' },
];

const SOCIAL_CONFIG = {
  LINKEDIN: 'i-ri-linkedin-box-fill',
  FACEBOOK: 'i-ri-facebook-circle-fill',
  INSTAGRAM: 'i-ri-instagram-line',
  TELEGRAM: 'i-ri-telegram-fill',
  TIKTOK: 'i-ri-tiktok-fill',
  TWITTER: 'i-ri-twitter-x-fill',
  GITHUB: 'i-ri-github-fill',
};

const defaultState = {
  id: 0,
  name: '',
  email: '',
  firstName: '',
  lastName: '',
  phoneNumber: '',
  additionalAttributes: {
    description: '',
    companyName: '',
    countryCode: '',
    country: '',
    city: '',
    cpf: '',
    birthdate: '',
    gender: '',
    zipCode: '',
    street: '',
    streetNumber: '',
    addressComplement: '',
    neighborhood: '',
    state: '',
    socialProfiles: {
      facebook: '',
      github: '',
      instagram: '',
      telegram: '',
      tiktok: '',
      linkedin: '',
      twitter: '',
    },
  },
};

const state = reactive({ ...defaultState });

const validationRules = {
  firstName: { required },
  email: { email },
};

const v$ = useVuelidate(validationRules, state);

const isFormInvalid = computed(() => v$.value.$invalid);

const prepareStateBasedOnProps = () => {
  if (props.isNewContact) {
    return; // Added to prevent state update for new contact form
  }

  const {
    id,
    name = '',
    email: emailAddress,
    phoneNumber,
    additionalAttributes = {},
  } = props.contactData || {};
  const { firstName, lastName } = splitName(name || '');
  const {
    description = '',
    companyName = '',
    countryCode = '',
    country = '',
    city = '',
    cpf = '',
    birthdate = '',
    gender = '',
    zipCode = '',
    street = '',
    streetNumber = '',
    addressComplement = '',
    neighborhood = '',
    state: stateField = '',
    socialTelegramUserName = '',
    socialProfiles = {},
  } = additionalAttributes || {};

  const telegramUsername =
    socialProfiles?.telegram || socialTelegramUserName || '';

  Object.assign(state, {
    id,
    name,
    firstName,
    lastName,
    email: emailAddress,
    phoneNumber,
    additionalAttributes: {
      description,
      companyName,
      countryCode,
      country,
      city,
      cpf,
      birthdate,
      gender,
      zipCode,
      street,
      streetNumber,
      addressComplement,
      neighborhood,
      state: stateField,
      socialProfiles: {
        ...socialProfiles,
        telegram: telegramUsername,
      },
    },
  });
};

const countryOptions = computed(() =>
  countries.map(({ name, id }) => ({ label: name, value: id }))
);

const editDetailsForm = computed(() =>
  Object.keys(FORM_CONFIG).map(key => ({
    key,
    placeholder: t(
      `CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.${key}.PLACEHOLDER`
    ),
  }))
);

const personalDataForm = computed(() =>
  Object.keys(PERSONAL_CONFIG).map(key => ({
    key,
    placeholder: t(
      `CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.${key}.PLACEHOLDER`
    ),
    type: PERSONAL_CONFIG[key].type,
  }))
);

const addressForm = computed(() =>
  Object.keys(ADDRESS_CONFIG).map(key => ({
    key,
    placeholder: t(
      `CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.${key}.PLACEHOLDER`
    ),
  }))
);

const socialProfilesForm = computed(() =>
  Object.entries(SOCIAL_CONFIG).map(([key, icon]) => ({
    key,
    placeholder: t(`CONTACTS_LAYOUT.CARD.SOCIAL_MEDIA.FORM.${key}.PLACEHOLDER`),
    icon,
  }))
);

const isValidationField = key => {
  const field = FORM_CONFIG[key]?.field;
  return ['firstName', 'email'].includes(field);
};

const getValidationKey = key => {
  return FORM_CONFIG[key]?.field;
};

// Creates a computed property for two-way form field binding
const getFormBinding = key => {
  const field =
    FORM_CONFIG[key]?.field ||
    PERSONAL_CONFIG[key]?.field ||
    ADDRESS_CONFIG[key]?.field;
  if (!field) return null;

  return computed({
    get: () => {
      // Handle firstName/lastName fields
      if (field === 'firstName' || field === 'lastName') {
        return state[field]?.toString() || '';
      }

      // Handle nested vs non-nested fields
      const [base, nested] = field.split('.');
      // Example: 'email' → state.email
      // Example: 'additionalAttributes.city' → state.additionalAttributes.city
      return (nested ? state[base][nested] : state[base])?.toString() || '';
    },

    set: async value => {
      // Handle name fields specially to maintain the combined 'name' field
      if (field === 'firstName' || field === 'lastName') {
        state[field] = value;
        // Example: firstName="John", lastName="Doe" → name="John Doe"
        state.name = `${state.firstName} ${state.lastName}`.trim();
      } else {
        // Handle nested vs non-nested fields
        const [base, nested] = field.split('.');
        if (nested) {
          // Example: additionalAttributes.city = "New York"
          state[base][nested] = value;
        } else {
          // Example: email = "test@example.com"
          state[base] = value;
        }
      }

      const isFormValid = await v$.value.$validate();
      if (isFormValid) {
        const { firstName, lastName, ...stateWithoutNames } = state;
        emit('update', stateWithoutNames);
      }
    },
  });
};

const getMessageType = key => {
  return isValidationField(key) && v$.value[getValidationKey(key)]?.$error
    ? 'error'
    : 'info';
};

const handleCountrySelection = value => {
  const selectedCountry = countries.find(option => option.id === value);
  state.additionalAttributes.country = selectedCountry?.name || '';
  emit('update', state);
};

const resetValidation = () => {
  v$.value.$reset();
};

const resetForm = () => {
  Object.assign(state, defaultState);
};

const cepLoading = ref(false);

const lookupCep = async () => {
  const clean = (state.additionalAttributes.zipCode || '').replace(/\D/g, '');
  if (clean.length !== 8) return;
  cepLoading.value = true;
  try {
    const res = await fetch(`https://viacep.com.br/ws/${clean}/json/`);
    const json = await res.json();
    if (!json.erro) {
      state.additionalAttributes.street =
        json.logradouro || state.additionalAttributes.street;
      state.additionalAttributes.neighborhood =
        json.bairro || state.additionalAttributes.neighborhood;
      state.additionalAttributes.city =
        json.localidade || state.additionalAttributes.city;
      state.additionalAttributes.state =
        json.uf || state.additionalAttributes.state;
      emit('update', state);
    }
  } catch (e) {
    // ignore lookup errors
  } finally {
    cepLoading.value = false;
  }
};

watch(
  () => props.contactData?.id,
  id => {
    if (id) prepareStateBasedOnProps();
  },
  { immediate: true }
);

// Expose state to parent component for avatar upload
defineExpose({
  state,
  resetValidation,
  isFormInvalid,
  resetForm,
});
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="flex flex-col items-start gap-2">
      <span class="py-1 text-sm font-medium text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.TITLE') }}
      </span>
      <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
        <template v-for="item in editDetailsForm" :key="item.key">
          <ComboBox
            v-if="item.key === 'COUNTRY'"
            v-model="state.additionalAttributes.countryCode"
            :options="countryOptions"
            :placeholder="item.placeholder"
            class="[&>div>button]:h-8"
            :class="{
              '[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:!outline-transparent':
                !isDetailsView,
              '[&>div>button]:!bg-n-alpha-black2': isDetailsView,
            }"
            @update:model-value="handleCountrySelection"
          />
          <PhoneNumberInput
            v-else-if="item.key === 'PHONE_NUMBER'"
            v-model="getFormBinding(item.key).value"
            :placeholder="item.placeholder"
            :show-border="isDetailsView"
          />
          <Input
            v-else
            v-model="getFormBinding(item.key).value"
            :placeholder="item.placeholder"
            :message-type="getMessageType(item.key)"
            :custom-input-class="`h-8 !pt-1 !pb-1 ${
              !isDetailsView
                ? '[&:not(.error,.focus)]:!outline-transparent'
                : ''
            }`"
            class="w-full"
            @input="
              isValidationField(item.key) &&
                v$[getValidationKey(item.key)].$touch()
            "
            @blur="
              isValidationField(item.key) &&
                v$[getValidationKey(item.key)].$touch()
            "
          />
        </template>
      </div>
    </div>
    <!-- Dados Pessoais Extras -->
    <div class="flex flex-col items-start gap-2">
      <span class="py-1 text-sm font-medium text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PERSONAL_DATA_TITLE') }}
      </span>
      <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
        <template v-for="item in personalDataForm" :key="item.key">
          <select
            v-if="item.type === 'select'"
            v-model="state.additionalAttributes.gender"
            class="h-8 w-full rounded-lg border border-n-weak bg-n-alpha-2 px-2.5 text-sm text-n-slate-12 outline-none focus:border-woot-500 dark:bg-n-solid-3"
            @change="emit('update', state)"
          >
            <option value="">{{ item.placeholder }}</option>
            <option
              v-for="opt in GENDER_OPTIONS"
              :key="opt.value"
              :value="opt.value"
            >
              {{ opt.label }}
            </option>
          </select>
          <input
            v-else-if="item.type === 'date'"
            v-model="state.additionalAttributes.birthdate"
            type="date"
            class="h-8 w-full rounded-lg border border-n-weak bg-n-alpha-2 px-2.5 text-sm text-n-slate-12 outline-none focus:border-woot-500 dark:bg-n-solid-3"
            @change="emit('update', state)"
          />
          <Input
            v-else
            v-model="getFormBinding(item.key).value"
            :placeholder="item.placeholder"
            :custom-input-class="`h-8 !pt-1 !pb-1 ${
              !isDetailsView
                ? '[&:not(.error,.focus)]:!outline-transparent'
                : ''
            }`"
            class="w-full"
            @input="emit('update', state)"
          />
        </template>
      </div>
    </div>

    <!-- Endereço -->
    <div class="flex flex-col items-start gap-2">
      <span class="py-1 text-sm font-medium text-n-slate-12">{{
        t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TITLE')
      }}</span>
      <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
        <template v-for="item in addressForm" :key="item.key">
          <div v-if="item.key === 'ZIP_CODE'" class="relative w-full">
            <Input
              v-model="getFormBinding(item.key).value"
              :placeholder="item.placeholder"
              :custom-input-class="`h-8 !pt-1 !pb-1 ${
                !isDetailsView
                  ? '[&:not(.error,.focus)]:!outline-transparent'
                  : ''
              }`"
              class="w-full"
              @input="emit('update', state)"
              @blur="lookupCep"
            />
            <span
              v-if="cepLoading"
              class="absolute right-2.5 top-1/2 -translate-y-1/2 i-lucide-loader-circle size-3.5 animate-spin text-woot-500"
            />
          </div>
          <Input
            v-else
            v-model="getFormBinding(item.key).value"
            :placeholder="item.placeholder"
            :custom-input-class="`h-8 !pt-1 !pb-1 ${
              !isDetailsView
                ? '[&:not(.error,.focus)]:!outline-transparent'
                : ''
            }`"
            class="w-full"
            @input="emit('update', state)"
          />
        </template>
      </div>
    </div>

    <div class="flex flex-col items-start gap-2">
      <span class="py-1 text-sm font-medium text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.CARD.SOCIAL_MEDIA.TITLE') }}
      </span>
      <div class="flex flex-wrap gap-2">
        <div
          v-for="item in socialProfilesForm"
          :key="item.key"
          class="flex items-center h-8 gap-2 px-2 rounded-lg"
          :class="{
            'bg-n-alpha-2 dark:bg-n-solid-2': isDetailsView,
            'bg-n-alpha-2 dark:bg-n-solid-3': !isDetailsView,
          }"
        >
          <Icon
            :icon="item.icon"
            class="flex-shrink-0 text-n-slate-11 size-4"
          />
          <input
            v-model="
              state.additionalAttributes.socialProfiles[item.key.toLowerCase()]
            "
            class="w-auto min-w-[100px] text-sm bg-transparent outline-none reset-base text-n-slate-12 dark:text-n-slate-12 placeholder:text-n-slate-10 dark:placeholder:text-n-slate-10"
            :placeholder="item.placeholder"
            :size="item.placeholder.length"
            @input="emit('update', state)"
          />
        </div>
      </div>
    </div>
  </div>
</template>
