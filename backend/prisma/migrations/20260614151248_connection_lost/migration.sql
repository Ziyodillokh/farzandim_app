-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'CONNECTION_LOST';

-- AlterTable
ALTER TABLE "children" ADD COLUMN     "connection_lost_notified_at" TIMESTAMP(3);
