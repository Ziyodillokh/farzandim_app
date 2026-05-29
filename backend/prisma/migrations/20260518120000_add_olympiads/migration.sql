-- CreateTable
CREATE TABLE "olympiads" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "subject" TEXT NOT NULL,
    "age_from" INTEGER NOT NULL,
    "age_to" INTEGER NOT NULL,
    "type" TEXT NOT NULL DEFAULT 'test',
    "difficulty" TEXT NOT NULL DEFAULT 'o''rta',
    "start_time" TIMESTAMP(3) NOT NULL,
    "end_time" TIMESTAMP(3) NOT NULL,
    "duration_min" INTEGER NOT NULL DEFAULT 30,
    "max_attempts" INTEGER NOT NULL DEFAULT 1,
    "xp_reward" INTEGER NOT NULL DEFAULT 50,
    "shuffle_questions" BOOLEAN NOT NULL DEFAULT true,
    "shuffle_answers" BOOLEAN NOT NULL DEFAULT true,
    "hide_results" BOOLEAN NOT NULL DEFAULT false,
    "allow_back" BOOLEAN NOT NULL DEFAULT true,
    "certificate_enabled" BOOLEAN NOT NULL DEFAULT true,
    "status" TEXT NOT NULL DEFAULT 'draft',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "olympiads_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "olympiads_status_idx" ON "olympiads"("status");

-- CreateIndex
CREATE INDEX "olympiads_subject_idx" ON "olympiads"("subject");

-- CreateIndex
CREATE INDEX "olympiads_start_time_idx" ON "olympiads"("start_time");

-- CreateTable
CREATE TABLE "olympiad_questions" (
    "id" TEXT NOT NULL,
    "olympiad_id" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "options" TEXT[],
    "correct_index" INTEGER NOT NULL,
    "points" INTEGER NOT NULL DEFAULT 10,
    "order_idx" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "olympiad_questions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "olympiad_questions_olympiad_id_order_idx_idx" ON "olympiad_questions"("olympiad_id", "order_idx");

-- AddForeignKey
ALTER TABLE "olympiad_questions" ADD CONSTRAINT "olympiad_questions_olympiad_id_fkey" FOREIGN KEY ("olympiad_id") REFERENCES "olympiads"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "olympiad_attempts" (
    "id" TEXT NOT NULL,
    "olympiad_id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finished_at" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'in_progress',
    "score" INTEGER NOT NULL DEFAULT 0,
    "total_points" INTEGER NOT NULL DEFAULT 0,
    "correct_answers" INTEGER NOT NULL DEFAULT 0,
    "questions_total" INTEGER NOT NULL DEFAULT 0,
    "time_sec" INTEGER NOT NULL DEFAULT 0,
    "answers" JSONB NOT NULL DEFAULT '[]',

    CONSTRAINT "olympiad_attempts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "olympiad_attempts_olympiad_id_score_idx" ON "olympiad_attempts"("olympiad_id", "score");

-- CreateIndex
CREATE INDEX "olympiad_attempts_child_id_idx" ON "olympiad_attempts"("child_id");

-- CreateIndex
CREATE UNIQUE INDEX "olympiad_attempts_olympiad_id_child_id_key" ON "olympiad_attempts"("olympiad_id", "child_id");

-- AddForeignKey
ALTER TABLE "olympiad_attempts" ADD CONSTRAINT "olympiad_attempts_olympiad_id_fkey" FOREIGN KEY ("olympiad_id") REFERENCES "olympiads"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "olympiad_attempts" ADD CONSTRAINT "olympiad_attempts_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
