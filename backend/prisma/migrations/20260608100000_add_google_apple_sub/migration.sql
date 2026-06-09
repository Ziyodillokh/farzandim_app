-- Sprint 7: Google / Apple ijtimoiy login
-- Foydalanuvchini Google "sub" (stabil ID) yoki Apple "sub" bo'yicha topish/yaratish.
ALTER TABLE "users" ADD COLUMN "google_sub" TEXT;
ALTER TABLE "users" ADD COLUMN "apple_sub" TEXT;

CREATE UNIQUE INDEX "users_google_sub_key" ON "users"("google_sub");
CREATE UNIQUE INDEX "users_apple_sub_key" ON "users"("apple_sub");
