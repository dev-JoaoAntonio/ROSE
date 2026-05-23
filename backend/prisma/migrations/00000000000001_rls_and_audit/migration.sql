-- Tele ROSE — Row Level Security + audit log append-only
--
-- Esta migração é manual (não gerada pelo Prisma) e estabelece a camada de
-- segurança LGPD do banco. Roda DEPOIS da migration `00000000000000_init`.
--
-- Princípios:
-- 1. RLS habilitada em TODA tabela com dado clínico ou pessoal.
-- 2. Backend NestJS conecta como `service_role` (Supabase) e BYPASSA RLS,
--    aplicando segurança via Guards/Interceptors do Nest.
-- 3. Apps mobile / dashboard web conectam como `authenticated` (JWT do Supabase)
--    e SÃO afetados por RLS — esse é o cinto de segurança real.
-- 4. `audit_log` rejeita UPDATE e DELETE de qualquer role exceto superuser.
--
-- Funções helper para RLS lendo o JWT do Supabase:
--   auth.uid()       → uuid do usuário autenticado (vem do claim `sub` do JWT)
--   auth.role()      → 'authenticated' | 'anon' | 'service_role'
--   auth.jwt()       → JSON completo do JWT
-- Essas funções existem por padrão no Postgres do Supabase.

-- ============================================================
-- Função helper: lê a role de aplicação (user_profiles.role) do usuário atual.
-- ============================================================
CREATE OR REPLACE FUNCTION public.current_app_role()
RETURNS public.user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.user_profiles WHERE id = auth.uid();
$$;

-- ============================================================
-- Função helper: hospitais aos quais o usuário atual está vinculado (membership ativo).
-- ============================================================
CREATE OR REPLACE FUNCTION public.current_user_hospitals()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT hospital_id FROM public.memberships
   WHERE user_id = auth.uid() AND active = true;
$$;

-- ============================================================
-- Habilitar RLS em todas as tabelas sensíveis
-- ============================================================
ALTER TABLE public.hospitals          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_models      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reagent_batches    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cases              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_assets       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integrity_hashes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_sessions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_reports       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log          ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- USER_PROFILES
-- - Cada usuário lê o próprio perfil.
-- - ADMIN/AUDITOR leem todos.
-- ============================================================
CREATE POLICY user_profiles_self_read ON public.user_profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid()
      OR public.current_app_role() IN ('ADMIN', 'AUDITOR'));

CREATE POLICY user_profiles_admin_write ON public.user_profiles
  FOR ALL TO authenticated
  USING (public.current_app_role() = 'ADMIN')
  WITH CHECK (public.current_app_role() = 'ADMIN');

-- ============================================================
-- HOSPITALS
-- - Usuário lê hospitais aos quais tem membership.
-- - ADMIN lê todos.
-- ============================================================
CREATE POLICY hospitals_member_read ON public.hospitals
  FOR SELECT TO authenticated
  USING (id IN (SELECT public.current_user_hospitals())
      OR public.current_app_role() = 'ADMIN');

CREATE POLICY hospitals_admin_write ON public.hospitals
  FOR ALL TO authenticated
  USING (public.current_app_role() = 'ADMIN')
  WITH CHECK (public.current_app_role() = 'ADMIN');

-- ============================================================
-- MEMBERSHIPS
-- - Usuário lê seus próprios memberships.
-- - ADMIN gerencia todos.
-- ============================================================
CREATE POLICY memberships_self_read ON public.memberships
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()
      OR public.current_app_role() = 'ADMIN');

CREATE POLICY memberships_admin_write ON public.memberships
  FOR ALL TO authenticated
  USING (public.current_app_role() = 'ADMIN')
  WITH CHECK (public.current_app_role() = 'ADMIN');

-- ============================================================
-- DEVICE_MODELS (tabela "de fábrica" — fator µm/pixel)
-- - Qualquer autenticado lê (precisa para calibrar a régua no login).
-- - Só ADMIN escreve.
-- ============================================================
CREATE POLICY device_models_auth_read ON public.device_models
  FOR SELECT TO authenticated USING (true);

CREATE POLICY device_models_admin_write ON public.device_models
  FOR ALL TO authenticated
  USING (public.current_app_role() = 'ADMIN')
  WITH CHECK (public.current_app_role() = 'ADMIN');

-- ============================================================
-- DEVICES (smartphones em campo)
-- - Membros do hospital dono leem.
-- - ADMIN gerencia.
-- ============================================================
CREATE POLICY devices_hospital_read ON public.devices
  FOR SELECT TO authenticated
  USING (hospital_id IN (SELECT public.current_user_hospitals())
      OR public.current_app_role() = 'ADMIN');

CREATE POLICY devices_admin_write ON public.devices
  FOR ALL TO authenticated
  USING (public.current_app_role() = 'ADMIN')
  WITH CHECK (public.current_app_role() = 'ADMIN');

-- ============================================================
-- REAGENT_BATCHES (lotes de corante por hospital — ANVISA)
-- - Membros do hospital leem/escrevem para lotes do próprio hospital.
-- ============================================================
CREATE POLICY reagent_batches_hospital_rw ON public.reagent_batches
  FOR ALL TO authenticated
  USING (hospital_id IN (SELECT public.current_user_hospitals())
      OR public.current_app_role() = 'ADMIN')
  WITH CHECK (hospital_id IN (SELECT public.current_user_hospitals())
           OR public.current_app_role() = 'ADMIN');

-- ============================================================
-- PATIENTS (dado clínico/pessoal SENSÍVEL)
-- - Apenas técnicos/patologistas do hospital de origem leem.
-- - Patologista atribuído a um caso pode ler o paciente daquele caso.
-- - HOSPITAL_DIRECTOR não enxerga dados pessoais (só BI agregado).
-- - AUDITOR NUNCA enxerga (auditoria é sobre acessos, não conteúdo clínico).
-- ============================================================
CREATE POLICY patients_clinical_read ON public.patients
  FOR SELECT TO authenticated
  USING (
    public.current_app_role() IN ('TECNICO', 'PATOLOGISTA')
    AND (
      hospital_id IN (SELECT public.current_user_hospitals())
      OR id IN (SELECT patient_id FROM public.cases WHERE reviewed_by_id = auth.uid())
    )
  );

CREATE POLICY patients_tecnico_insert ON public.patients
  FOR INSERT TO authenticated
  WITH CHECK (
    public.current_app_role() = 'TECNICO'
    AND hospital_id IN (SELECT public.current_user_hospitals())
  );

CREATE POLICY patients_tecnico_update ON public.patients
  FOR UPDATE TO authenticated
  USING (
    public.current_app_role() = 'TECNICO'
    AND hospital_id IN (SELECT public.current_user_hospitals())
  );

-- ============================================================
-- CASES (caso clínico)
-- - Técnico vê casos que ele coletou.
-- - Patologista vê casos atribuídos a ele OU em IN_REVIEW sem atribuição.
-- - Membros do hospital veem casos do hospital, exceto AUDITOR.
-- - HOSPITAL_DIRECTOR vê metadados agregados (view separada, não esta tabela).
-- ============================================================
CREATE POLICY cases_clinical_read ON public.cases
  FOR SELECT TO authenticated
  USING (
    (public.current_app_role() = 'TECNICO' AND collected_by_id = auth.uid())
    OR (public.current_app_role() = 'PATOLOGISTA' AND (reviewed_by_id = auth.uid() OR (status = 'IN_REVIEW' AND reviewed_by_id IS NULL)))
    OR public.current_app_role() = 'ADMIN'
  );

CREATE POLICY cases_tecnico_insert ON public.cases
  FOR INSERT TO authenticated
  WITH CHECK (
    public.current_app_role() = 'TECNICO'
    AND collected_by_id = auth.uid()
    AND hospital_id IN (SELECT public.current_user_hospitals())
  );

CREATE POLICY cases_clinical_update ON public.cases
  FOR UPDATE TO authenticated
  USING (
    (public.current_app_role() = 'TECNICO' AND collected_by_id = auth.uid() AND status IN ('OPENED', 'IN_CAPTURE'))
    OR (public.current_app_role() = 'PATOLOGISTA' AND (reviewed_by_id = auth.uid() OR reviewed_by_id IS NULL))
    OR public.current_app_role() = 'ADMIN'
  );

-- ============================================================
-- MEDIA_ASSETS / INTEGRITY_HASHES / LIVE_SESSIONS / CASE_REPORTS
-- - Herdam o acesso ao caso pai. Quem vê o caso, vê os assets.
-- ============================================================
CREATE POLICY media_assets_via_case_read ON public.media_assets
  FOR SELECT TO authenticated
  USING (case_id IN (SELECT id FROM public.cases));

CREATE POLICY media_assets_tecnico_insert ON public.media_assets
  FOR INSERT TO authenticated
  WITH CHECK (
    public.current_app_role() = 'TECNICO'
    AND case_id IN (SELECT id FROM public.cases WHERE collected_by_id = auth.uid())
  );

CREATE POLICY integrity_hashes_via_case_read ON public.integrity_hashes
  FOR SELECT TO authenticated
  USING (case_id IN (SELECT id FROM public.cases));

CREATE POLICY live_sessions_via_case_read ON public.live_sessions
  FOR SELECT TO authenticated
  USING (case_id IN (SELECT id FROM public.cases));

CREATE POLICY case_reports_via_case_read ON public.case_reports
  FOR SELECT TO authenticated
  USING (case_id IN (SELECT id FROM public.cases));

-- ============================================================
-- AUDIT_LOG — append-only
-- - Authenticated NUNCA escreve direto (escrita é via backend service_role).
-- - AUDITOR e ADMIN leem; demais não.
-- - Qualquer UPDATE/DELETE rejeitado.
-- ============================================================
CREATE POLICY audit_log_read ON public.audit_log
  FOR SELECT TO authenticated
  USING (public.current_app_role() IN ('AUDITOR', 'ADMIN'));

-- Rejeita UPDATE e DELETE para qualquer role autenticado.
-- Trigger garante append-only mesmo se RLS for alterada acidentalmente.
CREATE OR REPLACE FUNCTION public.reject_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'audit_log é append-only — UPDATE/DELETE proibidos';
END;
$$;

CREATE TRIGGER audit_log_block_update
  BEFORE UPDATE ON public.audit_log
  FOR EACH ROW EXECUTE FUNCTION public.reject_audit_mutation();

CREATE TRIGGER audit_log_block_delete
  BEFORE DELETE ON public.audit_log
  FOR EACH ROW EXECUTE FUNCTION public.reject_audit_mutation();

-- ============================================================
-- Realtime: habilitar para a fila de casos (dashboard recebe novos casos).
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.cases;
