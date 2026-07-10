-- CreateTable
CREATE TABLE "child_video_views" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "video_id" TEXT NOT NULL,
    "viewed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "child_video_views_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "child_video_favorites" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "video_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "child_video_favorites_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "child_video_views_child_id_viewed_at_idx" ON "child_video_views"("child_id", "viewed_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "child_video_views_child_id_video_id_key" ON "child_video_views"("child_id", "video_id");

-- CreateIndex
CREATE INDEX "child_video_favorites_child_id_created_at_idx" ON "child_video_favorites"("child_id", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "child_video_favorites_child_id_video_id_key" ON "child_video_favorites"("child_id", "video_id");

-- AddForeignKey
ALTER TABLE "child_video_views" ADD CONSTRAINT "child_video_views_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_video_views" ADD CONSTRAINT "child_video_views_video_id_fkey" FOREIGN KEY ("video_id") REFERENCES "videos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_video_favorites" ADD CONSTRAINT "child_video_favorites_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_video_favorites" ADD CONSTRAINT "child_video_favorites_video_id_fkey" FOREIGN KEY ("video_id") REFERENCES "videos"("id") ON DELETE CASCADE ON UPDATE CASCADE;
