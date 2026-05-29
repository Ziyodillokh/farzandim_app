-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('ACHIEVEMENT', 'CONTEST', 'SCHEDULE', 'PARENT_REQUEST', 'VOICE', 'GEO_ZONE', 'SYSTEM');

-- CreateEnum
CREATE TYPE "FeedbackEmoji" AS ENUM ('HAPPY', 'EXCITED', 'THINKING', 'WINKING', 'SAD', 'ANGRY', 'TIRED', 'LOVE');

-- CreateEnum
CREATE TYPE "XpEventType" AS ENUM ('BOOK_READ', 'CONTEST_JOIN', 'CONTEST_WIN', 'CREATIVE_JOIN', 'CREATIVE_WIN', 'COURSE_LESSON', 'DAILY_GOAL', 'STREAK_WEEKLY', 'CONTENT_POST', 'OTHER');

-- CreateEnum
CREATE TYPE "PhotoRequestStatus" AS ENUM ('PENDING', 'COMPLETED', 'DECLINED');

-- CreateEnum
CREATE TYPE "SosStatus" AS ENUM ('ACTIVE', 'RESOLVED');

-- CreateTable
CREATE TABLE "video_messages" (
    "id" TEXT NOT NULL,
    "sender_id" TEXT NOT NULL,
    "receiver_id" TEXT NOT NULL,
    "storage_path" TEXT NOT NULL,
    "thumbnail_path" TEXT,
    "duration_seconds" INTEGER,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "video_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "type" "NotificationType" NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "data" JSONB,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "feedback" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "emoji" "FeedbackEmoji" NOT NULL,
    "message" TEXT,
    "context" TEXT,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "feedback_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "child_profiles" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "xp" INTEGER NOT NULL DEFAULT 0,
    "don_balance" INTEGER NOT NULL DEFAULT 0,
    "level" INTEGER NOT NULL DEFAULT 1,
    "status" TEXT NOT NULL DEFAULT 'Boshlovchi',
    "streak_days" INTEGER NOT NULL DEFAULT 0,
    "last_activity_date" TIMESTAMP(3),
    "achievements" JSONB NOT NULL DEFAULT '[]',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "child_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "xp_events" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "type" "XpEventType" NOT NULL,
    "xp_delta" INTEGER NOT NULL,
    "don_delta" INTEGER NOT NULL DEFAULT 0,
    "related_id" TEXT,
    "source" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "xp_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "photo_requests" (
    "id" TEXT NOT NULL,
    "parent_id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "status" "PhotoRequestStatus" NOT NULL DEFAULT 'PENDING',
    "photo_path" TEXT,
    "thumbnail_path" TEXT,
    "message" TEXT,
    "requested_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMP(3),
    "declined_at" TIMESTAMP(3),

    CONSTRAINT "photo_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sos_alerts" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "accuracy" DOUBLE PRECISION,
    "status" "SosStatus" NOT NULL DEFAULT 'ACTIVE',
    "device_info" JSONB,
    "resolved_at" TIMESTAMP(3),
    "resolved_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sos_alerts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "installed_apps" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "package_name" TEXT NOT NULL,
    "app_name" TEXT NOT NULL,
    "version_name" TEXT,
    "version_code" INTEGER,
    "install_source" TEXT,
    "icon_path" TEXT,
    "is_system" BOOLEAN NOT NULL DEFAULT false,
    "first_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "installed_apps_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app_usage" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "package_name" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "foreground_ms" BIGINT NOT NULL DEFAULT 0,
    "last_used_at" TIMESTAMP(3),
    "open_count" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "app_usage_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "video_messages_receiver_id_is_read_idx" ON "video_messages"("receiver_id", "is_read");

-- CreateIndex
CREATE INDEX "video_messages_sender_id_idx" ON "video_messages"("sender_id");

-- CreateIndex
CREATE INDEX "notifications_child_id_is_read_idx" ON "notifications"("child_id", "is_read");

-- CreateIndex
CREATE INDEX "notifications_child_id_created_at_idx" ON "notifications"("child_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "feedback_child_id_is_read_idx" ON "feedback"("child_id", "is_read");

-- CreateIndex
CREATE INDEX "feedback_child_id_created_at_idx" ON "feedback"("child_id", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "child_profiles_child_id_key" ON "child_profiles"("child_id");

-- CreateIndex
CREATE INDEX "xp_events_child_id_created_at_idx" ON "xp_events"("child_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "photo_requests_child_id_status_idx" ON "photo_requests"("child_id", "status");

-- CreateIndex
CREATE INDEX "photo_requests_parent_id_status_idx" ON "photo_requests"("parent_id", "status");

-- CreateIndex
CREATE INDEX "sos_alerts_child_id_status_idx" ON "sos_alerts"("child_id", "status");

-- CreateIndex
CREATE INDEX "sos_alerts_status_created_at_idx" ON "sos_alerts"("status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "installed_apps_child_id_idx" ON "installed_apps"("child_id");

-- CreateIndex
CREATE UNIQUE INDEX "installed_apps_child_id_package_name_key" ON "installed_apps"("child_id", "package_name");

-- CreateIndex
CREATE INDEX "app_usage_child_id_date_idx" ON "app_usage"("child_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "app_usage_child_id_package_name_date_key" ON "app_usage"("child_id", "package_name", "date");

-- AddForeignKey
ALTER TABLE "video_messages" ADD CONSTRAINT "video_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "video_messages" ADD CONSTRAINT "video_messages_receiver_id_fkey" FOREIGN KEY ("receiver_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "feedback" ADD CONSTRAINT "feedback_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_profiles" ADD CONSTRAINT "child_profiles_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "xp_events" ADD CONSTRAINT "xp_events_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "photo_requests" ADD CONSTRAINT "photo_requests_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "photo_requests" ADD CONSTRAINT "photo_requests_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sos_alerts" ADD CONSTRAINT "sos_alerts_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "installed_apps" ADD CONSTRAINT "installed_apps_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app_usage" ADD CONSTRAINT "app_usage_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
