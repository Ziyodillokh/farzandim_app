-- School Mode: maktab hududi (faqat hududda bloklash), favqulodda o'chirish muddati,
-- Android "ustida ko'rsatish" ruxsati. Faqat qo'shimcha ustunlar (additive).
ALTER TABLE "schools" ADD COLUMN "latitude" DOUBLE PRECISION;
ALTER TABLE "schools" ADD COLUMN "longitude" DOUBLE PRECISION;
ALTER TABLE "schools" ADD COLUMN "zone_radius_m" INTEGER;

ALTER TABLE "school_mode_policies" ADD COLUMN "zone_required" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "school_emergencies" ADD COLUMN "until" TIMESTAMP(3);

ALTER TABLE "children" ADD COLUMN "overlay_permission" BOOLEAN;
