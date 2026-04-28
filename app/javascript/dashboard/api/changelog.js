import ApiClient from './ApiClient';

class ChangelogApi extends ApiClient {
  constructor() {
    super('changelog', { apiVersion: 'v1' });
  }

  // eslint-disable-next-line class-methods-use-this
  fetchFromHub() {
    return Promise.resolve({ data: [] });
  }
}

export default new ChangelogApi();
