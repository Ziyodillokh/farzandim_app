-- Sprint 5.6c — MinIO storage paths for content tables.
-- Nullable: eski rowlar tashqi CDN URL bilan ishlashda davom etadi.
-- Bor bo'lsa, consumer endpoint har request'da signed URL qayta sign qiladi.

ALTER TABLE "videos"
  ADD COLUMN "storage_key" TEXT,
  ADD COLUMN "thumb_storage_key" TEXT;

ALTER TABLE "audiobooks"
  ADD COLUMN "storage_key" TEXT,
  ADD COLUMN "thumb_storage_key" TEXT;

ALTER TABLE "games"
  ADD COLUMN "storage_key" TEXT,
  ADD COLUMN "thumb_storage_key" TEXT;
