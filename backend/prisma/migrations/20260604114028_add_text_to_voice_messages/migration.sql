-- AlterTable
ALTER TABLE "voice_messages" ADD COLUMN     "text" TEXT,
ALTER COLUMN "storage_path" DROP NOT NULL;
