-- Sprint 5.x — Admin actions audit log.
-- Har admin amal qaysi moderator, qachon, qaysi resurs ustida bajarganini saqlaydi.
-- Eslatma: mavjud `audit_logs` jadval Parent/Child consumer harakatlari uchun.
-- Bu YANGI jadval — faqat moderator actions uchun.

CREATE TABLE "moderator_audit_logs" (
  "id"            TEXT NOT NULL,
  "moderator_id"  TEXT,
  "email"         TEXT,
  "action"        TEXT NOT NULL,
  "resource_type" TEXT,
  "resource_id"   TEXT,
  "status"        TEXT NOT NULL DEFAULT 'success',
  "ip_address"    TEXT,
  "user_agent"    TEXT,
  "details"       JSONB,
  "created_at"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "moderator_audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "moderator_audit_logs_moderator_id_created_at_idx" ON "moderator_audit_logs"("moderator_id", "created_at" DESC);
CREATE INDEX "moderator_audit_logs_action_created_at_idx" ON "moderator_audit_logs"("action", "created_at" DESC);
CREATE INDEX "moderator_audit_logs_resource_type_resource_id_idx" ON "moderator_audit_logs"("resource_type", "resource_id");
