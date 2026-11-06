-- Men (I07 + I09): bildirishnoma sozlamalari va ma'lumot o'chirish so'rovi.
-- FAQAT qo'shuvchi: notification_preferences'ga 6 ta default'li ustun (mavjud qatorlar default oladi),
-- 2 ta yangi jadval (child_data_deletion_requests, child_push_dedupe). Mavjud qatorlarga tegilmaydi.

-- CreateEnum
CREATE TYPE "ChildDeletionRequestStatus" AS ENUM ('RECEIVED', 'CLOSED');

-- AlterTable
ALTER TABLE "notification_preferences" ADD COLUMN     "daily_reminder" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "daily_reminder_time" TEXT NOT NULL DEFAULT '18:00',
ADD COLUMN     "family_messages" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "hide_text" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "homework_reminder" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "school_announcements" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable
CREATE TABLE "child_data_deletion_requests" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "status" "ChildDeletionRequestStatus" NOT NULL DEFAULT 'RECEIVED',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closed_at" TIMESTAMP(3),

    CONSTRAINT "child_data_deletion_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "child_push_dedupe" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "ref_key" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "child_push_dedupe_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "child_data_deletion_requests_child_id_created_at_idx" ON "child_data_deletion_requests"("child_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "child_push_dedupe_created_at_idx" ON "child_push_dedupe"("created_at");

-- CreateIndex
CREATE UNIQUE INDEX "child_push_dedupe_child_id_kind_ref_key_key" ON "child_push_dedupe"("child_id", "kind", "ref_key");

-- AddForeignKey
ALTER TABLE "child_data_deletion_requests" ADD CONSTRAINT "child_data_deletion_requests_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_push_dedupe" ADD CONSTRAINT "child_push_dedupe_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

