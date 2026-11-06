-- Yutuqlar (badge) ochilgan vaqti: faqat qo'shuvchi, standart qiymatli ustun.
-- Mavjud qatorlar o'zgarmaydi (UPDATE/DELETE yo'q).
ALTER TABLE "child_profiles" ADD COLUMN "achievement_dates" JSONB NOT NULL DEFAULT '{}';
