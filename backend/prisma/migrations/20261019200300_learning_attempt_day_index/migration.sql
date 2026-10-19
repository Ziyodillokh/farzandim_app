-- Haftalik hisobot va admin statistikasi (kun + holat bo'yicha) uchun indeks.

-- CreateIndex
CREATE INDEX "learning_attempts_day_status_idx" ON "learning_attempts"("day", "status");

