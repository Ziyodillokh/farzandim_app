-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "NotificationType" ADD VALUE 'UNLOCK_REQUEST';
ALTER TYPE "NotificationType" ADD VALUE 'UNLOCK_DECISION';

-- CreateTable
CREATE TABLE "unlock_requests" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "package_name" TEXT,
    "kind" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "granted_minutes" INTEGER,
    "requested_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMP(3),
    "expires_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "unlock_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "unlock_requests_child_id_status_idx" ON "unlock_requests"("child_id", "status");

-- CreateIndex
CREATE INDEX "unlock_requests_status_expires_at_idx" ON "unlock_requests"("status", "expires_at");

-- AddForeignKey
ALTER TABLE "unlock_requests" ADD CONSTRAINT "unlock_requests_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
