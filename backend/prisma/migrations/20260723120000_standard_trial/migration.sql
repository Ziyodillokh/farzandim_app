-- 1-haftalik Standart demo (trial): User.trial_used + Subscription trial ustunlari.
-- Trial = ACTIVE Standart obuna, expires_at = now + 7 kun; muddati o'tsa entitlement
-- uni ko'rmaydi va foydalanuvchi avtomatik free'ga tushadi (ma'lumot saqlanadi).

-- User: bir foydalanuvchi = bir marta trial (qayta ro'yxatdan o'tsa ham qayta olmaydi)
ALTER TABLE "users" ADD COLUMN "trial_used" BOOLEAN NOT NULL DEFAULT false;

-- Subscription: trial belgisi + push eslatma holatlari (dedup uchun)
ALTER TABLE "subscriptions" ADD COLUMN "is_trial" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "subscriptions" ADD COLUMN "trial_reminder_sent_at" TIMESTAMP(3);
ALTER TABLE "subscriptions" ADD COLUMN "trial_ended_notified_at" TIMESTAMP(3);

-- Trial cron so'rovlari uchun indeks (is_trial + expires_at bo'yicha skanerlash)
CREATE INDEX "subscriptions_is_trial_expires_at_idx" ON "subscriptions"("is_trial", "expires_at");
