-- Block 3: "Barcha ilovalarni bloklash" — ota-ona dashboard toggle'i (qurilma siyosati).
ALTER TABLE "children" ADD COLUMN "block_all_apps" BOOLEAN NOT NULL DEFAULT false;

-- Block 4: OS-ruxsat holatlari (Child App device-info heartbeat bilan keladi). NULL = noma'lum.
ALTER TABLE "children" ADD COLUMN "location_permission" BOOLEAN;
ALTER TABLE "children" ADD COLUMN "notification_permission" BOOLEAN;
ALTER TABLE "children" ADD COLUMN "background_allowed" BOOLEAN;
ALTER TABLE "children" ADD COLUMN "accessibility_enabled" BOOLEAN;
