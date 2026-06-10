-- Sprint 5.7 — Bola qiziqishlari (onboarding'da tanlanadi)
-- Default '{}' bo'sh array — eski yozuvlar uchun ham xavfsiz.

ALTER TABLE "children"
  ADD COLUMN "interests" TEXT[] NOT NULL DEFAULT '{}';
