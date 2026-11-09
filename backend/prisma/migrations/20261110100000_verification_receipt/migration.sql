-- AlterTable
ALTER TABLE "school_verification_requests" ADD COLUMN     "receipt_key" TEXT,
ADD COLUMN     "receipt_size" INTEGER,
ADD COLUMN     "receipt_type" TEXT;

