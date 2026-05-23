# Arquitetura — Tele ROSE

## Topologia geral

```
┌────────────────────┐        ┌────────────────────┐
│  App iOS (Swift)   │        │ App Android (Kotlin)│
│                    │        │                    │
│  - Captura travada │        │  - Captura travada │
│  - OpenCV overlay  │        │  - OpenCV overlay  │
│  - C2PA cliente    │        │  - C2PA cliente    │
└─────────┬──────────┘        └──────────┬─────────┘
          │                              │
          │   ┌──────────────────────────┘
          ▼   ▼
   ┌────────────────────┐        ┌─────────────────────────┐
   │     LiveKit        │◄──────►│  Dashboard Web (Next.js)│
   │  (streaming live)  │        │   - Player ao vivo      │
   └────────────────────┘        │   - Botões veredito     │
                                 │   - PDF + audit log     │
          ┌──────────────────────┴──┐
          ▼                         │
   ┌────────────────────┐           │
   │     Supabase       │◄──────────┘
   │  (SP, sa-east-1)   │
   │  - Auth + RLS      │
   │  - Postgres        │
   │  - Storage         │
   │  - Realtime        │
   └─────────┬──────────┘
             │
             ▼
   ┌────────────────────────────────────────┐
   │  Workers Node/TS (containers)          │
   │  - C2PA injection                      │
   │  - SHA-256 duplo                       │
   │  - NTP timestamp (Observatório Nac.)   │
   │  - Geração PDF c/ marca d'água         │
   │  - Audit log writer                    │
   └────────────────────────────────────────┘
```

## Por que Supabase

- **Auth + Row Level Security:** controle de acesso por linha do banco — ideal para "técnico só vê seus casos, patologista só vê fila dele". Atende LGPD sem código extra.
- **Postgres gerenciado em SP (sa-east-1):** dado de saúde permanece em território brasileiro.
- **Storage + signed URLs:** arquivos finalizados com expiração temporal.
- **Realtime via WebSocket:** notifica o dashboard quando novo caso entra na fila.

## Por que LiveKit ao lado

Supabase Storage não faz streaming RTMP/WebRTC ao vivo. LiveKit é open source, hospedável em nuvem brasileira, e cuida da janela ao vivo (técnico → patologista). Após o procedimento, o vídeo final é arquivado no Supabase Storage.

## Por que workers Node separados

Pipeline de C2PA + duplo hash + carimbo NTP + PDF é **regra de negócio crítica** que precisa de:
- Logging detalhado para auditoria
- Retry com idempotência
- Isolamento de falhas (não pode quebrar o upload do mobile)

Edge Functions do Supabase têm timeout curto e observabilidade limitada — não servem para essa camada.

## Ordem técnica de construção

> Sem rótulo de MVP — o produto é um só. Esta é apenas a sequência de dependências para implementação coerente.

1. **Fundação Supabase:** schema do banco, RLS, auth (técnico, patologista, admin), seed de modelos de aparelho com fator µm/pixel.
2. **App mobile — captura travada:** Swift e Kotlin com câmera customizada, as 4 travas, gravação local + upload pós-procedimento.
3. **Upload pipeline:** worker Node que recebe arquivo, gera Hash 1, injeta C2PA, carimba NTP, persiste metadados.
4. **Dashboard web — fila + player:** lista de casos pendentes (Realtime), player de vídeo/foto, dois botões de veredito.
5. **Veredito + Hash 2 + PDF:** worker que fecha o caso, gera Hash 2, monta PDF com marca d'água e disclaimer, dispara push.
6. **Streaming ao vivo via LiveKit:** captura simultânea do mobile, janela ao vivo no dashboard.
7. **Visão computacional no device:** OpenCV thresholding, contador, barra de adequação.
8. **Audit log + tela de auditoria:** RLS + tabela append-only + relatório.
9. **Rastreabilidade ANVISA:** campos de lote de corante, ID DIPLE II, técnico coletor em cada caso.
10. **Funcionalidades de expansão:** botão de pânico (síncrono), BI para diretoria, HL7/DICOM, YOLO no device.

## Stack por camada

| Camada | Tecnologia |
|---|---|
| App iOS | Swift 5.9+, AVFoundation (câmera), OpenCV-iOS, c2pa-rs binding |
| App Android | Kotlin, CameraX, OpenCV4Android, c2pa-rs binding via JNI |
| Backend API/workers | Node.js 20 LTS, TypeScript, Fastify (a confirmar), BullMQ (filas) |
| BaaS | Supabase (sa-east-1) |
| Streaming ao vivo | LiveKit (self-hosted ou cloud) |
| Dashboard web | Next.js 14+ (App Router), TypeScript, Tailwind |
| Geração PDF | pdf-lib (Node) |
| C2PA | c2pa-node ou c2pa-rs |
| Filas/jobs | BullMQ + Redis |
