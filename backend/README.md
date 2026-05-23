# Tele ROSE — Backend

API e workers do sistema de telepatologia Tele ROSE.

**Stack:** NestJS 11 + Fastify + Prisma 7 + Supabase (Postgres SP) + BullMQ.

## Setup

### 1. Pré-requisitos

- Node.js 20+ (testado em 25)
- Acesso a um projeto Supabase em região São Paulo (`sa-east-1`)

### 2. Instalar dependências

```bash
cd backend
npm install
```

### 3. Configurar variáveis de ambiente

Copie o template e preencha com os valores do **seu** projeto Supabase:

```bash
cp .env.example .env.local
```

No painel do Supabase:
- **Project Settings → Database** → copie a *Connection String* (Direct connection)
- **Project Settings → API** → copie `URL`, `anon key`, `service_role key`, `JWT secret`

Cole no `.env.local`. Esse arquivo é **gitignored** — nunca commite.

### 4. Aplicar as migrations no Supabase

```bash
npx prisma migrate deploy
```

Isso roda na ordem:
1. `00000000000000_init` — cria tabelas, enums e índices
2. `00000000000001_rls_and_audit` — habilita RLS, cria policies LGPD, audit log append-only

> **Importante:** RLS protege seus dados clínicos. Não pule a segunda migration.

### 5. Gerar o client Prisma (já roda automático, mas se precisar)

```bash
npx prisma generate
```

### 6. Rodar em desenvolvimento

```bash
npm run start:dev
```

API em `http://localhost:3000`, Swagger em `http://localhost:3000/docs`.

## Estrutura

```
backend/
├── prisma/
│   ├── schema.prisma                    Schema do banco (source of truth)
│   ├── migrations/
│   │   ├── 00000000000000_init/         Tabelas + enums
│   │   └── 00000000000001_rls_and_audit/  Policies LGPD + audit append-only
│   └── ...
├── prisma.config.ts                     Config do CLI Prisma (lê DATABASE_URL)
├── src/
│   ├── main.ts                          Bootstrap (Fastify + Helmet + Swagger)
│   ├── app.module.ts                    Root module
│   ├── prisma/                          PrismaService + Module global
│   └── ...                              Módulos de negócio (a criar)
└── generated/
    └── prisma/                          Client gerado pelo Prisma (não editar)
```

## Modelo de segurança

| Quem | Conexão | RLS |
|---|---|---|
| App iOS/Android | Direto no Supabase via SDK, JWT do usuário | **Sim — protege os dados** |
| Dashboard web | Direto no Supabase via SDK, JWT do usuário | **Sim — protege os dados** |
| Este backend (NestJS) | Postgres com `service_role` via Prisma | Bypassa RLS — usa Guards/Interceptors |

Sempre que o backend operar em nome de um usuário (ex: gerar PDF, abrir caso), os
Guards verificam o JWT do Supabase e checam role/membership antes de prosseguir.

## Auditoria

Toda ação sensível escreve em `audit_log` via interceptor global.
A tabela é **append-only por trigger** — UPDATE e DELETE são rejeitados no
nível do banco, mesmo via `service_role`.

## Scripts úteis

```bash
npm run start:dev        # dev com hot-reload
npm run build            # build de produção
npm run start:prod       # start da build
npm run lint             # ESLint
npm run test             # unit tests
npm run test:e2e         # e2e tests

npx prisma studio        # GUI do banco (cuidado com dados clínicos)
npx prisma migrate dev   # cria nova migration a partir de mudanças no schema
npx prisma migrate deploy # aplica migrations em prod/staging
npx prisma generate      # regera o client TypeScript
```
