# Documentação Tele ROSE

## Estrutura

- [briefing/briefing-filtrado.md](briefing/briefing-filtrado.md) — Briefing original destilado em requisitos reais
- [architecture/arquitetura.md](architecture/arquitetura.md) — Topologia técnica e ordem de construção
- [compliance/lgpd-anvisa.md](compliance/lgpd-anvisa.md) — LGPD, ANVISA RDC 786/2023, cadeia de custódia digital

## Decisões registradas

| Decisão | Status | Onde |
|---|---|---|
| App nativo Swift + Kotlin (sem React Native/Flutter) | Fechada | [arquitetura.md](architecture/arquitetura.md) |
| Backend Node.js + TypeScript | Fechada | [arquitetura.md](architecture/arquitetura.md) |
| Supabase (região São Paulo) como BaaS | Fechada | [arquitetura.md](architecture/arquitetura.md) |
| LiveKit ao lado para streaming ao vivo | Fechada | [arquitetura.md](architecture/arquitetura.md) |
| Adobe Lightroom descartado (captura em app próprio) | Fechada | [briefing-filtrado.md §7](briefing/briefing-filtrado.md) |
| Visão computacional desde o início (OpenCV → YOLO) | Fechada | [briefing-filtrado.md §3.3](briefing/briefing-filtrado.md) |
| Framework do dashboard web | Provisório (Next.js) | [arquitetura.md](architecture/arquitetura.md) |
| Framework HTTP do backend (Fastify vs Express vs Hono) | Aberta | — |
