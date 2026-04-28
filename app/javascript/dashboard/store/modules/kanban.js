import {
  pipelinesAPI,
  stagesAPI,
  itemsAPI,
  tasksAPI,
  notesAPI,
  activitiesAPI,
  attachmentsAPI,
  globalItemsAPI,
  lostReasonsAPI,
} from '../../api/kanban';

const state = {
  pipelines: [],
  stages: [],
  items: [],
  conversationItems: [],
  lostReasons: [],
  pipelineStagesCache: {},
  // Per-item subresources (keyed by item id)
  tasks: {},
  notes: {},
  activities: {},
  attachments: {},
  uiFlags: {
    isFetchingPipelines: false,
    isFetchingStages: false,
    isFetchingItems: false,
    isFetchingSubresource: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
  activePipelineId: null,
  filters: {},
};

const getters = {
  getPipelines: $s => $s.pipelines,
  getActivePipeline: $s =>
    $s.pipelines.find(p => p.id === $s.activePipelineId) || null,
  getActivePipelineId: $s => $s.activePipelineId,
  getStages: $s => $s.stages,
  getItems: $s => $s.items,
  getItemsByStage: $s => stageId =>
    $s.items.filter(i => i.stage_id === stageId),
  getUIFlags: $s => $s.uiFlags,
  getFilters: $s => $s.filters,
  getTasksForItem: $s => itemId => $s.tasks[itemId] || [],
  getNotesForItem: $s => itemId => $s.notes[itemId] || [],
  getActivitiesForItem: $s => itemId => $s.activities[itemId] || [],
  getAttachmentsForItem: $s => itemId => $s.attachments[itemId] || [],
  getConversationItems: $s => $s.conversationItems,
  getLostReasons: $s => $s.lostReasons,
  getPipelineStagesCache: $s => pipelineId =>
    $s.pipelineStagesCache[pipelineId] || [],
};

const mutations = {
  SET_UI_FLAG($s, f) {
    $s.uiFlags = { ...$s.uiFlags, ...f };
  },
  SET_PIPELINES($s, v) {
    $s.pipelines = v;
  },
  SET_ACTIVE_PIPELINE($s, id) {
    $s.activePipelineId = id;
  },
  ADD_PIPELINE($s, v) {
    $s.pipelines.push(v);
  },
  UPDATE_PIPELINE($s, v) {
    const i = $s.pipelines.findIndex(p => p.id === v.id);
    if (i !== -1) $s.pipelines.splice(i, 1, v);
  },
  DELETE_PIPELINE($s, id) {
    $s.pipelines = $s.pipelines.filter(p => p.id !== id);
  },
  SET_STAGES($s, v) {
    $s.stages = v;
  },
  ADD_STAGE($s, v) {
    $s.stages.push(v);
  },
  UPDATE_STAGE($s, v) {
    const i = $s.stages.findIndex(s => s.id === v.id);
    if (i !== -1) $s.stages.splice(i, 1, v);
  },
  DELETE_STAGE($s, id) {
    $s.stages = $s.stages.filter(s => s.id !== id);
  },
  SET_ITEMS($s, v) {
    $s.items = v;
  },
  ADD_ITEM($s, v) {
    $s.items.push(v);
  },
  UPDATE_ITEM($s, v) {
    const i = $s.items.findIndex(x => x.id === v.id);
    if (i !== -1) $s.items.splice(i, 1, v);
  },
  DELETE_ITEM($s, id) {
    $s.items = $s.items.filter(x => x.id !== id);
  },
  MOVE_ITEM_OPTIMISTIC($s, { itemId, stageId }) {
    const i = $s.items.findIndex(x => x.id === itemId);
    if (i !== -1) $s.items[i] = { ...$s.items[i], stage_id: stageId };
  },
  SET_FILTERS($s, f) {
    $s.filters = { ...$s.filters, ...f };
  },
  CLEAR_FILTERS($s) {
    $s.filters = {};
  },
  SET_ITEM_TASKS($s, { itemId, tasks }) {
    $s.tasks = { ...$s.tasks, [itemId]: tasks };
  },
  ADD_ITEM_TASK($s, { itemId, task }) {
    $s.tasks = { ...$s.tasks, [itemId]: [...($s.tasks[itemId] || []), task] };
  },
  UPDATE_ITEM_TASK($s, { itemId, task }) {
    const list = ($s.tasks[itemId] || []).map(t =>
      t.id === task.id ? task : t
    );
    $s.tasks = { ...$s.tasks, [itemId]: list };
  },
  DELETE_ITEM_TASK($s, { itemId, taskId }) {
    $s.tasks = {
      ...$s.tasks,
      [itemId]: ($s.tasks[itemId] || []).filter(t => t.id !== taskId),
    };
  },
  SET_ITEM_NOTES($s, { itemId, notes }) {
    $s.notes = { ...$s.notes, [itemId]: notes };
  },
  ADD_ITEM_NOTE($s, { itemId, note }) {
    $s.notes = { ...$s.notes, [itemId]: [note, ...($s.notes[itemId] || [])] };
  },
  DELETE_ITEM_NOTE($s, { itemId, noteId }) {
    $s.notes = {
      ...$s.notes,
      [itemId]: ($s.notes[itemId] || []).filter(n => n.id !== noteId),
    };
  },
  SET_ITEM_ACTIVITIES($s, { itemId, activities }) {
    $s.activities = { ...$s.activities, [itemId]: activities };
  },
  SET_ITEM_ATTACHMENTS($s, { itemId, attachments }) {
    $s.attachments = { ...$s.attachments, [itemId]: attachments };
  },
  ADD_ITEM_ATTACHMENT($s, { itemId, attachment }) {
    $s.attachments = {
      ...$s.attachments,
      [itemId]: [attachment, ...($s.attachments[itemId] || [])],
    };
  },
  DELETE_ITEM_ATTACHMENT($s, { itemId, attachmentId }) {
    $s.attachments = {
      ...$s.attachments,
      [itemId]: ($s.attachments[itemId] || []).filter(
        a => a.id !== attachmentId
      ),
    };
  },
  SET_CONVERSATION_ITEMS($s, v) {
    $s.conversationItems = v;
  },
  UPDATE_CONVERSATION_ITEM($s, v) {
    const i = $s.conversationItems.findIndex(x => x.id === v.id);
    if (i !== -1) $s.conversationItems.splice(i, 1, v);
  },
  SET_LOST_REASONS($s, v) {
    $s.lostReasons = v;
  },
  ADD_LOST_REASON($s, v) {
    $s.lostReasons.push(v);
  },
  UPDATE_LOST_REASON($s, v) {
    const i = $s.lostReasons.findIndex(r => r.id === v.id);
    if (i !== -1) $s.lostReasons.splice(i, 1, v);
  },
  DELETE_LOST_REASON($s, id) {
    $s.lostReasons = $s.lostReasons.filter(r => r.id !== id);
  },
  SET_PIPELINE_STAGES_CACHE($s, { pipelineId, stages }) {
    $s.pipelineStagesCache = {
      ...$s.pipelineStagesCache,
      [pipelineId]: stages,
    };
  },
};

const actions = {
  // Pipelines
  fetchPipelines: async ({ commit, state: $s }) => {
    commit('SET_UI_FLAG', { isFetchingPipelines: true });
    try {
      const { data } = await pipelinesAPI.get();
      commit('SET_PIPELINES', data.payload);
      if (data.payload.length && !$s.activePipelineId) {
        commit('SET_ACTIVE_PIPELINE', data.payload[0].id);
      }
    } finally {
      commit('SET_UI_FLAG', { isFetchingPipelines: false });
    }
  },
  createPipeline: async ({ commit }, d) => {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const { data } = await pipelinesAPI.create(d);
      commit('ADD_PIPELINE', data.payload);
      return data.payload;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
  updatePipeline: async ({ commit }, { id, ...d }) => {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const { data } = await pipelinesAPI.update(id, d);
      commit('UPDATE_PIPELINE', data.payload);
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
  deletePipeline: async ({ commit }, id) => {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await pipelinesAPI.delete(id);
      commit('DELETE_PIPELINE', id);
    } finally {
      commit('SET_UI_FLAG', { isDeleting: false });
    }
  },
  setActivePipeline: ({ commit }, id) => {
    commit('SET_ACTIVE_PIPELINE', id);
  },

  // Stages
  fetchStages: async ({ commit }, pipelineId) => {
    commit('SET_UI_FLAG', { isFetchingStages: true });
    try {
      const { data } = await stagesAPI.list(pipelineId);
      commit('SET_STAGES', data.payload);
    } catch {
      /* ignore */
    } finally {
      commit('SET_UI_FLAG', { isFetchingStages: false });
    }
  },
  createStage: async ({ commit }, { pipelineId, ...d }) => {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const { data } = await stagesAPI.create(pipelineId, d);
      commit('ADD_STAGE', data.payload);
      return data.payload;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
  updateStage: async ({ commit }, { pipelineId, id, ...d }) => {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const { data } = await stagesAPI.update(pipelineId, id, d);
      commit('UPDATE_STAGE', data.payload);
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
  deleteStage: async ({ commit }, { pipelineId, id }) => {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await stagesAPI.delete(pipelineId, id);
      commit('DELETE_STAGE', id);
    } finally {
      commit('SET_UI_FLAG', { isDeleting: false });
    }
  },

  // Items
  fetchItems: async ({ commit }, { pipelineId, filters = {} } = {}) => {
    if (!pipelineId) return;
    commit('SET_UI_FLAG', { isFetchingItems: true });
    try {
      const { data } = await itemsAPI.list(pipelineId, filters);
      commit('SET_ITEMS', data.payload);
    } catch {
      /* ignore */
    } finally {
      commit('SET_UI_FLAG', { isFetchingItems: false });
    }
  },
  createItem: async ({ commit }, { pipelineId, ...d }) => {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const { data } = await itemsAPI.create(pipelineId, d);
      commit('ADD_ITEM', data.payload);
      return data.payload;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
  updateItem: async ({ commit }, { pipelineId, id, ...d }) => {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const { data } = await itemsAPI.update(pipelineId, id, d);
      commit('UPDATE_ITEM', data.payload);
      return data.payload;
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
  moveItem: async (
    { commit, state: $s },
    { pipelineId, id, stageId, position }
  ) => {
    const original = $s.items.find(x => x.id === id);
    const originalStageId = original?.stage_id;
    commit('MOVE_ITEM_OPTIMISTIC', { itemId: id, stageId });
    try {
      const { data } = await itemsAPI.move(pipelineId, id, stageId, position);
      commit('UPDATE_ITEM', data.payload);
    } catch (e) {
      // Roll back the optimistic update so the board reflects reality
      if (originalStageId != null) {
        commit('MOVE_ITEM_OPTIMISTIC', {
          itemId: id,
          stageId: originalStageId,
        });
      }
      throw e;
    }
  },
  markItemWon: async ({ commit }, { pipelineId, id }) => {
    const { data } = await itemsAPI.won(pipelineId, id);
    // Backend moves item to is_won stage and sets won_at — single source of truth
    commit('UPDATE_ITEM', data.payload);
    return data.payload;
  },
  markItemLost: async ({ commit }, { pipelineId, id, lostReasonId }) => {
    const payload = lostReasonId ? { lost_reason_id: lostReasonId } : {};
    const { data } = await itemsAPI.lost(pipelineId, id, payload);
    commit('UPDATE_ITEM', data.payload);
    return data.payload;
  },
  transferItem: async (
    { commit },
    { pipelineId, id, targetPipelineId, stageId }
  ) => {
    const { data } = await itemsAPI.transfer(
      pipelineId,
      id,
      targetPipelineId,
      stageId
    );
    commit('DELETE_ITEM', id);
    return data.payload;
  },
  reopenItem: async ({ commit }, { pipelineId, id }) => {
    try {
      const { data } = await itemsAPI.reopen(pipelineId, id);
      commit('UPDATE_ITEM', data.payload);
      return data.payload;
    } catch {
      return null;
    }
  },
  deleteItem: async ({ commit }, { pipelineId, id }) => {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await itemsAPI.delete(pipelineId, id);
      commit('DELETE_ITEM', id);
    } finally {
      commit('SET_UI_FLAG', { isDeleting: false });
    }
  },
  setFilters: ({ commit }, filters) => {
    commit('SET_FILTERS', filters);
  },
  clearFilters: ({ commit }) => {
    commit('CLEAR_FILTERS');
  },

  // Tasks
  fetchTasks: async ({ commit }, { pipelineId, itemId }) => {
    try {
      const { data } = await tasksAPI.list(pipelineId, itemId);
      commit('SET_ITEM_TASKS', { itemId, tasks: data.payload });
    } catch {
      /* ignore */
    }
  },
  createTask: async ({ commit }, { pipelineId, itemId, ...d }) => {
    try {
      const { data } = await tasksAPI.create(pipelineId, itemId, d);
      commit('ADD_ITEM_TASK', { itemId, task: data.payload });
      return data.payload;
    } catch (e) {
      const msg =
        e?.response?.data?.message ||
        e?.response?.data?.error ||
        'Erro ao criar tarefa';
      throw new Error(msg);
    }
  },
  updateTask: async ({ commit }, { pipelineId, itemId, id, ...d }) => {
    const { data } = await tasksAPI.update(pipelineId, itemId, id, d);
    commit('UPDATE_ITEM_TASK', { itemId, task: data.payload });
  },
  completeTask: async ({ commit }, { pipelineId, itemId, id }) => {
    try {
      const { data } = await tasksAPI.complete(pipelineId, itemId, id);
      commit('UPDATE_ITEM_TASK', { itemId, task: data.payload });
    } catch {
      /* ignore */
    }
  },
  deleteTask: async ({ commit }, { pipelineId, itemId, id }) => {
    try {
      await tasksAPI.delete(pipelineId, itemId, id);
      commit('DELETE_ITEM_TASK', { itemId, taskId: id });
    } catch {
      /* ignore */
    }
  },

  // Notes
  fetchNotes: async ({ commit }, { pipelineId, itemId }) => {
    try {
      const { data } = await notesAPI.list(pipelineId, itemId);
      commit('SET_ITEM_NOTES', { itemId, notes: data.payload });
    } catch {
      /* ignore */
    }
  },
  createNote: async ({ commit }, { pipelineId, itemId, content }) => {
    const { data } = await notesAPI.create(pipelineId, itemId, { content });
    commit('ADD_ITEM_NOTE', { itemId, note: data.payload });
    return data.payload;
  },
  deleteNote: async ({ commit }, { pipelineId, itemId, id }) => {
    try {
      await notesAPI.delete(pipelineId, itemId, id);
      commit('DELETE_ITEM_NOTE', { itemId, noteId: id });
    } catch {
      /* ignore */
    }
  },

  // Activities
  fetchActivities: async ({ commit }, { pipelineId, itemId }) => {
    try {
      const { data } = await activitiesAPI.list(pipelineId, itemId);
      commit('SET_ITEM_ACTIVITIES', { itemId, activities: data.payload });
    } catch {
      /* ignore */
    }
  },

  // Global items (conversation lookup)
  fetchItemsByConversation: async ({ commit }, conversationId) => {
    try {
      const { data } = await globalItemsAPI.byConversation(conversationId);
      commit('SET_CONVERSATION_ITEMS', data.payload);
    } catch {
      commit('SET_CONVERSATION_ITEMS', []);
    }
  },
  fetchItem: async ({ commit }, { pipelineId, id }) => {
    try {
      const { data } = await itemsAPI.show(pipelineId, id);
      commit('UPDATE_ITEM', data.payload);
      return data.payload;
    } catch {
      return null;
    }
  },

  // Attachments
  fetchAttachments: async ({ commit }, { pipelineId, itemId }) => {
    try {
      const { data } = await attachmentsAPI.list(pipelineId, itemId);
      commit('SET_ITEM_ATTACHMENTS', { itemId, attachments: data.payload });
    } catch {
      /* ignore */
    }
  },
  createAttachment: async ({ commit }, { pipelineId, itemId, formData }) => {
    const { data } = await attachmentsAPI.create(pipelineId, itemId, formData);
    commit('ADD_ITEM_ATTACHMENT', { itemId, attachment: data.payload });
    return data.payload;
  },
  deleteAttachment: async ({ commit }, { pipelineId, itemId, id }) => {
    try {
      await attachmentsAPI.delete(pipelineId, itemId, id);
      commit('DELETE_ITEM_ATTACHMENT', { itemId, attachmentId: id });
    } catch {
      /* ignore */
    }
  },

  // Lost reasons
  fetchLostReasons: async ({ commit }) => {
    try {
      const { data } = await lostReasonsAPI.list();
      commit('SET_LOST_REASONS', data.payload);
    } catch {
      /* ignore */
    }
  },
  createLostReason: async ({ commit }, d) => {
    const { data } = await lostReasonsAPI.create(d);
    commit('ADD_LOST_REASON', data.payload);
    return data.payload;
  },
  updateLostReason: async ({ commit }, { id, ...d }) => {
    const { data } = await lostReasonsAPI.update(id, d);
    commit('UPDATE_LOST_REASON', data.payload);
  },
  deleteLostReason: async ({ commit }, id) => {
    await lostReasonsAPI.delete(id);
    commit('DELETE_LOST_REASON', id);
  },

  // Pipeline stages cache (for cross-pipeline move)
  fetchPipelineStages: async ({ commit }, pipelineId) => {
    try {
      const { data } = await stagesAPI.list(pipelineId);
      commit('SET_PIPELINE_STAGES_CACHE', {
        pipelineId,
        stages: data.payload,
      });
    } catch {
      /* ignore */
    }
  },
};

export default { namespaced: true, state, getters, mutations, actions };
