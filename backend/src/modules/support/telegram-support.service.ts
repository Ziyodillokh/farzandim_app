import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../common/database/prisma.service';
import { EnvConfig } from '../../common/config/env.schema';

/**
 * Qo'llab-quvvatlash Telegram BOTI (mustaqil, ilova ichidagi chatsiz).
 *
 * Oqim (endi HAMMA ish botning o'zida — ilovada support chat YO'Q):
 *   1. Foydalanuvchi @parvozyordambot'ga TO'G'RIDAN-TO'G'RI yozadi (shaxsiy DM):
 *      matn / rasm / video / hujjat (pdf) / ovoz — hammasi.
 *   2. Bot murojaatni operatorlar GURUHiga (SUPPORT_CHAT_ID) yuboradi —
 *      "✍️ Javob berish" inline tugmasi bilan (media `copyMessage` orqali,
 *      qayta yuklamasdan; har xabar id → foydalanuvchi chat id ga bog'lanadi).
 *   3. Operator tugmani bosadi → ForceReply so'rovi chiqadi → operator SHU
 *      xabarga reply qilib javob yozadi (matn yoki rasm/fayl).
 *   4. Bot javobni foydalanuvchining DM'iga `copyMessage` orqali yetkazadi
 *      (matn ham, media ham — har qanday tur, hajm cheklovisiz relay).
 *
 * Media MinIO'ga saqlanmaydi va FCM/WS ishlatilmaydi — hammasi Telegram'ning
 * o'zida `copyMessage`/file_id qayta ishlatish orqali (ishonchli, oddiy).
 *
 * Ishonchlilik: guruhga barcha yuborishlar BITTA NAVBAT (serial) + 429/tarmoq
 * retry + supergroup migratsiyada chat ID self-heal. getUpdates (25s long-poll)
 * navbatdan tashqari.
 *
 * ESLATMA: `SupportMessage` DB modeli (eski ilova-ichi chat tarixi) endi
 * ishlatilmaydi — legacy sifatida schema'da qoladi (ma'lumot yo'qotmaslik
 * uchun DROP qilinmagan). `SupportTgPrompt` bu yerda "javob berish mumkin
 * bo'lgan guruh xabari id → foydalanuvchi DM chat id" xaritasi sifatida
 * qayta ishlatiladi (persist — restart'da yo'qolmasin).
 */
@Injectable()
export class TelegramSupportService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(TelegramSupportService.name);

  private token?: string;
  private chatId?: string; // operatorlar guruhi (SUPPORT_CHAT_ID)
  private enabled = false;
  private stopped = false;
  private offset = 0;

  // Guruhga yuborishlar navbati (serial) — flood-control'dan (429) himoya.
  private sendChain: Promise<unknown> = Promise.resolve();

  // In-memory holat (restart'da yo'qoladi — KRITIK EMAS):
  //  - lastAck: har foydalanuvchiga avto-tasdiq (ack) throttle'i.
  //  - nameCache: chat id → ko'rsatiladigan ism (reply prompt'ida chiroyli).
  private readonly lastAck = new Map<string, number>();
  private readonly nameCache = new Map<string, string>();
  private static readonly ACK_THROTTLE_MS = 30 * 60 * 1000; // 30 daqiqa

  constructor(
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly prisma: PrismaService,
  ) {}

  async onModuleInit() {
    this.token = this.config.get('TELEGRAM_BOT_TOKEN_SUPPORT', { infer: true });
    this.chatId = this.config.get('SUPPORT_CHAT_ID', { infer: true });
    this.enabled = Boolean(this.token);
    if (!this.enabled) {
      this.logger.log("Support Telegram bot o'chiq (env yo'q) — skip");
      return;
    }
    if (!this.chatId) {
      this.logger.warn(
        "TELEGRAM_BOT_TOKEN_SUPPORT bor, lekin SUPPORT_CHAT_ID yo'q — " +
          "murojaatlar operatorlar guruhiga bormaydi. Botni guruhga qo'shing: " +
          "u ID'ni e'lon qiladi.",
      );
    }
    const state = await this.prisma.supportTgState.upsert({
      where: { id: 1 },
      update: {},
      create: { id: 1, offset: 0 },
    });
    this.offset = state.offset;
    // Eski marshrut xaritalarini tozalash (30 kundan eski) — jadval shishmasin.
    void this.prisma.supportTgPrompt
      .deleteMany({
        where: { createdAt: { lt: new Date(Date.now() - 30 * 864e5) } },
      })
      .catch(() => undefined);
    // Ishga tushganda chat ID hali ham to'g'rimi — tekshiramiz (guruh
    // supergroup'ga ko'tarilgan bo'lsa avtomatik yangilanadi).
    await this.healChatId();
    void this.pollLoop();
    this.logger.log('Support Telegram bot polling boshlandi');
  }

  onModuleDestroy() {
    this.stopped = true;
  }

  /* ───────────────────────── Telegram API ───────────────────────── */

  /** Xom JSON API chaqiruvi. */
  private async api<T = unknown>(
    method: string,
    body?: Record<string, unknown>,
    timeoutMs = 35_000,
  ): Promise<TgResponse<T>> {
    const res = await fetch(
      `https://api.telegram.org/bot${this.token}/${method}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: body ? JSON.stringify(body) : undefined,
        signal: AbortSignal.timeout(timeoutMs),
      },
    );
    return (await res.json()) as TgResponse<T>;
  }

  /** Berilgan yuborishni 429 (flood) + tarmoq xatosida qayta uradi (5 marta). */
  private async withRetry<T = unknown>(
    fn: () => Promise<TgResponse<T>>,
    attempts = 5,
  ): Promise<TgResponse<T>> {
    for (let i = 0; i < attempts; i++) {
      try {
        const r = await fn();
        if (r.ok) return r;
        const retryAfter = r.parameters?.retry_after;
        if (retryAfter && i < attempts - 1) {
          await this.sleep(retryAfter * 1000 + 300);
          continue;
        }
        return r;
      } catch (e) {
        if (i < attempts - 1) {
          await this.sleep(800);
          continue;
        }
        return { ok: false, description: (e as Error).message };
      }
    }
    return { ok: false };
  }

  /** Navbatga qo'shadi (serial). Rad bo'lgan zanjir keyingilarni bloklamaydi. */
  private enqueue<T>(fn: () => Promise<T>): Promise<T> {
    const run = this.sendChain.then(fn, fn);
    this.sendChain = run.then(
      () => undefined,
      () => undefined,
    );
    return run;
  }

  /**
   * GURUHGA yuborish — SERIAL navbat (tartib + flood himoya) + supergroup
   * migratsiyada chat ID'ni yangilab QAYTA uradi. body.chat_id this.chatId
   * bo'lsa migratsiya qo'llanadi.
   */
  private sendToGroup<T = unknown>(
    method: string,
    body: Record<string, unknown>,
  ): Promise<TgResponse<T>> {
    return this.enqueue(async () => {
      let payload = body;
      for (let attempt = 0; attempt < 2; attempt++) {
        const r = await this.withRetry<T>(() =>
          this.api<T>(method, payload, 30_000),
        );
        if (r.ok) return r;
        const mig = r.parameters?.migrate_to_chat_id;
        if (
          mig &&
          attempt === 0 &&
          String(payload.chat_id) === String(this.chatId)
        ) {
          this.applyMigration(mig);
          payload = { ...payload, chat_id: this.chatId };
          continue;
        }
        return r;
      }
      return { ok: false } as TgResponse<T>;
    });
  }

  /** FOYDALANUVCHI DM'iga yuborish — navbatsiz (har chat alohida), retry bilan. */
  private sendToUser<T = unknown>(
    method: string,
    body: Record<string, unknown>,
  ): Promise<TgResponse<T>> {
    return this.withRetry<T>(() => this.api<T>(method, body, 30_000));
  }

  /**
   * Guruh basic→supergroup'ga ko'tarilsa chat ID o'zgaradi. Telegram javobida
   * `migrate_to_chat_id` keladi — uni ushlab chat ID'ni AVTOMATIK yangilaymiz
   * (server .env'ga qo'l tegizish shart emas).
   */
  private applyMigration(newId: number | string): void {
    const s = String(newId);
    if (s && s !== this.chatId) {
      this.logger.warn(`Support guruh ID migratsiya: ${this.chatId} → ${s}`);
      this.chatId = s;
    }
  }

  /** Ishga tushganda ko'rinmas probe (sendChatAction) — migratsiyani aniqlaydi. */
  private async healChatId(): Promise<void> {
    if (!this.chatId) return;
    try {
      const r = await this.api(
        'sendChatAction',
        { chat_id: this.chatId, action: 'typing' },
        10_000,
      );
      if (!r.ok && r.parameters?.migrate_to_chat_id) {
        this.applyMigration(r.parameters.migrate_to_chat_id);
      }
    } catch {
      // tarmoq xato — runtime'da send/inbound heal qiladi.
    }
  }

  private escapeHtml(s: string): string {
    return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  }

  private sleep(ms: number) {
    return new Promise((r) => setTimeout(r, ms));
  }

  /* ───────────────────────── Polling loop ───────────────────────── */

  private async pollLoop() {
    while (!this.stopped) {
      try {
        const r = await this.api<TgUpdate[]>('getUpdates', {
          offset: this.offset + 1,
          timeout: 25,
          allowed_updates: ['message', 'callback_query', 'my_chat_member'],
        });
        if (!r.ok || !r.result) {
          await this.sleep(3000);
          continue;
        }
        for (const u of r.result) {
          this.offset = Math.max(this.offset, u.update_id);
          try {
            await this.handleUpdate(u);
          } catch (e) {
            this.logger.warn(`update xato: ${(e as Error).message}`);
          }
        }
        if (r.result.length > 0) {
          await this.prisma.supportTgState.update({
            where: { id: 1 },
            data: { offset: this.offset },
          });
        }
      } catch (e) {
        if (!this.stopped) {
          this.logger.debug(`poll xato: ${(e as Error).message}`);
          await this.sleep(3000);
        }
      }
    }
  }

  /* ───────────────────────── Update handling ───────────────────────── */

  private async handleUpdate(u: TgUpdate) {
    // 1) "✍️ Javob berish" tugmasi → ForceReply prompt (guruhda).
    if (u.callback_query) {
      await this.handleReplyButton(u.callback_query);
      return;
    }

    // 2) Bot guruhga qo'shildi → guruh ID'sini e'lon qilamiz.
    if (u.my_chat_member) {
      const chat = u.my_chat_member.chat;
      const status = u.my_chat_member.new_chat_member?.status;
      if (
        (chat.type === 'group' || chat.type === 'supergroup') &&
        (status === 'member' || status === 'administrator')
      ) {
        await this.sendToGroup('sendMessage', {
          chat_id: chat.id,
          text:
            `🤖 Farzandim support bot ulandi.\nGuruh ID: <code>${chat.id}</code>\n` +
            "Shu ID'ni backend .env dagi SUPPORT_CHAT_ID ga yozing.",
          parse_mode: 'HTML',
        });
        this.logger.log(`Bot guruhga qo'shildi: ${chat.id} (${chat.title})`);
      }
      return;
    }

    // 3) Oddiy xabar.
    const m = u.message;
    if (!m) return;

    // Guruh supergroup'ga ko'tarilgan service-xabari → chat ID'ni yangilaymiz.
    if (m.migrate_to_chat_id) {
      this.applyMigration(m.migrate_to_chat_id);
      return;
    }

    // FOYDALANUVCHI DM'i (shaxsiy chat) → operatorlar guruhiga forward.
    if (m.chat.type === 'private') {
      await this.handleUserMessage(m);
      return;
    }

    // OPERATORLAR guruhi (SUPPORT_CHAT_ID) → /id yoki operator javobi (reply).
    if (this.chatId && String(m.chat.id) === String(this.chatId)) {
      await this.handleGroupMessage(m);
    }
  }

  /* ─────────────────── Foydalanuvchi DM'i → GURUH ─────────────────── */

  private displayName(from?: TgUser): string {
    if (!from) return 'Foydalanuvchi';
    const full = [from.first_name, from.last_name].filter(Boolean).join(' ');
    return full || from.username || `id${from.id}`;
  }

  private async handleUserMessage(m: TgMessage) {
    const chatId = String(m.chat.id);

    // /start — xush kelibsiz (forward qilinmaydi).
    if (m.text?.trim().toLowerCase() === '/start') {
      await this.sendToUser('sendMessage', {
        chat_id: chatId,
        text:
          '👋 Assalomu alaykum! <b>Farzandim</b> qo\'llab-quvvatlash ' +
          "xizmatiga xush kelibsiz.\n\nSavol yoki muammoingizni shu yerga " +
          'yozing (matn, rasm yoki fayl) — mutaxassislarimiz tez orada javob ' +
          'berishadi.',
        parse_mode: 'HTML',
      });
      return;
    }

    if (!this.enabled || !this.chatId) return;

    const name = this.displayName(m.from);
    this.nameCache.set(chatId, name);
    const uname = m.from?.username ? ` (@${m.from.username})` : '';
    const header =
      `🆘 <b>Yangi murojaat</b>\n👤 ${this.escapeHtml(name)}${this.escapeHtml(uname)}` +
      `\n🆔 <code>${chatId}</code>`;
    const keyboard = {
      inline_keyboard: [
        [{ text: '✍️ Javob berish', callback_data: `r:${chatId}` }],
      ],
    };

    const hasMedia = Boolean(
      m.photo ||
        m.video ||
        m.document ||
        m.voice ||
        m.audio ||
        m.animation ||
        m.sticker ||
        m.video_note,
    );

    if (!hasMedia) {
      // Oddiy matn — bitta xabar (header + matn + tugma).
      const text = (m.text ?? '').trim();
      const r = await this.sendToGroup<{ message_id: number }>('sendMessage', {
        chat_id: this.chatId,
        text: text ? `${header}\n\n${this.escapeHtml(text)}` : header,
        parse_mode: 'HTML',
        reply_markup: keyboard,
      });
      if (r.ok && r.result) {
        await this.mapReplyTarget(r.result.message_id, chatId);
      } else {
        this.logger.warn(`Guruhga (matn) yuborilmadi: ${r.description}`);
      }
    } else {
      // Media — sarlavha (tugma bilan) + asl media `copyMessage` orqali
      // (rasm/video/pdf/ovoz — har qanday tur, qayta yuklamasdan). Ikkala
      // xabar id ham marshrutga bog'lanadi (tugmaga yoki media'ga reply).
      const head = await this.sendToGroup<{ message_id: number }>(
        'sendMessage',
        {
          chat_id: this.chatId,
          text: header,
          parse_mode: 'HTML',
          reply_markup: keyboard,
        },
      );
      if (head.ok && head.result) {
        await this.mapReplyTarget(head.result.message_id, chatId);
      }
      const copied = await this.sendToGroup<{ message_id: number }>(
        'copyMessage',
        {
          chat_id: this.chatId,
          from_chat_id: chatId,
          message_id: m.message_id,
        },
      );
      if (copied.ok && copied.result) {
        await this.mapReplyTarget(copied.result.message_id, chatId);
      } else {
        this.logger.warn(`Guruhga (media) yuborilmadi: ${copied.description}`);
      }
    }

    // Avto-tasdiq (throttle) — foydalanuvchi murojaati yetganini bilsin.
    const now = Date.now();
    if (now - (this.lastAck.get(chatId) ?? 0) > TelegramSupportService.ACK_THROTTLE_MS) {
      this.lastAck.set(chatId, now);
      await this.sendToUser('sendMessage', {
        chat_id: chatId,
        text:
          '✅ Murojaatingiz qabul qilindi. Mutaxassislarimiz tez orada javob ' +
          'berishadi.',
      });
    }
  }

  /** "javob berish mumkin" guruh xabari id → foydalanuvchi DM chat id. */
  private async mapReplyTarget(messageId: number, chatId: string) {
    await this.prisma.supportTgPrompt
      .upsert({
        where: { promptMessageId: messageId },
        update: { userId: chatId },
        create: { promptMessageId: messageId, userId: chatId },
      })
      .catch((e: Error) =>
        this.logger.warn(`mapReplyTarget xato: ${e.message}`),
      );
  }

  /* ─────────────────── Guruh (operator) tomoni ─────────────────── */

  private async handleReplyButton(cq: TgCallbackQuery) {
    const data = cq.data ?? '';
    await this.api('answerCallbackQuery', { callback_query_id: cq.id }).catch(
      () => undefined,
    );
    if (!data.startsWith('r:') || !this.chatId) return;
    const targetChatId = data.slice(2);
    const name = this.nameCache.get(targetChatId) ?? 'Foydalanuvchi';
    const r = await this.sendToGroup<{ message_id: number }>('sendMessage', {
      chat_id: this.chatId,
      text:
        `✍️ <b>${this.escapeHtml(name)}</b> uchun javobni SHU XABARGA ` +
        '<i>reply</i> qilib yozing (matn yoki rasm/fayl).',
      parse_mode: 'HTML',
      reply_markup: { force_reply: true },
    });
    if (r.ok && r.result) {
      await this.mapReplyTarget(r.result.message_id, targetChatId);
    }
  }

  private async handleGroupMessage(m: TgMessage) {
    if (m.text?.trim().startsWith('/id')) {
      await this.sendToGroup('sendMessage', {
        chat_id: m.chat.id,
        text: `Chat ID: <code>${m.chat.id}</code>`,
        parse_mode: 'HTML',
      });
      return;
    }

    // Operator javobi — faqat REPLY bo'lsa (bizning forward/prompt xabarimizga).
    const replyTo = m.reply_to_message?.message_id;
    if (!replyTo) return;

    const prompt = await this.prisma.supportTgPrompt.findUnique({
      where: { promptMessageId: replyTo },
    });
    const targetChatId = prompt?.userId;
    if (!targetChatId) return; // bizning marshrut xabarimizga reply emas

    // Operator javobini (matn YOKI media — har qanday tur) foydalanuvchining
    // DM'iga AYNAN nusxalab yetkazamiz (copyMessage: hajm/tur cheklovisiz).
    const relayed = await this.sendToUser<{ message_id: number }>(
      'copyMessage',
      {
        chat_id: targetChatId,
        from_chat_id: m.chat.id,
        message_id: m.message_id,
      },
    );

    if (relayed.ok) {
      await this.sendToGroup('sendMessage', {
        chat_id: this.chatId,
        text: '✅ Yetkazildi',
        reply_parameters: { message_id: m.message_id },
      });
    } else {
      // 403 = foydalanuvchi botni bloklagan / hech qachon /start bosmagan.
      const blocked = /blocked|deactivated|can't initiate|not found/i.test(
        relayed.description ?? '',
      );
      await this.sendToGroup('sendMessage', {
        chat_id: this.chatId,
        text: blocked
          ? "⚠️ Yetkazib bo'lmadi — foydalanuvchi botni bloklagan yoki " +
            "hali /start bosmagan."
          : `⚠️ Yetkazib bo'lmadi: ${this.escapeHtml(relayed.description ?? 'xato')}`,
        reply_parameters: { message_id: m.message_id },
      });
    }
  }
}

/* ─────────── Telegram tiplari (minimal, faqat keraklisi) ─────────── */

interface TgResponse<T> {
  ok: boolean;
  result?: T;
  description?: string;
  parameters?: { retry_after?: number; migrate_to_chat_id?: number };
}

interface TgChat {
  id: number;
  type: string;
  title?: string;
}

interface TgUser {
  id: number;
  first_name?: string;
  last_name?: string;
  username?: string;
}

interface TgMessage {
  message_id: number;
  chat: TgChat;
  from?: TgUser;
  text?: string;
  caption?: string;
  reply_to_message?: { message_id: number };
  // Media turlari (borligini aniqlash uchun — mazmuni copyMessage bilan ketadi).
  photo?: unknown[];
  document?: unknown;
  video?: unknown;
  voice?: unknown;
  audio?: unknown;
  animation?: unknown;
  sticker?: unknown;
  video_note?: unknown;
  // Guruh supergroup'ga ko'tarilganda keladi (yangi chat ID).
  migrate_to_chat_id?: number;
}

interface TgCallbackQuery {
  id: string;
  data?: string;
  message?: TgMessage;
}

interface TgUpdate {
  update_id: number;
  message?: TgMessage;
  callback_query?: TgCallbackQuery;
  my_chat_member?: {
    chat: TgChat;
    new_chat_member?: { status: string };
  };
}
