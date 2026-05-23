Loaded Prisma config from prisma.config.ts.

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "hospital_contract_status" AS ENUM ('PILOT', 'ACTIVE', 'SUSPENDED', 'TERMINATED');

-- CreateEnum
CREATE TYPE "user_role" AS ENUM ('TECNICO', 'PATOLOGISTA', 'ADMIN', 'AUDITOR', 'HOSPITAL_DIRECTOR');

-- CreateEnum
CREATE TYPE "device_platform" AS ENUM ('IOS', 'ANDROID');

-- CreateEnum
CREATE TYPE "device_status" AS ENUM ('ACTIVE', 'MAINTENANCE', 'RETIRED');

-- CreateEnum
CREATE TYPE "case_status" AS ENUM ('OPENED', 'IN_CAPTURE', 'IN_REVIEW', 'VERDICT_ISSUED', 'CLOSED');

-- CreateEnum
CREATE TYPE "case_verdict" AS ENUM ('SATISFATORIA', 'INSATISFATORIA');

-- CreateEnum
CREATE TYPE "media_kind" AS ENUM ('PHOTO', 'ZSTACK', 'VIDEO', 'LIVE_RECORDING');

-- CreateEnum
CREATE TYPE "integrity_hash_kind" AS ENUM ('INGEST', 'SEAL');

-- CreateEnum
CREATE TYPE "audit_action" AS ENUM ('LOGIN', 'LOGOUT', 'CASE_OPEN', 'CASE_VIEW', 'CASE_UPDATE', 'MEDIA_UPLOAD', 'MEDIA_VIEW', 'VERDICT_ISSUED', 'REPORT_GENERATED', 'REPORT_DOWNLOAD', 'PATIENT_EXPORT', 'ROLE_GRANTED', 'ROLE_REVOKED');

-- CreateTable
CREATE TABLE "hospitals" (
    "id" UUID NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "cnpj" VARCHAR(14) NOT NULL,
    "city" VARCHAR(80) NOT NULL,
    "state" VARCHAR(2) NOT NULL,
    "contractStatus" "hospital_contract_status" NOT NULL DEFAULT 'PILOT',
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "hospitals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_profiles" (
    "id" UUID NOT NULL,
    "fullName" VARCHAR(160) NOT NULL,
    "cpf" VARCHAR(11) NOT NULL,
    "professionalRegistry" VARCHAR(40),
    "role" "user_role" NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "user_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "memberships" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "hospitalId" UUID NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "memberships_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "device_models" (
    "id" UUID NOT NULL,
    "manufacturer" VARCHAR(40) NOT NULL,
    "model" VARCHAR(80) NOT NULL,
    "platform" "device_platform" NOT NULL,
    "micronsPerPixel" DECIMAL(8,6) NOT NULL,
    "calibratedAt" TIMESTAMPTZ(6) NOT NULL,
    "calibratedBy" UUID NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_models_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "devices" (
    "id" UUID NOT NULL,
    "serial" VARCHAR(80) NOT NULL,
    "modelId" UUID NOT NULL,
    "hospitalId" UUID NOT NULL,
    "dipleSerial" VARCHAR(80) NOT NULL,
    "status" "device_status" NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "devices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reagent_batches" (
    "id" UUID NOT NULL,
    "hospitalId" UUID NOT NULL,
    "batchCode" VARCHAR(80) NOT NULL,
    "reagentName" VARCHAR(120) NOT NULL,
    "manufacturer" VARCHAR(120) NOT NULL,
    "expiresAt" DATE NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reagent_batches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "patients" (
    "id" UUID NOT NULL,
    "hospitalId" UUID NOT NULL,
    "externalRecordNumber" VARCHAR(80),
    "fullName" VARCHAR(200) NOT NULL,
    "cpf" VARCHAR(11) NOT NULL,
    "birthDate" DATE NOT NULL,
    "contactPhone" VARCHAR(20),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "patients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cases" (
    "id" UUID NOT NULL,
    "caseNumber" VARCHAR(20) NOT NULL,
    "patientId" UUID NOT NULL,
    "hospitalId" UUID NOT NULL,
    "deviceId" UUID NOT NULL,
    "reagentBatchId" UUID NOT NULL,
    "collectedById" UUID NOT NULL,
    "reviewedById" UUID,
    "anatomicSite" VARCHAR(120) NOT NULL,
    "clinicalIndication" TEXT,
    "status" "case_status" NOT NULL DEFAULT 'OPENED',
    "verdict" "case_verdict",
    "verdictNotes" TEXT,
    "geoLat" DECIMAL(10,7),
    "geoLng" DECIMAL(10,7),
    "openedAtNtp" TIMESTAMPTZ(6) NOT NULL,
    "capturedAtNtp" TIMESTAMPTZ(6),
    "reviewedAtNtp" TIMESTAMPTZ(6),
    "closedAtNtp" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cases_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "media_assets" (
    "id" UUID NOT NULL,
    "caseId" UUID NOT NULL,
    "kind" "media_kind" NOT NULL,
    "storagePath" VARCHAR(500) NOT NULL,
    "mimeType" VARCHAR(80) NOT NULL,
    "sizeBytes" BIGINT NOT NULL,
    "durationMs" INTEGER,
    "widthPx" INTEGER,
    "heightPx" INTEGER,
    "iso" INTEGER,
    "shutterUs" INTEGER,
    "whiteBalanceK" INTEGER,
    "focusLocked" BOOLEAN NOT NULL DEFAULT false,
    "c2paManifest" JSONB,
    "capturedAtNtp" TIMESTAMPTZ(6) NOT NULL,
    "uploadedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "media_assets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "integrity_hashes" (
    "id" UUID NOT NULL,
    "caseId" UUID NOT NULL,
    "mediaAssetId" UUID,
    "kind" "integrity_hash_kind" NOT NULL,
    "sha256" CHAR(64) NOT NULL,
    "algorithm" VARCHAR(20) NOT NULL DEFAULT 'SHA-256',
    "computedAtNtp" TIMESTAMPTZ(6) NOT NULL,
    "computedBy" VARCHAR(80) NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "integrity_hashes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "live_sessions" (
    "id" UUID NOT NULL,
    "caseId" UUID NOT NULL,
    "livekitRoom" VARCHAR(120) NOT NULL,
    "livekitToken" VARCHAR(500),
    "startedAtNtp" TIMESTAMPTZ(6) NOT NULL,
    "endedAtNtp" TIMESTAMPTZ(6),
    "participantCount" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "live_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "case_reports" (
    "id" UUID NOT NULL,
    "caseId" UUID NOT NULL,
    "storagePath" VARCHAR(500) NOT NULL,
    "sealHash" CHAR(64) NOT NULL,
    "issuedAtNtp" TIMESTAMPTZ(6) NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "case_reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_log" (
    "id" BIGSERIAL NOT NULL,
    "occurredAtNtp" TIMESTAMPTZ(6) NOT NULL,
    "actorId" UUID,
    "actorRole" "user_role",
    "action" "audit_action" NOT NULL,
    "resourceType" VARCHAR(60) NOT NULL,
    "resourceId" UUID,
    "ip" INET,
    "userAgent" VARCHAR(400),
    "metadata" JSONB,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_log_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "hospitals_cnpj_key" ON "hospitals"("cnpj");

-- CreateIndex
CREATE UNIQUE INDEX "user_profiles_cpf_key" ON "user_profiles"("cpf");

-- CreateIndex
CREATE INDEX "memberships_hospitalId_idx" ON "memberships"("hospitalId");

-- CreateIndex
CREATE UNIQUE INDEX "memberships_userId_hospitalId_key" ON "memberships"("userId", "hospitalId");

-- CreateIndex
CREATE UNIQUE INDEX "device_models_manufacturer_model_key" ON "device_models"("manufacturer", "model");

-- CreateIndex
CREATE UNIQUE INDEX "devices_serial_key" ON "devices"("serial");

-- CreateIndex
CREATE INDEX "devices_hospitalId_idx" ON "devices"("hospitalId");

-- CreateIndex
CREATE INDEX "reagent_batches_hospitalId_active_idx" ON "reagent_batches"("hospitalId", "active");

-- CreateIndex
CREATE UNIQUE INDEX "reagent_batches_hospitalId_batchCode_key" ON "reagent_batches"("hospitalId", "batchCode");

-- CreateIndex
CREATE INDEX "patients_hospitalId_idx" ON "patients"("hospitalId");

-- CreateIndex
CREATE UNIQUE INDEX "cases_caseNumber_key" ON "cases"("caseNumber");

-- CreateIndex
CREATE INDEX "cases_hospitalId_status_idx" ON "cases"("hospitalId", "status");

-- CreateIndex
CREATE INDEX "cases_reviewedById_status_idx" ON "cases"("reviewedById", "status");

-- CreateIndex
CREATE INDEX "cases_status_openedAtNtp_idx" ON "cases"("status", "openedAtNtp");

-- CreateIndex
CREATE INDEX "media_assets_caseId_idx" ON "media_assets"("caseId");

-- CreateIndex
CREATE INDEX "integrity_hashes_caseId_idx" ON "integrity_hashes"("caseId");

-- CreateIndex
CREATE INDEX "integrity_hashes_sha256_idx" ON "integrity_hashes"("sha256");

-- CreateIndex
CREATE INDEX "live_sessions_caseId_idx" ON "live_sessions"("caseId");

-- CreateIndex
CREATE UNIQUE INDEX "case_reports_caseId_key" ON "case_reports"("caseId");

-- CreateIndex
CREATE INDEX "audit_log_occurredAtNtp_idx" ON "audit_log"("occurredAtNtp");

-- CreateIndex
CREATE INDEX "audit_log_actorId_occurredAtNtp_idx" ON "audit_log"("actorId", "occurredAtNtp");

-- CreateIndex
CREATE INDEX "audit_log_resourceType_resourceId_idx" ON "audit_log"("resourceType", "resourceId");

-- AddForeignKey
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_userId_fkey" FOREIGN KEY ("userId") REFERENCES "user_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_hospitalId_fkey" FOREIGN KEY ("hospitalId") REFERENCES "hospitals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "devices" ADD CONSTRAINT "devices_modelId_fkey" FOREIGN KEY ("modelId") REFERENCES "device_models"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "devices" ADD CONSTRAINT "devices_hospitalId_fkey" FOREIGN KEY ("hospitalId") REFERENCES "hospitals"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reagent_batches" ADD CONSTRAINT "reagent_batches_hospitalId_fkey" FOREIGN KEY ("hospitalId") REFERENCES "hospitals"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "patients" ADD CONSTRAINT "patients_hospitalId_fkey" FOREIGN KEY ("hospitalId") REFERENCES "hospitals"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cases" ADD CONSTRAINT "cases_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "patients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cases" ADD CONSTRAINT "cases_hospitalId_fkey" FOREIGN KEY ("hospitalId") REFERENCES "hospitals"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cases" ADD CONSTRAINT "cases_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cases" ADD CONSTRAINT "cases_reagentBatchId_fkey" FOREIGN KEY ("reagentBatchId") REFERENCES "reagent_batches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cases" ADD CONSTRAINT "cases_collectedById_fkey" FOREIGN KEY ("collectedById") REFERENCES "user_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cases" ADD CONSTRAINT "cases_reviewedById_fkey" FOREIGN KEY ("reviewedById") REFERENCES "user_profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_caseId_fkey" FOREIGN KEY ("caseId") REFERENCES "cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "integrity_hashes" ADD CONSTRAINT "integrity_hashes_caseId_fkey" FOREIGN KEY ("caseId") REFERENCES "cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "integrity_hashes" ADD CONSTRAINT "integrity_hashes_mediaAssetId_fkey" FOREIGN KEY ("mediaAssetId") REFERENCES "media_assets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_sessions" ADD CONSTRAINT "live_sessions_caseId_fkey" FOREIGN KEY ("caseId") REFERENCES "cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "case_reports" ADD CONSTRAINT "case_reports_caseId_fkey" FOREIGN KEY ("caseId") REFERENCES "cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_log" ADD CONSTRAINT "audit_log_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "user_profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

