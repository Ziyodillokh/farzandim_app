-- Maktab paneli sessiyasi: refresh poygasi uchun oldingi sir xeshi va vaqti.

-- AlterTable
ALTER TABLE "school_staff_sessions" ADD COLUMN     "previous_token_hash" TEXT,
ADD COLUMN     "rotated_at" TIMESTAMP(3);

