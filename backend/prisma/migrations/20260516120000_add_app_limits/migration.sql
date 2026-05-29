-- CreateTable
CREATE TABLE "app_limits" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "package_name" TEXT NOT NULL,
    "daily_limit_ms" BIGINT NOT NULL,
    "weekly_limit_ms" BIGINT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "app_limits_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "app_limits_child_id_package_name_key" ON "app_limits"("child_id", "package_name");

-- CreateIndex
CREATE INDEX "app_limits_child_id_is_active_idx" ON "app_limits"("child_id", "is_active");

-- AddForeignKey
ALTER TABLE "app_limits" ADD CONSTRAINT "app_limits_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
