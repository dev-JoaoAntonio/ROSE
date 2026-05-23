# Compliance — LGPD e ANVISA

## LGPD

### Anonimização
- Arquivos no Storage e em URLs públicas/temporárias usam UUID v4 — **nunca** nome, CPF ou identificadores reais do paciente.
- Tabela `pacientes` no Postgres tem colunas sensíveis (nome, CPF, contatos) criptografadas em repouso. Chave gerenciada via Supabase Vault.
- Associação UUID ↔ paciente real só via JOIN dentro do banco, protegida por Row Level Security (RLS).

### Controle de acesso
- RLS habilitado em todas as tabelas com dado pessoal.
- Roles: `tecnico`, `patologista`, `admin`, `auditor`.
- `tecnico` → vê apenas casos do hospital onde atua.
- `patologista` → vê apenas a fila atribuída a ele.
- `auditor` → leitura no audit log, nunca em dados clínicos.

### Audit log
- Tabela `audit_log` append-only (sem UPDATE/DELETE via RLS).
- Registra: usuário, ação, recurso acessado, IP, user-agent, timestamp NTP, duração da sessão.
- Trigger automático em SELECT de tabelas sensíveis.

### Direito de titular
- Endpoint para exportação dos dados de um paciente (LGPD Art. 18).
- Procedimento documentado para anonimização irreversível ao final da retenção legal.

---

## ANVISA — RDC 786/2023

### Rastreabilidade obrigatória por caso
Cada caso registra obrigatoriamente:

| Campo | Origem |
|---|---|
| Identificação do técnico coletor | Login no app mobile |
| ID/serial do dispositivo DIPLE II | Selecionado no app no início do caso |
| Lote do corante usado | Selecionado no app no início do caso (lista do hospital) |
| Modelo + serial do smartphone | Device Info automático |
| Geolocalização do procedimento | GPS do device (consentido) |
| Carimbo NTP de cada etapa | Servidor NTP do Observatório Nacional |

### Disclaimer fixo
Todo PDF de laudo e toda tela do dashboard exibem:

> "Avaliação restrita à adequação celular (ROSE). Não substitui o exame histopatológico definitivo."

### Cadeia de custódia digital
- **C2PA** no momento da captura.
- **Hash SHA-256 #1** no upload (arquivo bruto).
- **Hash SHA-256 #2** no fechamento do caso (combina arquivo + veredito).
- Qualquer alteração posterior quebra o hash → evidência de violação.

---

## Janela de homologação

Enquanto a homologação ANVISA de Classe I não conclui (estimado em 60 dias pelo briefing), a operação roda sob **Acordo de Cooperação e Validação Científica** com os 18 hospitais piloto. Esse status precisa estar marcado no dashboard administrativo até que a homologação saia.
