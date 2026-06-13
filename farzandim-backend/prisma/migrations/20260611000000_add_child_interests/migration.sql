-- Onboarding'da bola tanlagan qiziqishlar (kInterestOptions ID'lari).
-- PUT /api/children/me/interests endpoint'i bilan yangilanadi.
-- Content recommendation shu array'dan overlap'iga qarab saralanadi.

ALTER TABLE "children" ADD COLUMN "interests" TEXT[] DEFAULT ARRAY[]::TEXT[];
