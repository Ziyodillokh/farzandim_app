-- Session access request: ota-ona akaunti 2-qurilma limiti (3-qurilma kirish so'rovi)

-- CreateEnum
CREATE TYPE "SessionAccessStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED');

-- CreateTable
CREATE TABLE "session_access_requests" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "status" "SessionAccessStatus" NOT NULL DEFAULT 'PENDING',
    "poll_token" TEXT NOT NULL,
    "device_model" TEXT,
    "platform" TEXT,
    "ip_address" TEXT,
    "user_agent" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMP(3),
    "consumed_at" TIMESTAMP(3),
    "expires_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "session_access_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "session_access_requests_user_id_status_idx" ON "session_access_requests"("user_id", "status");

-- CreateIndex
CREATE INDEX "session_access_requests_status_expires_at_idx" ON "session_access_requests"("status", "expires_at");

-- AddForeignKey
ALTER TABLE "session_access_requests" ADD CONSTRAINT "session_access_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
