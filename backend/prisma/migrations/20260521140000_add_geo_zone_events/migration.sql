-- Sprint 6 P2 — geo-zona kirish/chiqish hodisalari tarixi.
-- Location POST geofence kesib o'tishni aniqlaganda shu jadvalga yoziladi.

CREATE TABLE "geo_zone_events" (
  "id"         TEXT NOT NULL,
  "zone_id"    TEXT NOT NULL,
  "child_id"   TEXT NOT NULL,
  "type"       TEXT NOT NULL,
  "latitude"   DOUBLE PRECISION NOT NULL,
  "longitude"  DOUBLE PRECISION NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "geo_zone_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "geo_zone_events_child_id_created_at_idx" ON "geo_zone_events"("child_id", "created_at" DESC);
CREATE INDEX "geo_zone_events_zone_id_idx" ON "geo_zone_events"("zone_id");

ALTER TABLE "geo_zone_events" ADD CONSTRAINT "geo_zone_events_zone_id_fkey" FOREIGN KEY ("zone_id") REFERENCES "geo_zones"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "geo_zone_events" ADD CONSTRAINT "geo_zone_events_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
