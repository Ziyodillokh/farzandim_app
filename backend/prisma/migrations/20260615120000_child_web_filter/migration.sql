-- Xavfsiz internet filtri (ota-ona ixtiyoriy yoqadi) — schema'da maydonlar
-- bor edi, lekin migration yo'q edi (deploy'da ustunlar yaratilmasdi →
-- runtime'da children query 500 berishi mumkin). Shu ustunlarni qo'shamiz.
ALTER TABLE "children" ADD COLUMN "web_filter_enabled" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "children" ADD COLUMN "blocked_web_categories" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
