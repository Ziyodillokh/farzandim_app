-- Bola so'ragan qo'shimcha vaqt (daqiqa) + sabab. Ota-onaga ko'rsatiladi va
-- tasdiqlashda "o'shancha miqdorda" beriladi (default minutes = requestedMinutes).
ALTER TABLE "unlock_requests" ADD COLUMN "requested_minutes" INTEGER;
ALTER TABLE "unlock_requests" ADD COLUMN "reason" TEXT;
