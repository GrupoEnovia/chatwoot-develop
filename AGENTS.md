# Chatwoot-Volponi
## Projeto: Chatwoot-Volponi (Skill-Hub Edition)

> Quando perguntado "qual projeto é esse?", responda: **Chatwoot-Volponi**

---

## Identidade do Projeto

- **Nome**: Chatwoot-Volponi
- **Edição**: Skill-Hub Edition
- **Base**: Fork do [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot)
- **Repositório**: https://github.com/skillhub-app/chatwoot
- **Branch principal**: `main`
- **Branch de desenvolvimento**: `develop`
- **Feature ativa**: `feature/kanban`

---

## Ambiente Local

- **URL**: http://localhost:3000
- **Admin**: adm@skill-hub.app
- **Subir tudo**: `docker compose up` (na pasta `/Users/wesleipreisner/chatwoot`)
- **MailHog**: http://localhost:8025
- **Primeira vez**:
  ```bash
  docker compose build
  docker compose run --rm rails bundle exec rails db:chatwoot_prepare
  docker compose up
  ```

---

## Stack Técnica

| Camada | Tecnologia |
|--------|-----------|
| Backend | Ruby on Rails 7.1 |
| Frontend | Vue 3 (Composition API + `<script setup>`) |
| CSS | Tailwind CSS (sem CSS customizado) |
| Build | Vite |
| Jobs | Sidekiq + Redis |
| Banco | PostgreSQL 16 (pgvector) |
| Containers | Docker Compose |
| CI/CD | GitHub Actions → VPS via SSH |

---

## Funcionalidades Customizadas: Kanban Multi-Tenant

### Conceito
Cada `Account` tem seu próprio Kanban isolado. As colunas (stages) são configuradas por conta. Cada card do Kanban (`KanbanItem`) é vinculado a uma conversa do Chatwoot e ao telefone do contato.

### Modelo de Dados

```
Account (multi-tenant)
  └── KanbanBoard (1 por account)
        └── KanbanStage (colunas ordenadas)
              └── KanbanItem (cards)
                    ├── conversation_id → Conversation
                    ├── contact_phone   → string
                    ├── assignee_id     → User
                    ├── title
                    ├── description
                    ├── position        → integer (ordenação)
                    └── metadata        → jsonb
```

### Arquivos a Criar

```
app/
  models/
    kanban_board.rb
    kanban_stage.rb
    kanban_item.rb
  controllers/
    api/v1/accounts/
      kanban_boards_controller.rb
      kanban_stages_controller.rb
      kanban_items_controller.rb
  services/
    kanban/
      move_item_service.rb        # move card entre stages + dispara automações
      webhook_dispatcher_service.rb
  javascript/
    dashboard/
      components/
        kanban/
          KanbanBoard.vue
          KanbanStage.vue
          KanbanCard.vue
          KanbanCardModal.vue
db/
  migrate/
    YYYYMMDD_create_kanban_boards.rb
    YYYYMMDD_create_kanban_stages.rb
    YYYYMMDD_create_kanban_items.rb
spec/
  models/
    kanban_item_spec.rb
  services/
    kanban/move_item_service_spec.rb
```

---

## Automações por Etapa

Quando um `KanbanItem` é movido para uma stage, o sistema executa automaticamente as automações configuradas para aquela stage:

- Enviar mensagem template via WhatsApp
- Atribuir conversa a agente
- Adicionar label à conversa
- Disparar webhook externo
- Agendar follow-up

As automações são configuradas por `KanbanStage` e armazenadas em `jsonb`.

---

## Webhooks por Etapa e Geral

### Webhook por Stage
Cada `KanbanStage` pode ter uma URL de webhook configurada. Quando um card entra nessa stage, um POST é enviado:

```json
{
  "event": "kanban.item.stage_changed",
  "account_id": 1,
  "stage": { "id": 3, "name": "Proposta Enviada" },
  "item": {
    "id": 42,
    "title": "Empresa XYZ",
    "conversation_id": 100,
    "contact_phone": "+5511999999999"
  },
  "timestamp": "2026-04-17T13:00:00Z"
}
```

### Webhook Geral
A conta pode cadastrar um webhook global que recebe todos os eventos do Kanban:
- `kanban.item.created`
- `kanban.item.stage_changed`
- `kanban.item.updated`
- `kanban.item.deleted`

---

## API Pública do Kanban

Prefixo: `/api/v1/accounts/:account_id/kanban`

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/boards` | Lista o board da conta |
| GET | `/stages` | Lista as stages |
| POST | `/stages` | Cria stage |
| PATCH | `/stages/:id` | Atualiza stage |
| DELETE | `/stages/:id` | Remove stage |
| GET | `/items` | Lista cards (filtrável por stage/assignee) |
| POST | `/items` | Cria card |
| PATCH | `/items/:id` | Atualiza card |
| PATCH | `/items/:id/move` | Move card para outra stage |
| DELETE | `/items/:id` | Remove card |

Autenticação: `api_access_token` (padrão Chatwoot).

---

## KanbanItem: Vinculação com Conversa e Telefone

- `conversation_id` → referência direta à `Conversation` do Chatwoot
- `contact_phone` → número extraído do contato da conversa (WhatsApp/SMS)
- Ao criar um `KanbanItem` a partir de uma conversa, esses campos são preenchidos automaticamente
- A UI exibe o histórico da conversa inline no card do Kanban

---

## Dashboard de Negócios

Rota: `/dashboard/kanban/analytics`

Métricas exibidas por período (hoje / semana / mês):

- Total de cards por stage
- Taxa de conversão entre stages
- Tempo médio em cada stage
- Cards por agente (ranking)
- Cards criados vs fechados
- Receita estimada (campo opcional no card)

Tecnologia: Vue 3 + Chart.js (ou Recharts se já disponível no projeto).

---

## Gamificação com Modo TV

### Modo TV
Tela fullscreen para exibição em TV/monitor da equipe. Ativado via `/kanban/tv`.

Exibe em tempo real (via ActionCable):
- Ranking de agentes (cards fechados no dia)
- Placar de metas (ex: 10 propostas enviadas)
- Últimas movimentações do Kanban
- Alertas de cards parados há mais de X horas

### Gamificação
- Pontos por ação: mover card (+1), fechar negócio (+10), bater meta diária (+50)
- Badge por conquista (primeiro fechamento, 10 seguidos, etc.)
- Histórico de pontuação por agente em `AgentScore` (model a criar)

---

## Chatwoot Development Guidelines

### Build / Test / Lint

- **Setup**: `bundle install && pnpm install`
- **Run Dev**: `pnpm dev` or `overmind start -f ./Procfile.dev`
- **Seed Local Test Data**: `bundle exec rails db:seed`
- **Seed Account Sample Data**: Super Admin → Accounts → Seed ou `bundle exec rails runner "Internal::SeedAccountJob.perform_now(Account.find(<id>))"`
- **Lint JS/Vue**: `pnpm eslint` / `pnpm eslint:fix`
- **Lint Ruby**: `bundle exec rubocop -a`
- **Test JS**: `pnpm test` or `pnpm test:watch`
- **Test Ruby**: `bundle exec rspec spec/path/to/file_spec.rb`
- **Single Test**: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- **Ruby Version**: via `rbenv` — versão em `.ruby-version`
- **rbenv setup**: `eval "$(rbenv init -)"`
- Always prefer `bundle exec` for Ruby CLI tasks

### Code Style

- **Ruby**: RuboCop (150 char max line length)
- **Vue/JS**: ESLint (Airbnb base + Vue 3 recommended)
- **Vue Components**: PascalCase
- **Events**: camelCase
- **I18n**: Sem strings bare nos templates; usar i18n
- **Vue API**: Sempre Composition API com `<script setup>`

### Styling

- **Tailwind Only** — sem CSS customizado, sem scoped CSS, sem inline styles
- **Colors**: ver `tailwind.config.js`

### General Guidelines

- MVP focus: menor mudança de código, happy-path only
- Sem defensive programming desnecessário
- Código minimal e legível; clareza > abstração
- Iterar após confirmação
- Evitar specs a menos que pedido
- Remover código morto/inatingível

### Commit Messages

- Conventional Commits: `type(scope): subject`
- Exemplo: `feat(kanban): add stage webhook dispatcher`
- Não referenciar Claude nos commits

### PR Description Format

- Parágrafo curto descrevendo a mudança para o usuário
- Seção `Closes` com links de issues
- `How to test` para features, `How to reproduce` para bugfixes

### Project-Specific

- **Translations**: Atualizar apenas `en.yml` e `en.json`
- **Frontend**: Usar `components-next/` para message bubbles

### Ruby Best Practices

- Usar definições compactas de `module/class`; evitar estilo aninhado

### Enterprise Edition Notes

- Overlay Enterprise em `enterprise/` — sempre verificar arquivos correspondentes ao editar core
- Novos endpoints/serviços: considerar override ou extension point via `prepend_mod_with`
- Specs Enterprise: `spec/enterprise/`

### Branding

- Usar `replaceInstallationName` de `shared/composables/useBranding` para strings com "Chatwoot"
