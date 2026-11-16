-- Refresh rotatsiyasi imtiyozi: oldingi jti va rotatsiya vaqti (faqat qo'shimcha ustunlar).
ALTER TABLE "user_sessions" ADD COLUMN "prev_jti" TEXT;
ALTER TABLE "user_sessions" ADD COLUMN "rotated_at" TIMESTAMP(3);
