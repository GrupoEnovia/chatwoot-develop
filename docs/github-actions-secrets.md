# GitHub Actions: secrets `VPS_HOST`, `VPS_USER` e `SSH_KEY`

Este guia descreve como cadastrar os secrets usados pelo workflow **Deploy to VPS** (`.github/workflows/deploy.yml`) e como obter cada valor com segurança.

---

## O que é cada secret

| Secret | Descrição |
|--------|-----------|
| **VPS_HOST** | Endereço da VPS: **IP** (ex.: `203.0.113.10`) ou **hostname** (ex.: `vps.exemplo.com`). Sem prefixo `ssh://`, sem espaços no início ou fim. |
| **VPS_USER** | Usuário Linux usado no SSH (ex.: `root`, `ubuntu`, `debian`). Deve ser o mesmo usuário que possui a chave pública correspondente em `~/.ssh/authorized_keys` na VPS. |
| **SSH_KEY** | Conteúdo completo da **chave privada** SSH (arquivo **sem** extensão `.pub`). O texto começa com `-----BEGIN ... PRIVATE KEY-----` e termina com `-----END ... PRIVATE KEY-----`. **Não** é a senha de login da VPS. |

---

## Onde adicionar no GitHub

1. Abra o **repositório** no GitHub (o mesmo onde as Actions executam).  
   - Se usar **fork**, os secrets devem ser criados **no fork**, não apenas no repositório original.
2. Vá em **Settings** (Configurações do repositório).
3. No menu lateral: **Secrets and variables** → **Actions**.
4. Aba **Repository secrets**.
5. Clique em **New repository secret** e crie cada um dos três secrets abaixo.

### `VPS_HOST`

- **Name:** `VPS_HOST` (nome exato).
- **Secret:** IP ou hostname da VPS.
- Salve com **Add secret**.

### `VPS_USER`

- **Name:** `VPS_USER`.
- **Secret:** nome do usuário SSH (ex.: `root`).
- **Add secret**.

### `SSH_KEY`

- **Name:** `SSH_KEY`.
- **Secret:** cole a **chave privada** inteira (várias linhas, incluindo `BEGIN` e `END`).
- **Add secret**.

> **Segurança:** nunca commite a chave privada no repositório. Use apenas **Repository secrets** (ou secrets de ambiente/organização, se a política da equipe permitir).

---

## Como obter o `SSH_KEY` (par de chaves)

O GitHub Actions conecta na VPS por SSH com **autenticação por chave**. É necessário um **par**: privada (no secret `SSH_KEY`) e pública (na VPS).

### Gerar um par novo na VPS

Exemplo (ajuste o caminho `-f` se quiser outra pasta):

```bash
cd /opt/chatwoot-agenda-inteligente
ssh-keygen -t ed25519 -C "github-actions-deploy" -f deploy_github -N ""
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat deploy_github.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

- O arquivo **`deploy_github.pub`** contém a **chave pública** (uma linha começando com `ssh-ed25519`). Esse conteúdo deve estar em **`authorized_keys`** — use `cat deploy_github.pub >> ~/.ssh/authorized_keys` como acima.
- **Não** coloque no `authorized_keys` o bloco **randomart** (desenho ASCII) exibido pelo `ssh-keygen`; apenas a linha do `.pub`.

Para colar no GitHub como **SSH_KEY**, exiba a **privada**:

```bash
cat deploy_github
```

Copie **todo** o resultado (da primeira à última linha) para o secret **SSH_KEY**.

### Gerar um par novo no Windows (PowerShell)

```powershell
ssh-keygen -t ed25519 -C "github-deploy" -f "$env:USERPROFILE\.ssh\deploy_github" -N ""
```

- Privada: `%USERPROFILE%\.ssh\deploy_github` → conteúdo vai no secret **SSH_KEY**.
- Pública: `%USERPROFILE%\.ssh\deploy_github.pub` → uma linha; adicione na VPS em `~/.ssh/authorized_keys` do usuário escolhido.

### Usar uma chave que você já usa

Se você já acessa a VPS com chave (ex.: `~/.ssh/id_ed25519`), pode usar a **privada** correspondente no **SSH_KEY**, desde que a **pública** já esteja no `authorized_keys` do **VPS_USER** que você configurar.

### Testar antes do workflow

No seu computador:

```powershell
ssh -i "C:\Users\SEU_USUARIO\.ssh\deploy_github" VPS_USER@VPS_HOST
```

Substitua pelo caminho real da privada. Se a conexão funcionar sem senha (quando a chave está correta), os secrets tendem a estar alinhados.

### Copiar a privada sem usar o terminal

Se o cliente SSH não permitir copiar da tela (ex.: alguns terminais no Windows):

- Use **SFTP** para baixar o arquivo `deploy_github` (somente a privada) e abra no Bloco de Notas; ou  
- No PowerShell:  
  `scp VPS_USER@VPS_HOST:/caminho/completo/deploy_github %USERPROFILE%\Desktop\deploy_github.txt`

Depois cole o conteúdo do arquivo no secret **SSH_KEY**.

---

## Verificar se funcionou

1. **Actions** → selecione o workflow **Deploy to VPS**.
2. Execute **Re-run all jobs** ou faça um push na branch configurada no workflow (ex.: `main`).
3. O passo **Validate deployment secrets** falha se algum dos três secrets estiver ausente ou vazio; após configurar corretamente, esse passo deve concluir com sucesso.

---

## Observações sobre fork e organização

- **Fork:** Actions no fork **não herdam** secrets do repositório upstream; recrie **VPS_HOST**, **VPS_USER** e **SSH_KEY** no fork.
- **Organização:** secrets definidos no nível da organização precisam estar **acessíveis** ao repositório (políticas da org).

---

## Checklist rápido

- [ ] `VPS_HOST` = IP ou hostname correto da VPS  
- [ ] `VPS_USER` = usuário com `authorized_keys` contendo a chave **pública** correspondente  
- [ ] `SSH_KEY` = chave **privada** completa (não o arquivo `.pub`)  
- [ ] Nenhuma chave privada commitada no Git  

---

## Variável opcional: `SWARM_STACK_NAME` (deploy no Docker Swarm / Portainer)

No Swarm, os serviços seguem o padrão **`<nome_da_stack>_rails`** e **`<nome_da_stack>_sidekiq`**. O nome da stack no Portainer costuma ser o nome que você deu à stack (ex.: `chatwoot-agenda-inteligente`).

O workflow usa por padrão o prefixo **`chatwoot-agenda-inteligente`**. Se a sua stack tiver **outro nome**, crie uma **variable** (não precisa ser secret):

1. **Settings** → **Secrets and variables** → **Actions** → aba **Variables**.
2. **New repository variable**
3. **Name:** `SWARM_STACK_NAME`
4. **Value:** somente o prefixo da stack, **sem** `_rails` (ex.: `meu-projeto-chatwoot`).

Na VPS, confira com: `docker service ls` — os nomes devem bater com `{SWARM_STACK_NAME}_rails` e `{SWARM_STACK_NAME}_sidekiq`.

---

## Referência no repositório

O workflow que consome esses secrets está em `.github/workflows/deploy.yml`.
