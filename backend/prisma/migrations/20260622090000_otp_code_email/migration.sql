-- OtpCode: email OTP qo'llab-quvvatlash (SMS OTP bilan bir xil oqim).
-- phone endi ixtiyoriy (email OTP uchun phone bo'lmasligi mumkin),
-- email ustuni qo'shiladi va u bo'yicha index yaratiladi.

-- AlterTable
ALTER TABLE "otp_codes" ALTER COLUMN "phone" DROP NOT NULL;
ALTER TABLE "otp_codes" ADD COLUMN "email" TEXT;

-- CreateIndex
CREATE INDEX "otp_codes_email_created_at_idx" ON "otp_codes"("email", "created_at" DESC);
