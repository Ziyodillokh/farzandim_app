-- CreateEnum
CREATE TYPE "IqSessionStatus" AS ENUM ('STARTED', 'IN_PROGRESS', 'COMPLETED', 'ABANDONED');

-- CreateTable
CREATE TABLE "iq_items" (
    "id" TEXT NOT NULL,
    "external_id" TEXT NOT NULL,
    "level" INTEGER NOT NULL,
    "forms" TEXT[],
    "grid_svg" TEXT NOT NULL,
    "options" JSONB NOT NULL,
    "answer" CHAR(1) NOT NULL,
    "b" DOUBLE PRECISION NOT NULL,
    "rule" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "iq_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "iq_sessions" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "level" INTEGER NOT NULL,
    "form" TEXT NOT NULL,
    "age_years" INTEGER NOT NULL,
    "status" "IqSessionStatus" NOT NULL DEFAULT 'STARTED',
    "item_ids" TEXT[],
    "total" INTEGER NOT NULL,
    "first_attempt" BOOLEAN NOT NULL,
    "norm_group" TEXT,
    "result" JSONB,
    "scoring_version" INTEGER,
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMP(3),
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "iq_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "iq_answers" (
    "id" TEXT NOT NULL,
    "session_id" TEXT NOT NULL,
    "item_id" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "choice" CHAR(1) NOT NULL,
    "correct" BOOLEAN NOT NULL,
    "duration_ms" INTEGER,
    "answered_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "iq_answers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "iq_norms" (
    "group" TEXT NOT NULL,
    "n" INTEGER NOT NULL DEFAULT 0,
    "mean" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "m2" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "iq_norms_pkey" PRIMARY KEY ("group")
);

-- CreateIndex
CREATE UNIQUE INDEX "iq_items_external_id_key" ON "iq_items"("external_id");

-- CreateIndex
CREATE INDEX "iq_items_level_active_idx" ON "iq_items"("level", "active");

-- CreateIndex
CREATE INDEX "iq_sessions_child_id_status_completed_at_idx" ON "iq_sessions"("child_id", "status", "completed_at" DESC);

-- CreateIndex
CREATE INDEX "iq_answers_item_id_idx" ON "iq_answers"("item_id");

-- CreateIndex
CREATE UNIQUE INDEX "iq_answers_session_id_item_id_key" ON "iq_answers"("session_id", "item_id");

-- AddForeignKey
ALTER TABLE "iq_sessions" ADD CONSTRAINT "iq_sessions_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "iq_answers" ADD CONSTRAINT "iq_answers_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "iq_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "iq_answers" ADD CONSTRAINT "iq_answers_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "iq_items"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

