-- Sprint 6 — P0 monetizatsiya: Subscription modeli.
-- Foydalanuvchining aktiv obunasi. To'lov success bo'lganda yaratiladi/uzaytiriladi.
-- consumer-content plan-gating endi shu jadvaldan o'qiydi (Payment-scan o'rniga).
-- Payment jadvaliga to'lov lifecycle ustunlari qo'shiladi (provider callback uchun).

-- CreateEnum
CREATE TYPE "SubscriptionStatus" AS ENUM ('PENDING', 'ACTIVE', 'EXPIRED', 'CANCELLED');

-- CreateTable
CREATE TABLE "subscriptions" (
  "id"           TEXT NOT NULL,
  "user_id"      TEXT NOT NULL,
  "plan_id"      TEXT,
  "status"       "SubscriptionStatus" NOT NULL DEFAULT 'PENDING',
  "started_at"   TIMESTAMP(3),
  "expires_at"   TIMESTAMP(3),
  "auto_renew"   BOOLEAN NOT NULL DEFAULT false,
  "cancelled_at" TIMESTAMP(3),
  "created_at"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"   TIMESTAMP(3) NOT NULL,

  CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "subscriptions_user_id_status_idx" ON "subscriptions"("user_id", "status");
CREATE INDEX "subscriptions_status_expires_at_idx" ON "subscriptions"("status", "expires_at");

-- AlterTable: payments — to'lov lifecycle ustunlari.
-- updated_at mavjud rowlar uchun DEFAULT bilan qo'shiladi (schema'da @default(now())).
ALTER TABLE "payments"
  ADD COLUMN "subscription_id" TEXT,
  ADD COLUMN "idempotency_key" TEXT,
  ADD COLUMN "provider_data"   JSONB,
  ADD COLUMN "paid_at"         TIMESTAMP(3),
  ADD COLUMN "updated_at"      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- CreateIndex
CREATE UNIQUE INDEX "payments_idempotency_key_key" ON "payments"("idempotency_key");
CREATE INDEX "payments_subscription_id_idx" ON "payments"("subscription_id");

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "plans"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "payments" ADD CONSTRAINT "payments_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "subscriptions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
