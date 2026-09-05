-- Do'kondagi JONLI versiya (App Store / Play) — cron yozadi.
-- Faylda saqlab bo'lmaydi: deploy rsync --delete repo nusxasini tiklaydi.
CREATE TABLE "store_versions" (
    "id" TEXT NOT NULL,
    "app" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "latest" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "checked_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "store_versions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "store_versions_app_platform_key" ON "store_versions"("app", "platform");
