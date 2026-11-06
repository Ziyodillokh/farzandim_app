-- Kirish (A01–A12), 1-qism: bola login/parol, sessiya sababi, asosiy qurilma va tiklash so'rovlari.
-- FAQAT qo'shuvchi: 3 ta yangi enum, 2 ta yangi jadval (child_credentials, child_recovery_requests),
-- `children`ga 1 ta, `users`ga 1 ta va `user_sessions`ga 4 ta nullable / defaultli ustun. Mavjud qatorlarga
-- tegilmaydi (UPDATE / DELETE yo'q); eski kod ustunlarni ishlatmaydi.

-- CreateEnum
CREATE TYPE "ChildCredentialIssuer" AS ENUM ('PARENT', 'SCHOOL');

-- CreateEnum
CREATE TYPE "ChildRecoveryChannel" AS ENUM ('PARENT', 'SCHOOL');

-- CreateEnum
CREATE TYPE "ChildRecoveryStatus" AS ENUM ('RECEIVED', 'RESTORED', 'REJECTED');

-- AlterTable
ALTER TABLE "children" ADD COLUMN     "education_language" TEXT;

-- AlterTable
ALTER TABLE "user_sessions" ADD COLUMN     "device_id" TEXT,
ADD COLUMN     "is_main" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "kind" TEXT,
ADD COLUMN     "revoked_reason" TEXT;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "created_via" TEXT;

-- CreateTable
CREATE TABLE "child_credentials" (
    "child_id" TEXT NOT NULL,
    "login" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "must_change_password" BOOLEAN NOT NULL DEFAULT true,
    "failed_logins" INTEGER NOT NULL DEFAULT 0,
    "failed_window_started_at" TIMESTAMP(3),
    "locked_until" TIMESTAMP(3),
    "issued_by" "ChildCredentialIssuer" NOT NULL,
    "issued_by_user_id" TEXT,
    "issued_by_staff_id" TEXT,
    "issued_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "password_changed_at" TIMESTAMP(3),
    "last_login_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "child_credentials_pkey" PRIMARY KEY ("child_id")
);

-- CreateTable
CREATE TABLE "child_recovery_requests" (
    "id" TEXT NOT NULL,
    "child_id" TEXT,
    "channel" "ChildRecoveryChannel" NOT NULL,
    "status" "ChildRecoveryStatus" NOT NULL DEFAULT 'RECEIVED',
    "poll_token_hash" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "restored_at" TIMESTAMP(3),
    "signed_out_at" TIMESTAMP(3),
    "rejected_at" TIMESTAMP(3),

    CONSTRAINT "child_recovery_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "child_credentials_login_key" ON "child_credentials"("login");

-- CreateIndex
CREATE INDEX "child_recovery_requests_child_id_status_idx" ON "child_recovery_requests"("child_id", "status");

-- CreateIndex
CREATE INDEX "child_recovery_requests_created_at_idx" ON "child_recovery_requests"("created_at");

-- AddForeignKey
ALTER TABLE "child_credentials" ADD CONSTRAINT "child_credentials_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_recovery_requests" ADD CONSTRAINT "child_recovery_requests_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

