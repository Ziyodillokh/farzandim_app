-- CreateTable
CREATE TABLE "content_categories" (
    "id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "content_categories_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "content_categories_kind_slug_key" ON "content_categories"("kind", "slug");

-- CreateIndex
CREATE INDEX "content_categories_kind_idx" ON "content_categories"("kind");

-- CreateTable
CREATE TABLE "videos" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "url" TEXT NOT NULL,
    "thumbnail" TEXT,
    "duration_sec" INTEGER,
    "age_from" INTEGER NOT NULL DEFAULT 0,
    "age_to" INTEGER NOT NULL DEFAULT 18,
    "category_id" TEXT,
    "category" TEXT,
    "plan_required" TEXT NOT NULL DEFAULT 'free',
    "level" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "featured" BOOLEAN NOT NULL DEFAULT false,
    "views" INTEGER NOT NULL DEFAULT 0,
    "likes" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "videos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "videos_status_idx" ON "videos"("status");
CREATE INDEX "videos_category_id_idx" ON "videos"("category_id");
CREATE INDEX "videos_plan_required_idx" ON "videos"("plan_required");
CREATE INDEX "videos_featured_idx" ON "videos"("featured");

-- CreateTable
CREATE TABLE "audiobooks" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "author" TEXT NOT NULL,
    "description" TEXT,
    "audio_url" TEXT NOT NULL,
    "thumbnail" TEXT,
    "duration_sec" INTEGER,
    "parts_count" INTEGER NOT NULL DEFAULT 1,
    "age_from" INTEGER NOT NULL DEFAULT 0,
    "age_to" INTEGER NOT NULL DEFAULT 18,
    "category_id" TEXT,
    "category" TEXT,
    "plan_required" TEXT NOT NULL DEFAULT 'free',
    "status" TEXT NOT NULL DEFAULT 'pending',
    "listens" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "audiobooks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "audiobooks_status_idx" ON "audiobooks"("status");
CREATE INDEX "audiobooks_category_id_idx" ON "audiobooks"("category_id");

-- CreateTable
CREATE TABLE "books" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "author" TEXT NOT NULL,
    "description" TEXT,
    "pdf_url" TEXT,
    "cover_url" TEXT,
    "pages" INTEGER NOT NULL DEFAULT 0,
    "age_from" INTEGER NOT NULL DEFAULT 0,
    "age_to" INTEGER NOT NULL DEFAULT 18,
    "category" TEXT NOT NULL DEFAULT 'school',
    "category_id" TEXT,
    "plan_required" TEXT NOT NULL DEFAULT 'free',
    "status" TEXT NOT NULL DEFAULT 'pending',
    "reads" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "books_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "books_status_idx" ON "books"("status");
CREATE INDEX "books_category_idx" ON "books"("category");

-- CreateTable
CREATE TABLE "games" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "game_url" TEXT NOT NULL,
    "thumbnail_url" TEXT,
    "category" TEXT NOT NULL DEFAULT 'memory',
    "age_group" TEXT NOT NULL DEFAULT '6-12',
    "difficulty" TEXT NOT NULL DEFAULT 'easy',
    "plan_required" TEXT NOT NULL DEFAULT 'free',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "plays" INTEGER NOT NULL DEFAULT 0,
    "avg_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "games_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "games_is_active_idx" ON "games"("is_active");
CREATE INDEX "games_category_idx" ON "games"("category");
