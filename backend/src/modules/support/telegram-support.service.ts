import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../common/database/prisma.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { FcmService } from '../../common/fcm/fcm.service';
import { EnvConfig } from '../../common/config/env.schema';

/**
 * Support chat ⇄ Telegram guruh ko'prigi.
 *
 * Oqim:
 *  1. Ota-ona ilovada yozadi → SupportService saqlaydi → bu servis xabarni
 *     operatorlar GURUHIGA yuboradi (rasm/video/hujjat HAQIQIY media bilan,
 *     "✍️ Javob berish" inline tugma).
 *  2. Operator tugmani bosadi → bot ForceReply prompt yuboradi → operator
 *     SHU promptga (yoki asl xabarga swipe-reply) javob yozadi.
 *  3. Bot javobni user'ga yetkazadi: DB + WS `support:message` (DARHOL) +
 *     FCM push (fonda). Guruhda "✅ Yetkazildi".
 *
 * MUHIM ishonchlilik qoidalari:
 *  - Barcha GURUHGA yuborishlar BITTA NAVBAT orqali ketadi (serial) — Telegram
 *    per-chat flood-control'i parallel yuborishda xabarni tushirib yuborardi
 *    ("ikkitadan bittasi bormaydi" muammosi). Navbat + 429 retry buni yo'qotadi.
 *  - `getUpdates` (25s long-poll) navbatdan TASHQARI — aks holda yuborishni
 *    25s bloklardi.
 *  - Token/chat-id .env'da bo'lmasa servis jim o'chiq (chat baribir saqlanadi).
 */
@Injectable()
export class TelegramSupportService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(TelegramSupportService.name);

  private token?: string;
  private chatId?: string;
  private enabled = false;
  private stopped = false;
  private offset = 0;

  // Guruhga yuborishlar navbati (serial) — flood-control'dan himoya.
  private sendChain: Promise<unknown> = Promise.resolve();

  constructor(
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
    private readonly fcm: FcmService,
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
          "guruhga yuborilmaydi. Botni guruhga qo'shing: u ID'ni e'lon qiladi.",
      );
    }
    const state = await this.prisma.supportTgState.upsert({
      where: { id: 1 },
      update: {},
      create: { id: 1, offset: 0 },
    });
    this.offset = state.offset;
    void this.pollLoop();
    this.logger.log('Support Telegram polling boshlandi');
  }

  onModuleDestroy() {
    this.stopped = true;
  }

  /* ───────────────────────── Telegram API ───────────────────────── */

  /** Xom Telegram API chaqiruvi (getUpdates uchun — navbatsiz, retry'siz). */
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

  /** API + 429 (flood) va tarmoq xatosida qayta urinish. */
  private async callWithRetry<T = unknown>(
    method: string,
    body: Record<string, unknown>,
    attempts = 3,
  ): Promise<TgResponse<T>> {
    for (let i = 0; i < attempts; i++) {
      try {
        const r = await this.api<T>(method, body, 20_000);
        if (r.ok) return r;
        const retryAfter = r.parameters?.retry_after;
        if (retryAfter && i < attempts - 1) {
          await this.sleep(retryAfter * 1000 + 300);
          continue;
        }
        // 429'dan boshqa xato (masalan media URL yetib bo'lmadi) — qaytaramiz.
        return r;
      } catch (e) {
        if (i < attempts - 1) {
          await this.sleep(800);
          continue;
        }
        this.logger.warn(`${method} tarmoq xato: ${(e as Error).message}`);
        return { ok: false, description: (e as Error).message };
      }
    }
    return { ok: false };
  }

  /**
   * Guruhga yuborish — NAVBAT orqali (bittadan), retry bilan. Parallel
   * yuborishlar bir-birini tushirib yubormasligi uchun ketma-ket ishlaydi.
   */
  private sendQueued<T = unknown>(
    method: string,
    body: Record<string, unknown>,
  ): Promise<TgResponse<T>> {
    const run = this.sendChain.then(
      () => this.callWithRetry<T>(method, body),
      () => this.callWithRetry<T>(method, body),
    );
    // Navbatni hech qachon "rejected"da qoldirmaymiz (keyingilar bloklanmasin).
    this.sendChain = run.then(
      () => undefined,
      () => undefined,
    );
    return run;
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

  /* ─────────────────── User xabari → GURUHGA ─────────────────── */

  /**
   * Yangi user xabarini operatorlar guruhiga yuboradi. Rasm/video/hujjat —
   * HAQIQIY media (sendPhoto/sendVideo/sendDocument), shu sababli operator
   * guruhda darhol ko'radi. Media yetkazilmasa (katta fayl/URL) — matn+havola
   * zaxira. Muvaffaqiyatda guruh message_id qaytadi (swipe-reply routing).
   */
  async notifyNewUserMessage(params: {
    userId: string;
    text?: string | null;
    attachmentType?: string | null;
    fileName?: string | null;
    attachmentKey?: string | null;
  }): Promise<number | null> {
    if (!this.enabled || !this.chatId) return null;
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: params.userId },
        select: { name: true, phone: true, email: true },
      });
      const who = this.escapeHtml(
        [user?.name, user?.phone ?? user?.email].filter(Boolean).join(' · ') ||
          params.userId,
      );
      const header = `🆘 <b>Yangi murojaat</b>\n👤 ${who}`;
      const keyboard = {
        inline_keyboard: [
          [{ text: '✍️ Javob berish', callback_data: `r:${params.userId}` }],
        ],
      };

      // ── Biriktirma: haqiqiy media yuboramiz ──
      if (params.attachmentType && params.attachmentKey) {
        const base = this.config.get('PUBLIC_BASE_URL', { infer: true });
        const url = `${base}/api/support/attachments/${encodeURIComponent(
          params.attachmentKey,
        )}`;
        const caption =
          `${header}\n📎 ${this.escapeHtml(params.fileName ?? 'fayl')}` +
          (params.text ? `\n\n${this.escapeHtml(params.text)}` : '');

        const map: Record<string, { method: string; field: string }> = {
          image: { method: 'sendPhoto', field: 'photo' },
          video: { method: 'sendVideo', field: 'video' },
          document: { method: 'sendDocument', field: 'document' },
        };
        const m = map[params.attachmentType] ?? map.document;
        const r = await this.sendQueued<{ message_id: number }>(m.method, {
          chat_id: this.chatId,
          [m.field]: url,
          caption,
          parse_mode: 'HTML',
          reply_markup: keyboard,
        });
        if (r.ok) return r.result?.message_id ?? null;
        // Media yetkazilmadi (katta/URL) → matn + havola zaxira.
        this.logger.warn(`Media yuborilmadi (${m.method}): ${r.description}`);
        const fb = await this.sendQueued<{ message_id: number }>(
          'sendMessage',
          {
            chat_id: this.chatId,
            text: `${caption}\n<a href="${url}">Faylni ochish</a>`,
            parse_mode: 'HTML',
            reply_markup: keyboard,
          },
        );
        return fb.ok ? (fb.result?.message_id ?? null) : null;
      }

      // ── Oddiy matn ──
      const r = await this.sendQueued<{ message_id: number }>('sendMessage', {
        chat_id: this.chatId,
        text: `${header}\n\n${this.escapeHtml(params.text ?? '')}`,
        parse_mode: 'HTML',
        reply_markup: keyboard,
      });
      if (!r.ok) {
        this.logger.warn(`Guruhga yuborilmadi: ${r.description}`);
        return null;
      }
      return r.result?.message_id ?? null;
    } catch (e) {
      this.logger.warn(`notifyNewUserMessage xato: ${(e as Error).message}`);
      return null;
    }
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
    // 1) "✍️ Javob berish" tugmasi → ForceReply prompt.
    if (u.callback_query) {
      const cq = u.callback_query;
      const data = cq.data ?? '';
      // answerCallbackQuery — xom (tezkor, navbatsiz).
      await this.api('answerCallbackQuery', { callback_query_id: cq.id }).catch(
        () => undefined,
      );
      if (!data.startsWith('r:') || !this.chatId) return;
      const userId = data.slice(2);
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { name: true },
      });
      const r = await this.sendQueued<{ message_id: number }>('sendMessage', {
        chat_id: this.chatId,
        text:
          `✍️ <b>${this.escapeHtml(user?.name ?? 'Foydalanuvchi')}</b> uchun ` +
          'javobni SHU XABARGA <i>reply</i> qilib yozing.',
        parse_mode: 'HTML',
        reply_markup: { force_reply: true },
      });
      if (r.ok && r.result) {
        await this.prisma.supportTgPrompt.create({
          data: { promptMessageId: r.result.message_id, userId },
        });
      }
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
        await this.sendQueued('sendMessage', {
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

    // /id — har qanday chatda chat ID'ni qaytaradi (sozlash yordami).
    if (m.text?.trim().startsWith('/id')) {
      await this.sendQueued('sendMessage', {
        chat_id: m.chat.id,
        text: `Chat ID: <code>${m.chat.id}</code>`,
        parse_mode: 'HTML',
      });
      return;
    }

    // Operator javobi — faqat support guruhidan va faqat REPLY bo'lsa.
    if (!this.chatId || String(m.chat.id) !== String(this.chatId)) return;
    const replyTo = m.reply_to_message?.message_id;
    if (!replyTo) return;

    // Routing: ForceReply prompt'imizga reply → prompt jadvalidan; aks holda
    // asl murojaat xabariga (bot yuborgan) swipe-reply → tgMessageId.
    let userId: string | null = null;
    const prompt = await this.prisma.supportTgPrompt.findUnique({
      where: { promptMessageId: replyTo },
    });
    if (prompt) {
      userId = prompt.userId;
    } else {
      const original = await this.prisma.supportMessage.findFirst({
        where: { tgMessageId: replyTo },
        select: { userId: true },
      });
      userId = original?.userId ?? null;
    }
    if (!userId) return; // bizning xabarlarga reply emas — e'tiborsiz

    // Javob bizning xabarimizga, lekin matnsiz (operator rasm/fayl yubordi) —
    // hozircha faqat MATN javob yetkaziladi; jim yo'qotmasdan operatorni
    // ogohlantiramiz (media javob keyingi bosqichda qo'shiladi).
    const replyText = (m.text ?? m.caption ?? '').trim();
    if (!replyText) {
      await this.sendQueued('sendMessage', {
        chat_id: this.chatId,
        text: '⚠️ Hozircha faqat MATN javob yetkaziladi. Iltimos matn yozing.',
        reply_parameters: { message_id: m.message_id },
      });
      return;
    }

    await this.deliverOperatorReply(userId, replyText, m.message_id);
  }

  /** Operator javobini user'ga yetkazadi: DB + WS (DARHOL) + FCM (fonda). */
  private async deliverOperatorReply(
    userId: string,
    text: string,
    operatorTgMessageId: number,
  ) {
    const saved = await this.prisma.supportMessage.create({
      data: { userId, sender: 'operator', text },
    });

    // WS — ilova ochiq bo'lsa DARHOL ko'rinadi (asosiy tezkor yo'l).
    this.realtime.emitToUser(userId, 'support:message', {
      id: saved.id,
      sender: 'operator',
      text: saved.text,
      createdAt: saved.createdAt.toISOString(),
    });

    // FCM push — FONDA (await YO'Q): poll loop'ni bloklamasin, keyingi
    // javoblar tez kelsin. Ilova yopiq bo'lsa bildirishnoma keladi.
    void this.sendSupportPush(userId, text);

    // Guruhda tasdiq — navbat orqali.
    await this.sendQueued('sendMessage', {
      chat_id: this.chatId,
      text: '✅ Yetkazildi',
      reply_parameters: { message_id: operatorTgMessageId },
    });
  }

  private async sendSupportPush(userId: string, text: string) {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { language: true },
      });
      const titles: Record<string, string> = {
        uz: "Qo'llab-quvvatlash javob berdi",
        ru: 'Поддержка ответила',
        en: 'Support replied',
      };
      await this.fcm.sendPushToUser(userId, {
        title: titles[user?.language ?? 'uz'] ?? titles.uz,
        body: text.length > 120 ? `${text.slice(0, 117)}...` : text,
        data: { type: 'support' },
      });
    } catch (e) {
      this.logger.warn(`support push xato: ${(e as Error).message}`);
    }
  }
}

/* ─────────── Telegram tiplari (minimal, faqat keraklisi) ─────────── */

interface TgResponse<T> {
  ok: boolean;
  result?: T;
  description?: string;
  parameters?: { retry_after?: number };
}

interface TgChat {
  id: number;
  type: string;
  title?: string;
}

interface TgMessage {
  message_id: number;
  chat: TgChat;
  text?: string;
  caption?: string;
  reply_to_message?: { message_id: number };
}

interface TgUpdate {
  update_id: number;
  message?: TgMessage;
  callback_query?: { id: string; data?: string; message?: TgMessage };
  my_chat_member?: {
    chat: TgChat;
    new_chat_member?: { status: string };
  };
}
