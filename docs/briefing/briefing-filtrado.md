# Briefing Filtrado — Tele ROSE

> Este documento é o destilado do briefing original (mensagens longas geradas por IA, repassadas pelo chefe). Foi filtrado para conter apenas **requisitos funcionais, restrições reais e decisões já tomadas**. Argumentação comercial, modelagem societária e marketing foram removidos.

---

## 1. Produto

- **Nome:** Tele ROSE (também referido como LABMOB).
- **Domínio:** Telepatologia.
- **Procedimento alvo:** Avaliação celular Rapid On-Site Evaluation (ROSE) durante punção por agulha fina (PAAF).
- **Objetivo clínico:** Permitir que um patologista central em Brasília valide a adequação celular de uma amostra **em tempo real**, enquanto o paciente ainda está na maca em um hospital remoto, evitando repunção.

---

## 2. Fluxo central

1. Técnico no hospital acopla a lente **DIPLE II** (óptica fixa da SmartMicroOptics, parceiro Andrea Antonini na Itália) ao smartphone homologado.
2. Captura foto e/ou vídeo da lâmina recém-coletada.
3. Streaming ao vivo + gravação local de fallback → backend central em Brasília.
4. Patologista central recebe alerta, revisa pelo dashboard, emite veredito:
   - **Satisfatória** → libera paciente, dispara PDF com marca d'água para o hospital.
   - **Insatisfatória** → caixa de texto obrigatória com orientação ao técnico (ex: "Faltam células foliculares, repetir punção na borda do nódulo").
5. Caso é selado com hash criptográfico final.

---

## 3. Requisitos do app mobile (iOS Swift + Android Kotlin)

### 3.1 Travas de captura padronizadas (regra LABMOB PRO)

A imagem que chega ao patologista deve ser idêntica independente do modelo de aparelho. O app trava:

1. **Exposição (ISO/Shutter):** sem compensação automática.
2. **White Balance:** temperatura de cor (Kelvin) fixa, calibrada para a LED do DIPLE II.
3. **Foco manual:** travado na distância focal da lente DIPLE II.
4. **Resolução máxima:** sensor em full resolution, sem compressão automática.
5. **Streaming + gravação local simultânea:** streaming a 30fps, gravação local na máxima taxa de quadros possível. Se a internet cair, o arquivo local é sincronizado depois.

### 3.2 Calibração automática por modelo (sem intervenção do usuário)

- Tabela de fábrica no backend mapeia `modelo_aparelho → fator_µm_por_pixel`.
- No login, o app detecta o modelo (User-Agent / Device Info), puxa o fator e injeta a régua digital correta.
- Calibração das 18 unidades piloto é feita uma única vez no escritório central, usando lâmina micrométrica física.

### 3.3 Visão computacional em tempo real (no device)

Overlay sobre o vídeo durante a captura:

- **Bounding boxes** ao redor de grumos celulares detectados.
- **Contador dinâmico** de células viáveis no canto da tela.
- **Barra/termômetro de adequação** (0% → 100%), com alerta visual/sonoro ao bater "Amostra adequada atingida".
- **Aviso de área inadequada** (sangue, necrose) quando aplicável.

**Abordagem inicial:** OpenCV — thresholding por cor (núcleos roxos sobre fundo claro) + medição de tamanho de contorno. Roda no device, sem dependência de internet.
**Evolução futura:** modelo YOLO treinado com dataset anotado de lâminas de PAAF.

---

## 4. Pipeline de segurança e integridade

### 4.1 C2PA (Coalition for Content Provenance and Authenticity)
Metadados criptografados injetados no arquivo no momento da captura: modelo do smartphone, ID do DIPLE II, geolocalização do hospital, prova de "não-alteração por IA/edição".

### 4.2 Duplo Hash SHA-256
- **Hash 1 (entrada):** gerado no upload do arquivo bruto.
- **Hash 2 (fechamento):** gerado quando o patologista emite veredito; combina imagem + decisão.
- Qualquer alteração futura no arquivo quebra o hash → evidência de violação.

### 4.3 Timestamp NTP
- Sincronização obrigatória com servidores NTP do Observatório Nacional (horário oficial de Brasília).
- Impede que o usuário altere o relógio local para forjar Turnaround Time (TAT).

### 4.4 Anonimização LGPD
- Nomes de arquivo em UUID v4 — nunca contém nome ou CPF.
- Dados sensíveis (nome, CPF, prontuário) **criptografados em repouso** no banco.
- Associação UUID ↔ paciente real só dentro do banco, com Row Level Security.

### 4.5 Audit log
- Todo acesso a imagem/caso registrado: quem abriu, quando, por quanto tempo.
- Imutável (append-only). Disponível para fiscalização.

---

## 5. Dashboard do patologista (web)

### 5.1 Tela do veredito
```
[ALERTAS: Nova PAAF Pendente] → [Abrir Prontuário] → [Assistir Streaming/Vídeo C2PA]
                                                              │
                          ┌───────────────────────────────────┘
                          ▼
                [PAINEL DE VEREDITO (Obrigatório)]
                          │
            ┌─────────────┴──────────────┐
            ▼                            ▼
    [ AMOSTRA SATISFATÓRIA ]      [ AMOSTRA INSATISFATÓRIA ]
    → Gera PDF c/ marca d'água    → Caixa de texto obrigatória
    → Push notification hospital  → Orientação técnica ao coletor
```

### 5.2 Disclaimer jurídico fixo
Texto obrigatório em rodapé do dashboard e em todo PDF exportado:

> *"Avaliação restrita à adequação celular (ROSE). Não substitui o exame histopatológico definitivo."*

### 5.3 Rastreabilidade ANVISA (RDC 786/2023)
Cada caso registra: técnico coletor, lote do corante, ID do dispositivo DIPLE II usado, horário NTP de cada etapa.

---

## 6. Funcionalidades adicionais (a planejar ordem técnica)

- **"Botão de pânico"** — abre teleconsulta síncrona ao vivo (vídeo + áudio) entre técnico e patologista central.
- **Dashboard BI para diretoria do hospital** — métricas mensais (procedimentos realizados, repunções evitadas, TAT médio).
- **IA de pré-classificação de urgência** — analisa critérios de suspeita de malignidade e prioriza a fila do patologista.
- **Integração HL7 / DICOM** com sistemas hospitalares (TASY, MV, Philips) — paciente cadastrado no hospital flui direto, sem redigitação.

---

## 7. Itens descartados do briefing original

| Item proposto | Motivo do descarte |
|---|---|
| Usar **Adobe Lightroom Mobile** como ferramenta de captura | Lightroom não permite travar programaticamente exposição/WB/foco a partir de um app externo. App nativo próprio é o único caminho técnico para garantir as travas do LABMOB PRO. |

---

## 8. Itens fora do escopo de software

Todo o conteúdo do briefing referente a **modelo SaaS, precificação (R$ 2,5k–4,5k/mês), divisão de equity (25/25/25/25), sociedade com Andrea/Deeple/Huron/Dr. Clóvis, argumentação comercial vs concorrência** foi tratado como contexto de negócio e **não** integra os requisitos técnicos do sistema.
