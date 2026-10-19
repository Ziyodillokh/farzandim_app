-- Parvoz School (2-to'lqin): xabarlar, School Mode, g'amxo'rlik, psixologik
-- testlar, xodim bildirishnomalari, maktab topshiriqlari. Faqat yangi jadvallar.

-- CreateEnum
CREATE TYPE "SchoolMessageStatus" AS ENUM ('DRAFT', 'SCHEDULED', 'SENT');

-- CreateTable
CREATE TABLE "school_announcements" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "audience" JSONB NOT NULL,
    "priority" TEXT NOT NULL DEFAULT 'NORMAL',
    "status" "SchoolMessageStatus" NOT NULL DEFAULT 'DRAFT',
    "scheduled_at" TIMESTAMP(3),
    "sent_at" TIMESTAMP(3),
    "by_staff_id" TEXT NOT NULL,
    "recipients" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_announcements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_announcement_deliveries" (
    "id" TEXT NOT NULL,
    "announcement_id" TEXT NOT NULL,
    "guardian_id" TEXT NOT NULL,
    "user_id" TEXT,
    "delivered_at" TIMESTAMP(3),
    "read_at" TIMESTAMP(3),

    CONSTRAINT "school_announcement_deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_reminders" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "audience" JSONB NOT NULL,
    "send_at" TIMESTAMP(3) NOT NULL,
    "repeat" TEXT NOT NULL DEFAULT 'NONE',
    "active" BOOLEAN NOT NULL DEFAULT true,
    "by_staff_id" TEXT NOT NULL,
    "last_sent_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_reminders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_payment_reminders" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "guardian_id" TEXT NOT NULL,
    "student_ids" TEXT[],
    "next_date" TEXT NOT NULL,
    "prepaid_months" INTEGER NOT NULL DEFAULT 0,
    "paused" BOOLEAN NOT NULL DEFAULT false,
    "history" JSONB NOT NULL DEFAULT '[]',
    "last_sent_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_payment_reminders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_verification_requests" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "guardian_id" TEXT NOT NULL,
    "payment_reminder_id" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "answer" TEXT,
    "answered_by_staff_id" TEXT,
    "answered_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_verification_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_mode_policies" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "blocked_categories" TEXT[],
    "allowed_apps" JSONB NOT NULL DEFAULT '[]',
    "shift_ids" TEXT[],
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "relax_during_breaks" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_mode_policies_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_mode_exceptions" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "class_id" TEXT,
    "from" TIMESTAMP(3) NOT NULL,
    "until" TIMESTAMP(3) NOT NULL,
    "reason" TEXT NOT NULL,
    "by_staff_id" TEXT NOT NULL,
    "revoked_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_mode_exceptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_emergencies" (
    "school_id" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT false,
    "scope" TEXT NOT NULL DEFAULT 'SCHOOL',
    "class_ids" TEXT[],
    "reason" TEXT NOT NULL DEFAULT '',
    "by_staff_id" TEXT,
    "at" TIMESTAMP(3),
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_emergencies_pkey" PRIMARY KEY ("school_id")
);

-- CreateTable
CREATE TABLE "school_care_questions" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "topic" TEXT NOT NULL,
    "age_groups" TEXT[],
    "text" JSONB NOT NULL,
    "reverse" BOOLEAN NOT NULL DEFAULT false,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_care_questions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_care_surveys" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "week_start" TEXT NOT NULL,
    "age_groups" TEXT[],
    "question_ids" TEXT[],
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "invited" INTEGER NOT NULL DEFAULT 0,
    "activated_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_care_surveys_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_care_responses" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "survey_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "class_id" TEXT,
    "grade" INTEGER NOT NULL,
    "answers_enc" TEXT NOT NULL,
    "submitted_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_care_responses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_care_requests" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "class_id" TEXT,
    "topic" TEXT NOT NULL,
    "message_enc" TEXT NOT NULL,
    "urgency" TEXT NOT NULL DEFAULT 'NORMAL',
    "status" TEXT NOT NULL DEFAULT 'NEW',
    "meeting_at" TIMESTAMP(3),
    "notes_enc" TEXT,
    "protocol_activated" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_care_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_psych_tests" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "definition" JSONB NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "created_by" TEXT,
    "based_on" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_psych_tests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_psych_template_states" (
    "school_id" TEXT NOT NULL,
    "template_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PUBLISHED',
    "norms" JSONB,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_psych_template_states_pkey" PRIMARY KEY ("school_id","template_id")
);

-- CreateTable
CREATE TABLE "school_psych_assignments" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "test_id" TEXT NOT NULL,
    "test_version" INTEGER NOT NULL,
    "target" JSONB NOT NULL,
    "class_ids" TEXT[],
    "opens_at" TIMESTAMP(3) NOT NULL,
    "closes_at" TIMESTAMP(3) NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "invited" INTEGER NOT NULL DEFAULT 0,
    "consent" TEXT NOT NULL DEFAULT 'PARENTS_INFORMED',
    "created_by" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_psych_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_psych_results" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "class_id" TEXT,
    "grade" INTEGER NOT NULL,
    "age_band" TEXT NOT NULL,
    "test_id" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "assignment_id" TEXT,
    "taken_at" TIMESTAMP(3) NOT NULL,
    "origin" TEXT NOT NULL,
    "raw" JSONB NOT NULL,
    "answers_enc" TEXT,
    "duration_sec" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_psych_results_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_staff_notifications" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "roles" TEXT[],
    "class_ids" TEXT[],
    "params" JSONB NOT NULL DEFAULT '{}',
    "subject" JSONB,
    "href" TEXT,

    CONSTRAINT "school_staff_notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_notification_reads" (
    "staff_id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "read_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_notification_reads_pkey" PRIMARY KEY ("staff_id","key")
);

-- CreateTable
CREATE TABLE "school_learning_assignments" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "material_kind" TEXT NOT NULL,
    "material_id" TEXT NOT NULL,
    "class_ids" TEXT[],
    "due_date" TEXT NOT NULL,
    "note" TEXT NOT NULL DEFAULT '',
    "by_staff_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_learning_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "school_announcements_school_id_status_idx" ON "school_announcements"("school_id", "status");

-- CreateIndex
CREATE INDEX "school_announcements_status_scheduled_at_idx" ON "school_announcements"("status", "scheduled_at");

-- CreateIndex
CREATE INDEX "school_announcement_deliveries_user_id_idx" ON "school_announcement_deliveries"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_announcement_deliveries_announcement_id_guardian_id_key" ON "school_announcement_deliveries"("announcement_id", "guardian_id");

-- CreateIndex
CREATE INDEX "school_reminders_school_id_idx" ON "school_reminders"("school_id");

-- CreateIndex
CREATE INDEX "school_reminders_active_send_at_idx" ON "school_reminders"("active", "send_at");

-- CreateIndex
CREATE INDEX "school_payment_reminders_school_id_next_date_idx" ON "school_payment_reminders"("school_id", "next_date");

-- CreateIndex
CREATE UNIQUE INDEX "school_payment_reminders_school_id_guardian_id_key" ON "school_payment_reminders"("school_id", "guardian_id");

-- CreateIndex
CREATE INDEX "school_verification_requests_school_id_status_idx" ON "school_verification_requests"("school_id", "status");

-- CreateIndex
CREATE INDEX "school_mode_policies_school_id_idx" ON "school_mode_policies"("school_id");

-- CreateIndex
CREATE INDEX "school_mode_exceptions_school_id_until_idx" ON "school_mode_exceptions"("school_id", "until");

-- CreateIndex
CREATE INDEX "school_mode_exceptions_student_id_idx" ON "school_mode_exceptions"("student_id");

-- CreateIndex
CREATE INDEX "school_care_questions_school_id_idx" ON "school_care_questions"("school_id");

-- CreateIndex
CREATE INDEX "school_care_surveys_school_id_status_idx" ON "school_care_surveys"("school_id", "status");

-- CreateIndex
CREATE INDEX "school_care_responses_school_id_survey_id_idx" ON "school_care_responses"("school_id", "survey_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_care_responses_survey_id_student_id_key" ON "school_care_responses"("survey_id", "student_id");

-- CreateIndex
CREATE INDEX "school_care_requests_school_id_status_idx" ON "school_care_requests"("school_id", "status");

-- CreateIndex
CREATE INDEX "school_care_requests_student_id_idx" ON "school_care_requests"("student_id");

-- CreateIndex
CREATE INDEX "school_psych_tests_school_id_status_idx" ON "school_psych_tests"("school_id", "status");

-- CreateIndex
CREATE INDEX "school_psych_assignments_school_id_status_idx" ON "school_psych_assignments"("school_id", "status");

-- CreateIndex
CREATE INDEX "school_psych_results_school_id_test_id_idx" ON "school_psych_results"("school_id", "test_id");

-- CreateIndex
CREATE INDEX "school_psych_results_student_id_taken_at_idx" ON "school_psych_results"("student_id", "taken_at" DESC);

-- CreateIndex
CREATE INDEX "school_staff_notifications_school_id_at_idx" ON "school_staff_notifications"("school_id", "at" DESC);

-- CreateIndex
CREATE INDEX "school_learning_assignments_school_id_due_date_idx" ON "school_learning_assignments"("school_id", "due_date");

-- AddForeignKey
ALTER TABLE "school_announcements" ADD CONSTRAINT "school_announcements_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_announcement_deliveries" ADD CONSTRAINT "school_announcement_deliveries_announcement_id_fkey" FOREIGN KEY ("announcement_id") REFERENCES "school_announcements"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_reminders" ADD CONSTRAINT "school_reminders_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_payment_reminders" ADD CONSTRAINT "school_payment_reminders_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_verification_requests" ADD CONSTRAINT "school_verification_requests_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_verification_requests" ADD CONSTRAINT "school_verification_requests_payment_reminder_id_fkey" FOREIGN KEY ("payment_reminder_id") REFERENCES "school_payment_reminders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_mode_policies" ADD CONSTRAINT "school_mode_policies_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_mode_exceptions" ADD CONSTRAINT "school_mode_exceptions_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_emergencies" ADD CONSTRAINT "school_emergencies_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_care_questions" ADD CONSTRAINT "school_care_questions_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_care_surveys" ADD CONSTRAINT "school_care_surveys_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_care_responses" ADD CONSTRAINT "school_care_responses_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_care_responses" ADD CONSTRAINT "school_care_responses_survey_id_fkey" FOREIGN KEY ("survey_id") REFERENCES "school_care_surveys"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_care_requests" ADD CONSTRAINT "school_care_requests_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_psych_tests" ADD CONSTRAINT "school_psych_tests_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_psych_template_states" ADD CONSTRAINT "school_psych_template_states_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_psych_assignments" ADD CONSTRAINT "school_psych_assignments_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_psych_results" ADD CONSTRAINT "school_psych_results_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_staff_notifications" ADD CONSTRAINT "school_staff_notifications_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_learning_assignments" ADD CONSTRAINT "school_learning_assignments_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

