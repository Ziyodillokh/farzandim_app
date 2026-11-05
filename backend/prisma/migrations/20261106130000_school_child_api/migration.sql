-- CreateEnum
CREATE TYPE "SchoolHomeworkStatus" AS ENUM ('SUBMITTED', 'ACCEPTED', 'RETURNED');

-- AlterTable
ALTER TABLE "school_learning_assignments" ADD COLUMN     "estimated_minutes" INTEGER,
ADD COLUMN     "title" TEXT;

-- CreateTable
CREATE TABLE "school_homework_submissions" (
    "id" TEXT NOT NULL,
    "assignment_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "comment" TEXT,
    "status" "SchoolHomeworkStatus" NOT NULL DEFAULT 'SUBMITTED',
    "submitted_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewed_at" TIMESTAMP(3),
    "reviewed_by_staff_id" TEXT,
    "review_note" TEXT,
    "request_id" TEXT,

    CONSTRAINT "school_homework_submissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_homework_photos" (
    "id" TEXT NOT NULL,
    "submission_id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "content_type" TEXT NOT NULL,
    "size" INTEGER NOT NULL,
    "position" INTEGER NOT NULL,

    CONSTRAINT "school_homework_photos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_timetable_lessons" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "class_id" TEXT NOT NULL,
    "weekday" INTEGER NOT NULL,
    "period_no" INTEGER NOT NULL,
    "subject" TEXT NOT NULL,
    "room" TEXT,
    "teacher_name" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_timetable_lessons_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_announcement_student_reads" (
    "id" TEXT NOT NULL,
    "announcement_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "read_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_announcement_student_reads_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "school_homework_submissions_student_id_idx" ON "school_homework_submissions"("student_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_homework_submissions_assignment_id_student_id_key" ON "school_homework_submissions"("assignment_id", "student_id");

-- CreateIndex
CREATE INDEX "school_homework_photos_submission_id_position_idx" ON "school_homework_photos"("submission_id", "position");

-- CreateIndex
CREATE INDEX "school_timetable_lessons_school_id_idx" ON "school_timetable_lessons"("school_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_timetable_lessons_class_id_weekday_period_no_key" ON "school_timetable_lessons"("class_id", "weekday", "period_no");

-- CreateIndex
CREATE INDEX "school_announcement_student_reads_student_id_idx" ON "school_announcement_student_reads"("student_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_announcement_student_reads_announcement_id_student_i_key" ON "school_announcement_student_reads"("announcement_id", "student_id");

-- AddForeignKey
ALTER TABLE "school_homework_submissions" ADD CONSTRAINT "school_homework_submissions_assignment_id_fkey" FOREIGN KEY ("assignment_id") REFERENCES "school_learning_assignments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_homework_submissions" ADD CONSTRAINT "school_homework_submissions_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_homework_photos" ADD CONSTRAINT "school_homework_photos_submission_id_fkey" FOREIGN KEY ("submission_id") REFERENCES "school_homework_submissions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_timetable_lessons" ADD CONSTRAINT "school_timetable_lessons_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_timetable_lessons" ADD CONSTRAINT "school_timetable_lessons_class_id_fkey" FOREIGN KEY ("class_id") REFERENCES "school_classes"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_announcement_student_reads" ADD CONSTRAINT "school_announcement_student_reads_announcement_id_fkey" FOREIGN KEY ("announcement_id") REFERENCES "school_announcements"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_announcement_student_reads" ADD CONSTRAINT "school_announcement_student_reads_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

