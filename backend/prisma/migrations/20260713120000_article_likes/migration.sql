-- Maqola like hisoblagichi (video.likes bilan bir xil).
ALTER TABLE "articles" ADD COLUMN IF NOT EXISTS "likes" INTEGER NOT NULL DEFAULT 0;
