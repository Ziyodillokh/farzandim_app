-- Video DON mukofoti (bola to'liq ko'rgach). Audiobook.xp_reward bilan bir xil.
ALTER TABLE "videos" ADD COLUMN IF NOT EXISTS "xp_reward" INTEGER NOT NULL DEFAULT 0;
