-- Jonli eshitish sessiyalari — FAQAT metadata (ovoz saqlanmaydi).
-- Ovoz WebRTC P2P orqali o'tadi, serverga tegmaydi.

CREATE TYPE "ListenSessionStatus" AS ENUM ('PENDING', 'ACTIVE', 'ENDED', 'EXPIRED');

CREATE TABLE "listen_sessions" (
    "id" TEXT NOT NULL,
    "parent_id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "status" "ListenSessionStatus" NOT NULL DEFAULT 'PENDING',
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ended_at" TIMESTAMP(3),
    "ended_by" TEXT,
    "expires_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "listen_sessions_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "listen_sessions_child_id_status_idx" ON "listen_sessions"("child_id", "status");
CREATE INDEX "listen_sessions_parent_id_started_at_idx" ON "listen_sessions"("parent_id", "started_at");

ALTER TABLE "listen_sessions" ADD CONSTRAINT "listen_sessions_parent_id_fkey"
  FOREIGN KEY ("parent_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "listen_sessions" ADD CONSTRAINT "listen_sessions_child_id_fkey"
  FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
