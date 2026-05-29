-- CreateEnum
CREATE TYPE "PairRequestStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED');

-- CreateTable
CREATE TABLE "child_pair_requests" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "status" "PairRequestStatus" NOT NULL DEFAULT 'PENDING',
    "device_info" JSONB,
    "ip_address" TEXT,
    "user_agent" TEXT,
    "new_user_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMP(3),
    "expires_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "child_pair_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "child_pair_requests_child_id_status_idx" ON "child_pair_requests"("child_id", "status");

-- CreateIndex
CREATE INDEX "child_pair_requests_status_expires_at_idx" ON "child_pair_requests"("status", "expires_at");

-- AddForeignKey
ALTER TABLE "child_pair_requests" ADD CONSTRAINT "child_pair_requests_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
