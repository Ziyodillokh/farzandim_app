-- Email + parol auth uchun ustunlar (Telegram-only userlar uchun null)
ALTER TABLE "users" ADD COLUMN "email" TEXT,
ADD COLUMN "password_hash" TEXT;

-- Email unique (faqat to'ldirilgan qiymatlar uchun amal qiladi; NULL'lar cheklanmaydi)
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");
