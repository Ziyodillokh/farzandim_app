-- Qadam mukofoti idempotentligi: shu kun uchun allaqachon berilgan don.
-- Yangi don = floor(steps/1000)*5 - don_awarded.
ALTER TABLE "child_step_daily" ADD COLUMN IF NOT EXISTS "don_awarded" INTEGER NOT NULL DEFAULT 0;
