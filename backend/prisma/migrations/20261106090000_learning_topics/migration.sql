-- Mavzular katalogi: learning_topics + savol / urinishga ixtiyoriy topic_id.
-- FAQAT qo'shimcha (yangi jadval, nullable ustunlar, indekslar): eski ustunlar
-- (learning_questions.topic, learning_attempts.topic) va ma'lumotlarga tegilmaydi.

-- CreateEnum
CREATE TYPE "LearningTopicStatus" AS ENUM ('ACTIVE', 'HIDDEN');

-- AlterTable
ALTER TABLE "learning_questions" ADD COLUMN     "topic_id" TEXT;

-- AlterTable
ALTER TABLE "learning_attempts" ADD COLUMN     "topic_id" TEXT;

-- CreateTable
CREATE TABLE "learning_topics" (
    "id" TEXT NOT NULL,
    "subject" "LearningSubject" NOT NULL,
    "key" TEXT NOT NULL,
    "title" JSONB NOT NULL,
    "goal" JSONB,
    "min_grade" INTEGER NOT NULL,
    "max_grade" INTEGER NOT NULL,
    "position" INTEGER NOT NULL,
    "status" "LearningTopicStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "learning_topics_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "learning_topics_subject_status_position_idx" ON "learning_topics"("subject", "status", "position");

-- CreateIndex
CREATE UNIQUE INDEX "learning_topics_subject_key_key" ON "learning_topics"("subject", "key");

-- CreateIndex
CREATE INDEX "learning_questions_topic_id_status_idx" ON "learning_questions"("topic_id", "status");

-- CreateIndex
CREATE INDEX "learning_attempts_child_id_topic_id_idx" ON "learning_attempts"("child_id", "topic_id");

-- AddForeignKey
ALTER TABLE "learning_questions" ADD CONSTRAINT "learning_questions_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "learning_topics"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning_attempts" ADD CONSTRAINT "learning_attempts_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "learning_topics"("id") ON DELETE SET NULL ON UPDATE CASCADE;

