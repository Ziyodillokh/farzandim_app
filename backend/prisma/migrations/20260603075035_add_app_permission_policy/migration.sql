-- Per-app ruxsat siyosati jadvali
CREATE TABLE "app_permission_policies" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "package_name" TEXT NOT NULL,
    "permission" TEXT NOT NULL,
    "allowed" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "app_permission_policies_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "app_permission_policies_child_id_package_name_permission_key" ON "app_permission_policies"("child_id", "package_name", "permission");
CREATE INDEX "app_permission_policies_child_id_permission_idx" ON "app_permission_policies"("child_id", "permission");
ALTER TABLE "app_permission_policies" ADD CONSTRAINT "app_permission_policies_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
