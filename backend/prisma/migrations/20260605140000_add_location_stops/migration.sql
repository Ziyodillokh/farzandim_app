-- AlterTable: Child stop-detection state machine fields
ALTER TABLE "children" ADD COLUMN "stop_anchor_lat" DOUBLE PRECISION;
ALTER TABLE "children" ADD COLUMN "stop_anchor_lng" DOUBLE PRECISION;
ALTER TABLE "children" ADD COLUMN "stop_anchor_at" TIMESTAMP(3);
ALTER TABLE "children" ADD COLUMN "open_stop_id" TEXT;

-- CreateTable
CREATE TABLE "location_stops" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "arrived_at" TIMESTAMP(3) NOT NULL,
    "left_at" TIMESTAMP(3),
    "duration_sec" INTEGER NOT NULL DEFAULT 0,
    "point_count" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "location_stops_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "location_stops_child_id_arrived_at_idx" ON "location_stops"("child_id", "arrived_at" DESC);

-- AddForeignKey
ALTER TABLE "location_stops" ADD CONSTRAINT "location_stops_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
