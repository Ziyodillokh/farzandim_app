-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "NotificationType" ADD VALUE 'STUDY_NUDGE';
ALTER TYPE "NotificationType" ADD VALUE 'HEALTH_NUDGE';
ALTER TYPE "NotificationType" ADD VALUE 'CONTENT_REMINDER';

-- CreateTable
CREATE TABLE "notification_preferences" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "study_nudge" BOOLEAN NOT NULL DEFAULT true,
    "health_nudge" BOOLEAN NOT NULL DEFAULT true,
    "content_reminder" BOOLEAN NOT NULL DEFAULT true,
    "quiet_from" TEXT,
    "quiet_to" TEXT,
    "last_study_nudge_at" TIMESTAMP(3),
    "last_health_nudge_at" TIMESTAMP(3),
    "last_content_reminder_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "notification_preferences_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "notification_preferences_child_id_key" ON "notification_preferences"("child_id");

-- AddForeignKey
ALTER TABLE "notification_preferences" ADD CONSTRAINT "notification_preferences_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
