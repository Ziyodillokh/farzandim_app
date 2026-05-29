-- Sprint 6 P2 — bildirishnoma open/click tracking.
-- Per-child Notification rowini uni yaratgan admin broadcast'ga bog'laydi.
-- clicked_at — deep-link bosilganini bir marta hisoblash uchun.

ALTER TABLE "notifications" ADD COLUMN "admin_notification_id" TEXT;
ALTER TABLE "notifications" ADD COLUMN "clicked_at" TIMESTAMP(3);

CREATE INDEX "notifications_admin_notification_id_idx" ON "notifications"("admin_notification_id");

ALTER TABLE "notifications" ADD CONSTRAINT "notifications_admin_notification_id_fkey" FOREIGN KEY ("admin_notification_id") REFERENCES "admin_notifications"("id") ON DELETE SET NULL ON UPDATE CASCADE;
