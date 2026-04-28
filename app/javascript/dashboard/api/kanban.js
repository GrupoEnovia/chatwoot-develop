/* global axios */
import ApiClient from './ApiClient';

class KanbanPipelinesAPI extends ApiClient {
  constructor() {
    super('kanban/pipelines', { accountScoped: true });
  }
}

class KanbanStagesAPI extends ApiClient {
  constructor() {
    super('kanban/pipelines', { accountScoped: true });
  }

  stagesUrl(pipelineId) {
    return `${this.url}/${pipelineId}/stages`;
  }

  list(pipelineId) {
    return axios.get(this.stagesUrl(pipelineId));
  }

  create(pipelineId, data) {
    return axios.post(this.stagesUrl(pipelineId), data);
  }

  update(pipelineId, id, data) {
    return axios.patch(`${this.stagesUrl(pipelineId)}/${id}`, data);
  }

  reorder(pipelineId, id, position) {
    return axios.patch(`${this.stagesUrl(pipelineId)}/${id}/reorder`, {
      position,
    });
  }

  delete(pipelineId, id) {
    return axios.delete(`${this.stagesUrl(pipelineId)}/${id}`);
  }
}

class KanbanItemsAPI extends ApiClient {
  constructor() {
    super('kanban/pipelines', { accountScoped: true });
  }

  itemsUrl(pipelineId) {
    return `${this.url}/${pipelineId}/items`;
  }

  list(pipelineId, params = {}) {
    return axios.get(this.itemsUrl(pipelineId), { params });
  }

  show(pipelineId, id) {
    return axios.get(`${this.itemsUrl(pipelineId)}/${id}`);
  }

  create(pipelineId, data) {
    return axios.post(this.itemsUrl(pipelineId), data);
  }

  update(pipelineId, id, data) {
    return axios.patch(`${this.itemsUrl(pipelineId)}/${id}`, data);
  }

  move(pipelineId, id, stageId, position) {
    return axios.patch(`${this.itemsUrl(pipelineId)}/${id}/move`, {
      stage_id: stageId,
      position,
    });
  }

  won(pipelineId, id) {
    return axios.patch(`${this.itemsUrl(pipelineId)}/${id}/won`);
  }

  lost(pipelineId, id, data = {}) {
    return axios.patch(`${this.itemsUrl(pipelineId)}/${id}/lost`, data);
  }

  reopen(pipelineId, id) {
    return axios.patch(`${this.itemsUrl(pipelineId)}/${id}/reopen`);
  }

  transfer(pipelineId, id, targetPipelineId, stageId) {
    return axios.patch(`${this.itemsUrl(pipelineId)}/${id}/transfer`, {
      target_pipeline_id: targetPipelineId,
      stage_id: stageId,
    });
  }

  delete(pipelineId, id) {
    return axios.delete(`${this.itemsUrl(pipelineId)}/${id}`);
  }
}

class KanbanItemSubresourceAPI extends ApiClient {
  constructor(subresource) {
    super('kanban/pipelines', { accountScoped: true });
    this.subresource = subresource;
  }

  // Named differently from ApiClient#baseUrl to avoid infinite recursion
  // (ApiClient.url getter calls this.baseUrl(), so overriding it loops forever)
  itemUrl(pipelineId, itemId) {
    return `${this.url}/${pipelineId}/items/${itemId}/${this.subresource}`;
  }

  list(pipelineId, itemId) {
    return axios.get(this.itemUrl(pipelineId, itemId));
  }

  create(pipelineId, itemId, data) {
    return axios.post(this.itemUrl(pipelineId, itemId), data);
  }

  update(pipelineId, itemId, id, data) {
    return axios.patch(`${this.itemUrl(pipelineId, itemId)}/${id}`, data);
  }

  delete(pipelineId, itemId, id) {
    return axios.delete(`${this.itemUrl(pipelineId, itemId)}/${id}`);
  }

  complete(pipelineId, itemId, id) {
    return axios.patch(`${this.itemUrl(pipelineId, itemId)}/${id}/complete`);
  }
}

class KanbanBadgesAPI extends ApiClient {
  constructor() {
    super('kanban/badges', { accountScoped: true });
  }

  list() {
    return axios.get(this.url);
  }

  create(data) {
    return axios.post(this.url, data);
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  seed() {
    return axios.post(`${this.url}/seed`);
  }
}

class KanbanLostReasonsAPI extends ApiClient {
  constructor() {
    super('kanban/lost_reasons', { accountScoped: true });
  }

  list() {
    return axios.get(this.url);
  }

  create(data) {
    return axios.post(this.url, data);
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

class KanbanGlobalItemsAPI extends ApiClient {
  constructor() {
    super('kanban/items', { accountScoped: true });
  }

  byConversation(conversationId) {
    return axios.get(this.url, { params: { conversation_id: conversationId } });
  }
}

class KanbanGamificationAPI extends ApiClient {
  constructor() {
    super('kanban/gamification', { accountScoped: true });
  }

  rankings(params = {}) {
    return axios.get(`${this.url}/rankings`, { params });
  }

  overview(params = {}) {
    return axios.get(`${this.url}/overview`, { params });
  }

  recentWins(params = {}) {
    return axios.get(`${this.url}/recent_wins`, { params });
  }

  timeline(params = {}) {
    return axios.get(`${this.url}/timeline`, { params });
  }

  globalGoals() {
    return axios.get(`${this.url}/global_goals`);
  }

  updateGlobalGoals(data) {
    return axios.patch(`${this.url}/global_goals`, data);
  }
}

class KanbanGoalsAPI extends ApiClient {
  constructor() {
    super('kanban/goals', { accountScoped: true });
  }

  list(year, month) {
    return axios.get(this.url, { params: { year, month } });
  }

  upsert(data) {
    return axios.post(`${this.url}/upsert`, data);
  }
}

class KanbanAutomationsAPI extends ApiClient {
  constructor() {
    super('kanban/automations', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(data) {
    return axios.post(this.url, data);
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  listActions(automationId) {
    return axios.get(`${this.url}/${automationId}/actions`);
  }

  createAction(automationId, data) {
    return axios.post(`${this.url}/${automationId}/actions`, data);
  }

  updateAction(automationId, actionId, data) {
    return axios.patch(`${this.url}/${automationId}/actions/${actionId}`, data);
  }

  deleteAction(automationId, actionId) {
    return axios.delete(`${this.url}/${automationId}/actions/${actionId}`);
  }
}

export const automationsAPI = new KanbanAutomationsAPI();
export const badgesAPI = new KanbanBadgesAPI();
export const pipelinesAPI = new KanbanPipelinesAPI();
export const lostReasonsAPI = new KanbanLostReasonsAPI();
export const globalItemsAPI = new KanbanGlobalItemsAPI();
export const gamificationAPI = new KanbanGamificationAPI();
export const goalsAPI = new KanbanGoalsAPI();
export const stagesAPI = new KanbanStagesAPI();
export const itemsAPI = new KanbanItemsAPI();
export const tasksAPI = new KanbanItemSubresourceAPI('tasks');
export const notesAPI = new KanbanItemSubresourceAPI('notes');
export const activitiesAPI = new KanbanItemSubresourceAPI('activities');
export const attachmentsAPI = new KanbanItemSubresourceAPI('attachments');
