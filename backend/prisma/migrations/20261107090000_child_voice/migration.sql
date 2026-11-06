-- Bola ovozi (Parvoz Growth, 3-faza). FAQAT QO'SHUVCHI: yangi jadvallar va nullable /
-- default'li ustunlar; mavjud qatorlarga tegilmaydi.
--
-- school_care_anon_responses: ATAYLAB o'quvchi / bola ustuni va vaqt belgisi (created_at ...)
-- YO'Q. "Kim javob berdi" faqat school_care_participation'da (javobsiz). Eski
-- school_care_responses jadvali o'zgarmaydi va o'qishda hamon hisobga olinadi.
--
-- Orqaga qaytarish: yangi jadvallarni DROP qilish + qo'shilgan ustunlarni olib tashlash
-- (eski kod ularni ishlatmaydi).

-- AlterTable
ALTER TABLE "school_care_requests" ADD COLUMN     "assigned_staff_id" TEXT,
ADD COLUMN     "client_request_id" TEXT,
ADD COLUMN     "escalated_at" TIMESTAMP(3),
ADD COLUMN     "last_message_at" TIMESTAMP(3),
ADD COLUMN     "opened_at" TIMESTAMP(3),
ADD COLUMN     "opened_by_staff_id" TEXT,
ADD COLUMN     "replied_at" TIMESTAMP(3),
ADD COLUMN     "resolved_at" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "school_psych_assignments" ADD COLUMN     "care_request_id" TEXT,
ADD COLUMN     "student_ids" TEXT[] DEFAULT ARRAY[]::TEXT[];

-- AlterTable
ALTER TABLE "school_staff_notifications" ADD COLUMN     "staff_ids" TEXT[] DEFAULT ARRAY[]::TEXT[];

-- CreateTable
CREATE TABLE "school_care_participation" (
    "id" TEXT NOT NULL,
    "survey_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_care_participation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_care_anon_responses" (
    "id" TEXT NOT NULL,
    "survey_id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "class_id" TEXT,
    "grade" INTEGER NOT NULL,
    "age_group" TEXT NOT NULL,
    "answers_enc" TEXT NOT NULL,

    CONSTRAINT "school_care_anon_responses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_care_messages" (
    "id" TEXT NOT NULL,
    "request_id" TEXT NOT NULL,
    "author" TEXT NOT NULL,
    "staff_id" TEXT,
    "body_enc" TEXT NOT NULL,
    "client_message_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "read_by_child_at" TIMESTAMP(3),
    "read_by_staff_at" TIMESTAMP(3),

    CONSTRAINT "school_care_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_care_settings" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "psychologist_staff_id" TEXT,
    "psychologist_display_name" TEXT,
    "deputy_staff_id" TEXT,
    "deputy_display_name" TEXT,
    "work_days" INTEGER[] DEFAULT ARRAY[1, 2, 3, 4, 5]::INTEGER[],
    "work_start" TEXT NOT NULL DEFAULT '09:00',
    "work_end" TEXT NOT NULL DEFAULT '17:00',
    "urgent_sla_minutes" INTEGER NOT NULL DEFAULT 60,
    "normal_sla_hours" INTEGER NOT NULL DEFAULT 24,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by_staff_id" TEXT,

    CONSTRAINT "school_care_settings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "school_care_participation_student_id_idx" ON "school_care_participation"("student_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_care_participation_survey_id_student_id_key" ON "school_care_participation"("survey_id", "student_id");

-- CreateIndex
CREATE INDEX "school_care_anon_responses_survey_id_idx" ON "school_care_anon_responses"("survey_id");

-- CreateIndex
CREATE INDEX "school_care_anon_responses_school_id_idx" ON "school_care_anon_responses"("school_id");

-- CreateIndex
CREATE INDEX "school_care_messages_request_id_created_at_idx" ON "school_care_messages"("request_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "school_care_messages_request_id_client_message_id_key" ON "school_care_messages"("request_id", "client_message_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_care_settings_school_id_key" ON "school_care_settings"("school_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_care_requests_student_id_client_request_id_key" ON "school_care_requests"("student_id", "client_request_id");

-- AddForeignKey
ALTER TABLE "school_care_participation" ADD CONSTRAINT "school_care_participation_survey_id_fkey" FOREIGN KEY ("survey_id") REFERENCES "school_care_surveys"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_care_anon_responses" ADD CONSTRAINT "school_care_anon_responses_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_care_anon_responses" ADD CONSTRAINT "school_care_anon_responses_survey_id_fkey" FOREIGN KEY ("survey_id") REFERENCES "school_care_surveys"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_care_messages" ADD CONSTRAINT "school_care_messages_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "school_care_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_care_settings" ADD CONSTRAINT "school_care_settings_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

