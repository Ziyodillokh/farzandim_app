-- Sprint 5.6d — Books PDF upload uchun MinIO storage paths.
-- Nullable: eski URL-based kitoblar buzilmaydi.

ALTER TABLE "books"
  ADD COLUMN "storage_key" TEXT,
  ADD COLUMN "thumb_storage_key" TEXT;
