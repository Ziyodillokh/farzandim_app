-- CreateTable: admin xavfsizlik sozlamalari (singleton — IP allowlist).
CREATE TABLE "admin_security_settings" (
    "id" TEXT NOT NULL DEFAULT 'singleton',
    "ip_allowlist_enabled" BOOLEAN NOT NULL DEFAULT false,
    "ip_allowlist" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "admin_security_settings_pkey" PRIMARY KEY ("id")
);
