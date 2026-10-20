-- Growth Daily Learning: o'quv profili, savollar banki, urinishlar,
-- javoblar va haftalik hisobot yuborilganligi. Faqat yangi jadvallar.

-- CreateEnum
CREATE TYPE "LearningSubject" AS ENUM ('MATH', 'ENGLISH', 'NATIVE', 'HISTORY', 'BIOLOGY', 'GEOGRAPHY', 'PHYSICS', 'CHEMISTRY', 'INFORMATICS', 'RUSSIAN');

-- CreateEnum
CREATE TYPE "LearningQuestionStatus" AS ENUM ('DRAFT', 'ACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "LearningAttemptStatus" AS ENUM ('IN_PROGRESS', 'COMPLETED', 'ABANDONED');

-- CreateTable
CREATE TABLE "learning_profiles" (
    "child_id" TEXT NOT NULL,
    "grade" INTEGER NOT NULL,
    "subjects" "LearningSubject"[],
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "learning_profiles_pkey" PRIMARY KEY ("child_id")
);

-- CreateTable
CREATE TABLE "learning_questions" (
    "id" TEXT NOT NULL,
    "external_id" TEXT,
    "subject" "LearningSubject" NOT NULL,
    "difficulty" INTEGER NOT NULL,
    "min_grade" INTEGER NOT NULL,
    "max_grade" INTEGER NOT NULL,
    "topic" JSONB NOT NULL,
    "prompt" JSONB NOT NULL,
    "options" JSONB NOT NULL,
    "answer_index" INTEGER NOT NULL,
    "explanation" JSONB NOT NULL,
    "status" "LearningQuestionStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "learning_questions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "learning_attempts" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "subject" "LearningSubject" NOT NULL,
    "day" TEXT NOT NULL,
    "is_daily" BOOLEAN NOT NULL,
    "status" "LearningAttemptStatus" NOT NULL DEFAULT 'IN_PROGRESS',
    "question_ids" TEXT[],
    "topic" JSONB,
    "correct" INTEGER NOT NULL DEFAULT 0,
    "total" INTEGER NOT NULL,
    "xp_earned" INTEGER NOT NULL DEFAULT 0,
    "don_earned" INTEGER NOT NULL DEFAULT 0,
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "learning_attempts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "learning_answers" (
    "id" TEXT NOT NULL,
    "attempt_id" TEXT NOT NULL,
    "question_id" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "selected_index" INTEGER NOT NULL,
    "is_correct" BOOLEAN NOT NULL,
    "answered_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "learning_answers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "learning_report_dispatches" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "week_start" TEXT NOT NULL,
    "sent_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "learning_report_dispatches_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "learning_questions_external_id_key" ON "learning_questions"("external_id");

-- CreateIndex
CREATE INDEX "learning_questions_subject_status_idx" ON "learning_questions"("subject", "status");

-- CreateIndex
CREATE INDEX "learning_attempts_child_id_day_idx" ON "learning_attempts"("child_id", "day");

-- CreateIndex
CREATE INDEX "learning_attempts_child_id_status_completed_at_idx" ON "learning_attempts"("child_id", "status", "completed_at" DESC);

-- CreateIndex
CREATE INDEX "learning_answers_question_id_idx" ON "learning_answers"("question_id");

-- CreateIndex
CREATE UNIQUE INDEX "learning_answers_attempt_id_question_id_key" ON "learning_answers"("attempt_id", "question_id");

-- CreateIndex
CREATE UNIQUE INDEX "learning_report_dispatches_child_id_week_start_key" ON "learning_report_dispatches"("child_id", "week_start");

-- AddForeignKey
ALTER TABLE "learning_profiles" ADD CONSTRAINT "learning_profiles_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning_attempts" ADD CONSTRAINT "learning_attempts_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning_answers" ADD CONSTRAINT "learning_answers_attempt_id_fkey" FOREIGN KEY ("attempt_id") REFERENCES "learning_attempts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning_answers" ADD CONSTRAINT "learning_answers_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "learning_questions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning_report_dispatches" ADD CONSTRAINT "learning_report_dispatches_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
