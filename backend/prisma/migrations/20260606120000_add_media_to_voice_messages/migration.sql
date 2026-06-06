-- AlterTable: Telegram-style chat media (rasm / hujjat) — MinIO `chat` bucket.
ALTER TABLE "voice_messages" ADD COLUMN     "media_key" TEXT,
ADD COLUMN     "media_type" TEXT,
ADD COLUMN     "mime_type" TEXT,
ADD COLUMN     "file_name" TEXT,
ADD COLUMN     "file_size" INTEGER;
