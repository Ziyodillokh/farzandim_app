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
 *     operatorlar GURUHIGA yuboradi ("✍️ Javob berish" inline tugma bilan).
 *  2. Operator tugmani bosadi → bot ForceReply prompt yuboradi → operator
 *     SHU promptga (yoki asl xabarga swipe-reply) javob yozadi.
 *  3. Bot javobni qabul qilib user'ga yetkazadi: DB'ga saqlaydi, WS
 *     `support:message` event + FCM push. Guruhda "✅ Yetkazildi" tasdiqlanadi.
 *
 * Texnika: WEBHOOK EMAS — long-polling (getUpdates, 25s). Public URL/secret
 * sozlamasiz har qanday muhitda ishlaydi. Offset DB'da (restart'da yo'qolmaydi).
 * Token/chat-id .env'da bo'lmasa servis jim o'chiq turadi (chat baribir saqlanadi).
 *
 * Yordam: guruhga /id yozilsa bot chat ID'ni qaytaradi; bot yangi guruhga
 * qo'shilganda ham ID'ni e'lon qiladi — .env SUPPORT_CHAT_ID'ni to'g'rilash oson.
 */
@Injectable()
export class TelegramSupportService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(TelegramSupportService.name);

  private token?: string;
  private chatId?: string;
  private enabled = false;
  private stopped = false;
  private offset = 0;

  constructor(
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
    private readonly fcm: FcmService,
  ) {}

  async onModuleInit() {
    this.token = this.config.get('TELEGRAM_BOT_TOKEN_SUPPORT', {
      infer: true,
    });
    this.chatId = this.config.get('SUPPORT_CHAT_ID', { infer: true });
    this.enabled = Boolean(this.token);
    if (!this.enabled) {
      this.logger.log('Support Telegram bot o\'chiq (env yo\'q) — skip');
      return;
    }
    if (!this.chatId) {
      this.logger.warn(
        'TELEGRAM_BOT_TOKEN_SUPPORT bor, lekin SUPPORT_CHAT_ID yo\'q — ' +
          'guruhga yuborilmaydi. Botni guruhga qo\'shing: u ID\'ni e\'lon qiladi.',
      );
    }
    // Offset'ni DB'dan tiklaymiz (restart'da eski update'lar qayta kelmasin).
    const state = await this.prisma.supportTgState.upsert({
      where: { id: 1 },
      update: {},
      create: { id: 1, offset: 0 },
    });
    this.offset = state.offset;
    // Polling loop — fonda (await YO'Q), xato bo'lsa o'zi qayta uradi.
    void this.pollLoop();
    this.logger.log('Support Telegram polling boshlandi');
  }

  onModuleDestroy() {
    this.stopped = true;
  }

  /* ───────────────────────── Telegram API ───────────────────────── */

  private async api<T = unknown>(
    method: string,
    body?: Record<string, unknown>,
    timeoutMs = 35_000,
  ): Promise<{ ok: boolean; result?: T; description?: string }> {
    const res = await fetch(
      `https://api.telegram.org/bot${this.token}/${method}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: body ? JSON.stringify(body) : undefined,
        signal: AbortSignal.timeout(timeoutMs),
      },
    );
    return (await res.json()) as {
      ok: boolean;
      result?: T;
      description?: string;
    };
  }

  private escapeHtml(s: string): string {
    return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  }

  /* ─────────────────── User xabari → GURUHGA ─────────────────── */

  /**
   * Yangi user xabarini operatorlar guruhiga yuboradi.
   * Muvaffaqiyatda guruhdagi message_id qaytadi (swipe-reply routing uchun).
   * Har qanday xato faqat log — chat oqimini hech qachon buzmaydi.
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

      let body: string;
      if (params.attachmentType) {
        const emoji =
          params.attachmentType === 'image'
            ? '🖼'
            : params.attachmentType === 'video'
              ? '🎬'
              : '📄';
        const base = this.config.get('PUBLIC_BASE_URL', { infer: true });
        const link = params.attachmentKey
          ? `\n<a href="${base}/api/support/attachments/${encodeURIComponent(
              params.attachmentKey,
            )}">Faylni ochish</a>`
          : '';
        body = `${emoji} <i>${this.escapeHtml(
          params.fileName ?? 'fayl',
        )}</i>${link}`;
      } else {
        body = this.escapeHtml(params.text ?? '');
      }

      const r = await this.api<{ message_id: number }>('sendMessage', {
        chat_id: this.chatId,
        text: `🆘 <b>Yangi murojaat</b>\n👤 ${who}\n\n${body}`,
        parse_mode: 'HTML',
        reply_markup: {
          inline_keyboard: [
            [{ text: '✍️ Javob berish', callback_data: `r:${params.userId}` }],
          ],
        },
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
        // Tarmoq/timeout — kutib qayta uramiz (loop hech qachon o'lmaydi).
        if (!this.stopped) {
          this.logger.debug(`poll xato: ${(e as Error).message}`);
          await this.sleep(3000);
        }
      }
    }
  }

  private sleep(ms: number) {
    return new Promise((r) => setTimeout(r, ms));
  }

  /* ───────────────────────── Update handling ───────────────────────── */

  private async handleUpdate(u: TgUpdate) {
    // 1) "✍️ Javob berish" tugmasi → ForceReply prompt.
    if (u.callback_query) {
      const cq = u.callback_query;
      const data = cq.data ?? '';
      await this.api('answerCallbackQuery', { callback_query_id: cq.id });
      if (!data.startsWith('r:') || !this.chatId) return;
      const userId = data.slice(2);
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { name: true },
      });
      const r = await this.api<{ message_id: number }>('sendMessage', {
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

    // 2) Bot guruhga qo'shildi → guruh ID'sini e'lon qilamiz (.env uchun).
    if (u.my_chat_member) {
      const chat = u.my_chat_member.chat;
      const status = u.my_chat_member.new_chat_member?.status;
      if (
        (chat.type === 'group' || chat.type === 'supergroup') &&
        (status === 'member' || status === 'administrator')
      ) {
        await this.api('sendMessage', {
          chat_id: chat.id,
          text:
            `🤖 Farzandim support bot ulandi.\nGuruh ID: <code>${chat.id}</code>\n` +
            'Shu ID\'ni backend .env dagi SUPPORT_CHAT_ID ga yozing.',
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
      await this.api('sendMessage', {
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
    const replyText = (m.text ?? m.caption ?? '').trim();
    if (!replyText) return;

    // Routing: ForceReply prompt'imizga reply → prompt jadvalidan;
    // aks holda asl murojaat xabariga (bot yuborgan) swipe-reply → tgMessageId.
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

    await this.deliverOperatorReply(userId, replyText, m.message_id);
  }

  /** Operator javobini user'ga yetkazadi: DB + WS + FCM + guruhda tasdiq. */
  private async deliverOperatorReply(
    userId: string,
    text: string,
    operatorTgMessageId: number,
  ) {
    const saved = await this.prisma.supportMessage.create({
      data: { userId, sender: 'operator', text },
    });

    // WS — ilova ochiq bo'lsa darhol ko'rinadi.
    this.realtime.emitToUser(userId, 'support:message', {
      id: saved.id,
      sender: 'operator',
      text: saved.text,
      createdAt: saved.createdAt.toISOString(),
    });

    // FCM push — ilova yopiq bo'lsa ham bildirishnoma keladi (user tilida).
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

    // Guruhda tasdiq — operator javob yetganini ko'radi.
    await this.api('sendMessage', {
      chat_id: this.chatId,
      text: '✅ Yetkazildi',
      reply_parameters: { message_id: operatorTgMessageId },
    });
  }
}

/* ─────────── Telegram update tiplari (minimal, faqat keraklisi) ─────────── */

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
