-- Sprint 6 P1 — token bekor qilish (logout).
-- users va moderators jadvallariga token_version ustuni qo'shiladi.
-- Logout'da increment qilinadi; refresh endpoint token'dagi tokenVersion
-- joriy qiymatga mos kelishini tekshiradi — mos kelmasa refresh rad etiladi.

ALTER TABLE "users" ADD COLUMN "token_version" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "moderators" ADD COLUMN "token_version" INTEGER NOT NULL DEFAULT 0;
