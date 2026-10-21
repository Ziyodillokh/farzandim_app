-- Parvoz Kelajak: savollar banki, sessiyalar va javoblar (docs/KELAJAK-REJA.md §2).
-- Faqat yangi enum, jadvallar, indekslar va FK; mavjud jadvallar o'zgarmaydi.

-- CreateEnum
CREATE TYPE "KelajakSessionStatus" AS ENUM ('STARTED', 'IN_PROGRESS', 'COMPLETED', 'ABANDONED');

-- CreateTable
CREATE TABLE "kelajak_questions" (
    "id" TEXT NOT NULL,
    "external_id" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "age_group" TEXT NOT NULL,
    "text" JSONB NOT NULL,
    "answer_type" TEXT NOT NULL,
    "options" JSONB NOT NULL,
    "scoring" JSONB,
    "reverse" BOOLEAN NOT NULL DEFAULT false,
    "required" BOOLEAN NOT NULL DEFAULT true,
    "follow_up" TEXT,
    "notes" TEXT,
    "review_note" TEXT,
    "source_type" TEXT NOT NULL,
    "source_name" TEXT NOT NULL,
    "source_version" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "kelajak_questions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kelajak_sessions" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "age_group" TEXT NOT NULL,
    "day" TEXT NOT NULL,
    "status" "KelajakSessionStatus" NOT NULL DEFAULT 'STARTED',
    "question_ids" TEXT[],
    "total" INTEGER NOT NULL,
    "result" JSONB,
    "scoring_version" INTEGER,
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMP(3),
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "kelajak_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kelajak_answers" (
    "id" TEXT NOT NULL,
    "session_id" TEXT NOT NULL,
    "question_id" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "value" INTEGER,
    "text_enc" TEXT,
    "answered_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "kelajak_answers_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "kelajak_questions_external_id_key" ON "kelajak_questions"("external_id");

-- CreateIndex
CREATE INDEX "kelajak_questions_age_group_active_category_idx" ON "kelajak_questions"("age_group", "active", "category");

-- CreateIndex
CREATE INDEX "kelajak_sessions_child_id_type_day_idx" ON "kelajak_sessions"("child_id", "type", "day");

-- CreateIndex
CREATE INDEX "kelajak_sessions_child_id_status_completed_at_idx" ON "kelajak_sessions"("child_id", "status", "completed_at" DESC);

-- CreateIndex
CREATE INDEX "kelajak_answers_question_id_idx" ON "kelajak_answers"("question_id");

-- CreateIndex
CREATE UNIQUE INDEX "kelajak_answers_session_id_question_id_key" ON "kelajak_answers"("session_id", "question_id");

-- AddForeignKey
ALTER TABLE "kelajak_sessions" ADD CONSTRAINT "kelajak_sessions_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kelajak_answers" ADD CONSTRAINT "kelajak_answers_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "kelajak_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kelajak_answers" ADD CONSTRAINT "kelajak_answers_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "kelajak_questions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
