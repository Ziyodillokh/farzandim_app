-- CreateTable
CREATE TABLE "admin_notifications" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "target_type" TEXT NOT NULL,
    "filters" JSONB NOT NULL DEFAULT '{}',
    "image_url" TEXT,
    "deep_link" TEXT,
    "status" TEXT NOT NULL DEFAULT 'sent',
    "scheduled_at" TIMESTAMP(3),
    "sent_at" TIMESTAMP(3),
    "delivered_count" INTEGER NOT NULL DEFAULT 0,
    "opened_count" INTEGER NOT NULL DEFAULT 0,
    "clicked_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "created_by_id" TEXT,

    CONSTRAINT "admin_notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "admin_notifications_status_idx" ON "admin_notifications"("status");

-- CreateIndex
CREATE INDEX "admin_notifications_target_type_idx" ON "admin_notifications"("target_type");

-- CreateIndex
CREATE INDEX "admin_notifications_created_at_idx" ON "admin_notifications"("created_at");
