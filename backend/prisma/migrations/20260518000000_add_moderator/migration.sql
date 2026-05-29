-- CreateTable
CREATE TABLE "moderators" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT,
    "password_hash" TEXT NOT NULL,
    "moderator_role_key" TEXT NOT NULL,
    "permissions" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "status" TEXT NOT NULL DEFAULT 'active',
    "last_activity_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "moderators_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "moderators_email_key" ON "moderators"("email");

-- CreateIndex
CREATE INDEX "moderators_moderator_role_key_idx" ON "moderators"("moderator_role_key");

-- CreateIndex
CREATE INDEX "moderators_status_idx" ON "moderators"("status");
