-- Sprint 5.x — TOTP 2FA admin auth uchun.
-- Eski moderator'lar default holatda 2FA o'chirilgan (twoFactorEnabled=false).
-- Setup flow: /2fa/setup → /2fa/enable (verifiklasiyalik kodni tekshirish).

ALTER TABLE "moderators"
  ADD COLUMN "two_factor_enabled"      BOOLEAN     NOT NULL DEFAULT false,
  ADD COLUMN "two_factor_secret"       TEXT,
  ADD COLUMN "two_factor_backup_codes" TEXT[]      NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "two_factor_enabled_at"   TIMESTAMP(3);
