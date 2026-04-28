/* global axios */
import ApiClient from './ApiClient';

class AiAgentsAPI extends ApiClient {
  constructor() {
    super('ai_agents', { accountScoped: true });
  }

  getAll() {
    return axios.get(this.url);
  }

  get(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(data) {
    return axios.post(this.url, { ai_agent: data });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { ai_agent: data });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  publishPrompt(id, prompt) {
    return axios.post(`${this.url}/${id}/publish_prompt`, { prompt });
  }

  saveDraft(id, prompt) {
    return axios.patch(`${this.url}/${id}/save_draft`, { prompt });
  }

  playground(id, messages, useDraft = false) {
    return axios.post(`${this.url}/${id}/playground`, {
      messages,
      use_draft: useDraft,
    });
  }

  promptAssistant(id) {
    return axios.post(`${this.url}/${id}/prompt_assistant`);
  }

  exportAgent(id) {
    return axios.get(`${this.url}/${id}/export`, { responseType: 'blob' });
  }

  importAgent(agentData) {
    return axios.post(`${this.url}/import`, {
      agent_data: JSON.stringify(agentData),
    });
  }

  getPromptVersions(agentId) {
    return axios.get(`${this.url}/${agentId}/prompt_versions`);
  }

  getFaqs(agentId) {
    return axios.get(`${this.url}/${agentId}/faqs`);
  }

  createFaq(agentId, data) {
    return axios.post(`${this.url}/${agentId}/faqs`, { faq: data });
  }

  updateFaq(agentId, faqId, data) {
    return axios.patch(`${this.url}/${agentId}/faqs/${faqId}`, { faq: data });
  }

  deleteFaq(agentId, faqId) {
    return axios.delete(`${this.url}/${agentId}/faqs/${faqId}`);
  }

  importFaqs(agentId, rows) {
    return axios.post(`${this.url}/${agentId}/faqs/import`, { rows });
  }

  getProtocols(agentId) {
    return axios.get(`${this.url}/${agentId}/protocols`);
  }

  createProtocol(agentId, data) {
    return axios.post(`${this.url}/${agentId}/protocols`, { protocol: data });
  }

  updateProtocol(agentId, protocolId, data) {
    return axios.patch(`${this.url}/${agentId}/protocols/${protocolId}`, {
      protocol: data,
    });
  }

  deleteProtocol(agentId, protocolId) {
    return axios.delete(`${this.url}/${agentId}/protocols/${protocolId}`);
  }

  getSchedule(agentId) {
    return axios.get(`${this.url}/${agentId}/schedule`);
  }

  updateSchedule(agentId, data) {
    return axios.patch(`${this.url}/${agentId}/schedule`, { schedule: data });
  }

  getGoogleAuthUrl(agentId) {
    return axios.get(`${this.url}/${agentId}/schedule/google_auth`);
  }

  disconnectGoogle(agentId) {
    return axios.delete(`${this.url}/${agentId}/schedule/google_disconnect`);
  }

  getAvailableSlots(agentId) {
    return axios.get(`${this.url}/${agentId}/schedule/available_slots`);
  }

  getMetrics(period = 'week') {
    return axios.get(`${this.url.replace('/ai_agents', '/ai_agent_metrics')}`, {
      params: { period },
    });
  }

  getAgentMetrics(agentId, period = 'week') {
    return axios.get(`${this.url}/${agentId}/metrics`, { params: { period } });
  }
}

export default new AiAgentsAPI();
