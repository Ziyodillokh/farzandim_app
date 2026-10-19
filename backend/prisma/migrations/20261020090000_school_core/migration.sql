-- Parvoz School (1-to'lqin): maktab tuzilmasi, xodimlar va sessiyalar,
-- audit, o'quvchilar, vasiylar, eslatmalar, davomat. Faqat yangi jadvallar.

-- CreateEnum
CREATE TYPE "SchoolStatus" AS ENUM ('ACTIVE', 'SUSPENDED');

-- CreateEnum
CREATE TYPE "SchoolStaffRole" AS ENUM ('DIRECTOR', 'ADMIN', 'HOMEROOM', 'PSYCHOLOGIST', 'DUTY', 'TEACHER');

-- CreateEnum
CREATE TYPE "SchoolGender" AS ENUM ('MALE', 'FEMALE');

-- CreateEnum
CREATE TYPE "SchoolDeviceOs" AS ENUM ('IOS', 'ANDROID', 'NONE');

-- CreateEnum
CREATE TYPE "GuardianRelation" AS ENUM ('MOTHER', 'FATHER', 'GRANDPARENT', 'OTHER');

-- CreateEnum
CREATE TYPE "GuardianLinkStatus" AS ENUM ('NOT_INVITED', 'INVITED', 'LINKED');

-- CreateEnum
CREATE TYPE "AttendanceStatus" AS ENUM ('PRESENT', 'LATE', 'ABSENT', 'LEFT_EARLY', 'EXCUSED');

-- CreateEnum
CREATE TYPE "AttendanceSource" AS ENUM ('QR', 'KIOSK', 'MANUAL', 'SYSTEM');

-- CreateEnum
CREATE TYPE "AttendanceEventKind" AS ENUM ('IN', 'OUT');

-- CreateEnum
CREATE TYPE "EarlyExitStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "ParentNoticeKind" AS ENUM ('ARRIVED', 'LEFT', 'ABSENT', 'EARLY_EXIT');

-- CreateTable
CREATE TABLE "schools" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "short_name" TEXT NOT NULL,
    "city" TEXT NOT NULL DEFAULT '',
    "address" TEXT NOT NULL DEFAULT '',
    "phone" TEXT NOT NULL DEFAULT '',
    "logo" TEXT,
    "academic_year" TEXT NOT NULL,
    "late_after_minutes" INTEGER NOT NULL DEFAULT 10,
    "quarters" JSONB NOT NULL DEFAULT '[]',
    "kiosk_secret" TEXT NOT NULL,
    "status" "SchoolStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "schools_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_shifts" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "start" TEXT NOT NULL,
    "end" TEXT NOT NULL,
    "weekdays" INTEGER[],
    "periods" JSONB NOT NULL DEFAULT '[]',
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_shifts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_holidays" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "date" TEXT NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "school_holidays_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_classes" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "grade" INTEGER NOT NULL,
    "letter" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "shift_id" TEXT NOT NULL,
    "homeroom_staff_id" TEXT,
    "room" TEXT NOT NULL DEFAULT '',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_classes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_staff" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "full_name" TEXT NOT NULL,
    "position" TEXT NOT NULL DEFAULT '',
    "role" "SchoolStaffRole" NOT NULL,
    "phone" TEXT NOT NULL DEFAULT '',
    "email" TEXT NOT NULL DEFAULT '',
    "photo" TEXT,
    "portrait" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "username" TEXT,
    "password_hash" TEXT,
    "must_change_password" BOOLEAN NOT NULL DEFAULT false,
    "token_version" INTEGER NOT NULL DEFAULT 0,
    "failed_logins" INTEGER NOT NULL DEFAULT 0,
    "locked_until" TIMESTAMP(3),
    "last_login_at" TIMESTAMP(3),
    "totp_secret" TEXT,
    "totp_enabled" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_staff_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_staff_classes" (
    "staff_id" TEXT NOT NULL,
    "class_id" TEXT NOT NULL,

    CONSTRAINT "school_staff_classes_pkey" PRIMARY KEY ("staff_id","class_id")
);

-- CreateTable
CREATE TABLE "school_staff_sessions" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "staff_id" TEXT NOT NULL,
    "token_hash" TEXT NOT NULL,
    "user_agent" TEXT,
    "ip" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_used_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "revoked_at" TIMESTAMP(3),

    CONSTRAINT "school_staff_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_audit_logs" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "actor_id" TEXT,
    "actor_name" TEXT NOT NULL,
    "module" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "entity_id" TEXT,
    "summary" TEXT NOT NULL,
    "params" JSONB,
    "before" JSONB,
    "after" JSONB,
    "ip" TEXT,

    CONSTRAINT "school_audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_students" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "class_id" TEXT,
    "last_name" TEXT NOT NULL,
    "first_name" TEXT NOT NULL,
    "middle_name" TEXT NOT NULL DEFAULT '',
    "gender" "SchoolGender" NOT NULL,
    "birth_date" TEXT NOT NULL,
    "device" "SchoolDeviceOs" NOT NULL DEFAULT 'NONE',
    "student_code" TEXT NOT NULL,
    "enrolled_at" TEXT NOT NULL,
    "archived" BOOLEAN NOT NULL DEFAULT false,
    "archived_at" TIMESTAMP(3),
    "child_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_students_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_guardians" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "full_name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "relation" "GuardianRelation" NOT NULL,
    "link_status" "GuardianLinkStatus" NOT NULL DEFAULT 'NOT_INVITED',
    "invite_code" TEXT,
    "invite_expires_at" TIMESTAMP(3),
    "linked_at" TIMESTAMP(3),
    "user_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_guardians_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_student_guardians" (
    "student_id" TEXT NOT NULL,
    "guardian_id" TEXT NOT NULL,

    CONSTRAINT "school_student_guardians_pkey" PRIMARY KEY ("student_id","guardian_id")
);

-- CreateTable
CREATE TABLE "school_student_notes" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "class_id" TEXT,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "by_staff_id" TEXT NOT NULL,
    "text" TEXT NOT NULL,

    CONSTRAINT "school_student_notes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_attendance" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "date" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "class_id" TEXT,
    "status" "AttendanceStatus" NOT NULL,
    "in_at" TEXT,
    "out_at" TEXT,
    "source" "AttendanceSource" NOT NULL,
    "parent_notified" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_attendance_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_attendance_corrections" (
    "id" TEXT NOT NULL,
    "attendance_id" TEXT NOT NULL,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "by_staff_id" TEXT NOT NULL,
    "from" "AttendanceStatus" NOT NULL,
    "to" "AttendanceStatus" NOT NULL,
    "reason" TEXT NOT NULL,

    CONSTRAINT "school_attendance_corrections_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_attendance_events" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "date" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "class_id" TEXT,
    "kind" "AttendanceEventKind" NOT NULL,
    "source" "AttendanceSource" NOT NULL,
    "late" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "school_attendance_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_early_exits" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "class_id" TEXT,
    "date" TEXT NOT NULL,
    "time" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "pickup_by" TEXT NOT NULL,
    "status" "EarlyExitStatus" NOT NULL DEFAULT 'PENDING',
    "requested_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "requested_by_user_id" TEXT,
    "decided_by_staff_id" TEXT,
    "decided_at" TIMESTAMP(3),

    CONSTRAINT "school_early_exits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_parent_notices" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "date" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "guardian_id" TEXT NOT NULL,
    "kind" "ParentNoticeKind" NOT NULL,
    "delivered" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "school_parent_notices_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "schools_code_key" ON "schools"("code");

-- CreateIndex
CREATE INDEX "school_shifts_school_id_idx" ON "school_shifts"("school_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_holidays_school_id_date_key" ON "school_holidays"("school_id", "date");

-- CreateIndex
CREATE INDEX "school_classes_school_id_grade_idx" ON "school_classes"("school_id", "grade");

-- CreateIndex
CREATE UNIQUE INDEX "school_classes_school_id_name_key" ON "school_classes"("school_id", "name");

-- CreateIndex
CREATE INDEX "school_staff_school_id_role_idx" ON "school_staff"("school_id", "role");

-- CreateIndex
CREATE UNIQUE INDEX "school_staff_school_id_username_key" ON "school_staff"("school_id", "username");

-- CreateIndex
CREATE INDEX "school_staff_classes_class_id_idx" ON "school_staff_classes"("class_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_staff_sessions_token_hash_key" ON "school_staff_sessions"("token_hash");

-- CreateIndex
CREATE INDEX "school_staff_sessions_staff_id_idx" ON "school_staff_sessions"("staff_id");

-- CreateIndex
CREATE INDEX "school_audit_logs_school_id_at_idx" ON "school_audit_logs"("school_id", "at" DESC);

-- CreateIndex
CREATE INDEX "school_audit_logs_school_id_module_at_idx" ON "school_audit_logs"("school_id", "module", "at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "school_students_child_id_key" ON "school_students"("child_id");

-- CreateIndex
CREATE INDEX "school_students_school_id_class_id_idx" ON "school_students"("school_id", "class_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_students_school_id_student_code_key" ON "school_students"("school_id", "student_code");

-- CreateIndex
CREATE UNIQUE INDEX "school_guardians_invite_code_key" ON "school_guardians"("invite_code");

-- CreateIndex
CREATE INDEX "school_guardians_school_id_phone_idx" ON "school_guardians"("school_id", "phone");

-- CreateIndex
CREATE INDEX "school_guardians_user_id_idx" ON "school_guardians"("user_id");

-- CreateIndex
CREATE INDEX "school_student_guardians_guardian_id_idx" ON "school_student_guardians"("guardian_id");

-- CreateIndex
CREATE INDEX "school_student_notes_student_id_at_idx" ON "school_student_notes"("student_id", "at" DESC);

-- CreateIndex
CREATE INDEX "school_attendance_school_id_date_idx" ON "school_attendance"("school_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "school_attendance_student_id_date_key" ON "school_attendance"("student_id", "date");

-- CreateIndex
CREATE INDEX "school_attendance_corrections_attendance_id_idx" ON "school_attendance_corrections"("attendance_id");

-- CreateIndex
CREATE INDEX "school_attendance_events_school_id_date_at_idx" ON "school_attendance_events"("school_id", "date", "at" DESC);

-- CreateIndex
CREATE INDEX "school_attendance_events_student_id_date_idx" ON "school_attendance_events"("student_id", "date");

-- CreateIndex
CREATE INDEX "school_early_exits_school_id_date_idx" ON "school_early_exits"("school_id", "date");

-- CreateIndex
CREATE INDEX "school_early_exits_school_id_status_idx" ON "school_early_exits"("school_id", "status");

-- CreateIndex
CREATE INDEX "school_parent_notices_school_id_at_idx" ON "school_parent_notices"("school_id", "at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "school_parent_notices_student_id_date_kind_guardian_id_key" ON "school_parent_notices"("student_id", "date", "kind", "guardian_id");

-- AddForeignKey
ALTER TABLE "school_shifts" ADD CONSTRAINT "school_shifts_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_holidays" ADD CONSTRAINT "school_holidays_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_classes" ADD CONSTRAINT "school_classes_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_classes" ADD CONSTRAINT "school_classes_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "school_shifts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_classes" ADD CONSTRAINT "school_classes_homeroom_staff_id_fkey" FOREIGN KEY ("homeroom_staff_id") REFERENCES "school_staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_staff" ADD CONSTRAINT "school_staff_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_staff_classes" ADD CONSTRAINT "school_staff_classes_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "school_staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_staff_classes" ADD CONSTRAINT "school_staff_classes_class_id_fkey" FOREIGN KEY ("class_id") REFERENCES "school_classes"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_staff_sessions" ADD CONSTRAINT "school_staff_sessions_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_staff_sessions" ADD CONSTRAINT "school_staff_sessions_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "school_staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_audit_logs" ADD CONSTRAINT "school_audit_logs_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_students" ADD CONSTRAINT "school_students_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_students" ADD CONSTRAINT "school_students_class_id_fkey" FOREIGN KEY ("class_id") REFERENCES "school_classes"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_students" ADD CONSTRAINT "school_students_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_guardians" ADD CONSTRAINT "school_guardians_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_guardians" ADD CONSTRAINT "school_guardians_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_student_guardians" ADD CONSTRAINT "school_student_guardians_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_student_guardians" ADD CONSTRAINT "school_student_guardians_guardian_id_fkey" FOREIGN KEY ("guardian_id") REFERENCES "school_guardians"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_student_notes" ADD CONSTRAINT "school_student_notes_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_student_notes" ADD CONSTRAINT "school_student_notes_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_attendance" ADD CONSTRAINT "school_attendance_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_attendance" ADD CONSTRAINT "school_attendance_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_attendance_corrections" ADD CONSTRAINT "school_attendance_corrections_attendance_id_fkey" FOREIGN KEY ("attendance_id") REFERENCES "school_attendance"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_attendance_events" ADD CONSTRAINT "school_attendance_events_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_early_exits" ADD CONSTRAINT "school_early_exits_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_parent_notices" ADD CONSTRAINT "school_parent_notices_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

