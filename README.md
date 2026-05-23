# ROSE — Tele ROSE / LABMOB

Plataforma de **telepatologia para avaliação celular Rapid On-Site Evaluation (ROSE)** durante punção por agulha fina (PAAF).

Permite que um patologista central valide em tempo real a adequação celular de uma amostra coletada por técnico em hospital remoto, usando smartphone homologado + lente óptica DIPLE II.

## Componentes

| Pasta | Descrição |
|---|---|
| [ios/](ios/) | App iOS nativo (Swift) |
| [android/](android/) | App Android nativo (Kotlin) |
| [backend/](backend/) | API e workers (Node.js + TypeScript) |
| [dashboard/](dashboard/) | Dashboard web do patologista (Next.js — provisório) |
| [infra/](infra/) | Configs Supabase, IaC, templates de secrets |
| [docs/](docs/) | Briefing filtrado, arquitetura, compliance |

## Documentação

Comece por [docs/README.md](docs/README.md).

## Stack

- **Mobile:** Swift (iOS) + Kotlin (Android), nativos
- **Backend:** Node.js + TypeScript
- **BaaS:** Supabase (sa-east-1)
- **Streaming ao vivo:** LiveKit
- **Dashboard:** Next.js + TypeScript

## Compliance

- LGPD (anonimização via UUID, criptografia em repouso, RLS)
- ANVISA RDC 786/2023 (rastreabilidade pré-analítica)
- C2PA + duplo hash SHA-256 + timestamp NTP do Observatório Nacional

Ver [docs/compliance/lgpd-anvisa.md](docs/compliance/lgpd-anvisa.md).
