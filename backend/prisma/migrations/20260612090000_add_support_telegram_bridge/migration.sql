-- Support chat — Telegram ko'prigi: xabarlar + prompt routing + polling offset.
CREATE TABLE "support_messages" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "sender" TEXT NOT NULL,
    "text" TEXT,
    "is_auto_ack" BOOLEAN NOT NULL DEFAULT false,
    "attachment_key" TEXT,
    "attachment_type" TEXT,
    "file_name" TEXT,
    "file_size" INTEGER,
    "mime_type" TEXT,
    "tg_message_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "support_messages_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "support_messages_user_id_created_at_idx" ON "support_messages"("user_id", "created_at");
CREATE INDEX "support_messages_tg_message_id_idx" ON "support_messages"("tg_message_id");

CREATE TABLE "support_tg_prompts" (
    "prompt_message_id" INTEGER NOT NULL,
    "user_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "support_tg_prompts_pkey" PRIMARY KEY ("prompt_message_id")
);

CREATE TABLE "support_tg_state" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "offset" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "support_tg_state_pkey" PRIMARY KEY ("id")
);
