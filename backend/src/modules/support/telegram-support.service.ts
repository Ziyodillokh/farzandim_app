import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { extname } from 'path';
import { PrismaService } from '../../common/database/prisma.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { FcmService } from '../../common/fcm/fcm.service';
import { StorageService } from '../../common/storage/storage.service';
import { BUCKETS } from '../../common/storage/storage.constants';
import { EnvConfig } from '../../common/config/env.schema';

/**
 * Support chat ⇄ Telegram guruh ko'prigi (ikki tomonlama, media bilan).
 *
 * User → guruh: matn yoki biriktirma (rasm/video/hujjat) — biriktirma MinIO'dan
 *   o'qilib HAQIQIY BAYT (multipart) bilan yuboriladi (URL-reachability'ga
 *   bog'liq emas → hujjat ham ishonchli yetadi).
 * Guruh → user: operator "✍️ Javob berish" → matn YOKI rasm/fayl bilan reply
 *   qiladi → bot faylni yuklab MinIO'ga saqlaydi → user'ga DB + WS + FCM.
 *
 * Ishonchlilik: barcha guruhga yuborishlar BITTA NAVBAT (serial) orqali +
 * 429/tarmoq retry. getUpdates (25s long-poll) navbatdan tashqari.
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

  // Telegram media bot-API yuklab olish chegaralari (taxminiy, xavfsiz).
  private static readonly MAX_PHOTO = 10 * 1024 * 1024;
  private static readonly MAX_FILE = 50 * 1024 * 1024;

  constructor(
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
    private readonly fcm: FcmService,
    private readonly storage: StorageService,
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
    // Ishga tushganda chat ID hali ham to'g'rimi — tekshiramiz (guruh
    // supergroup'ga ko'tarilgan bo'lsa avtomatik yangilanadi).
    await this.healChatId();
    void this.pollLoop();
    this.logger.log('Support Telegram polling boshlandi');
  }

  onModuleDestroy() {
    this.stopped = true;
  }

  /* ───────────────────────── Telegram API ───────────────────────── */

  /** Xom JSON API chaqiruvi (getUpdates/getFile uchun — navbatsiz). */
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

  /** Multipart (fayl bayt) API chaqiruvi — sendPhoto/sendDocument/sendVideo. */
  private async apiMultipart<T = unknown>(
    method: string,
    fields: Record<string, string>,
    fileField: string,
    buffer: Buffer,
    fileName: string,
    mimeType: string,
    timeoutMs = 90_000,
  ): Promise<TgResponse<T>> {
    const form = new FormData();
    for (const [k, v] of Object.entries(fields)) form.append(k, v);
    // Buffer → Uint8Array (yangi ArrayBuffer) — Blob TS tipiga mos.
    form.append(
      fileField,
      new Blob([new Uint8Array(buffer)], {
        type: mimeType || 'application/octet-stream',
      }),
      fileName,
    );
    const res = await fetch(
      `https://api.telegram.org/bot${this.token}/${method}`,
      { method: 'POST', body: form, signal: AbortSignal.timeout(timeoutMs) },
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

  /**
   * Guruh basic→supergroup'ga ko'tarilsa chat ID o'zgaradi va eski ID bilan
   * BARCHA yuborish/javob buziladi. Telegram javobida `migrate_to_chat_id`
   * keladi — uni ushlab chat ID'ni AVTOMATIK yangilaymiz (server .env'ga
   * qo'l tegizish shart emas, kelajakda yana o'zgarsa ham o'zini tuzatadi).
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
      const r = await this.api('sendChatAction', {
        chat_id: this.chatId,
        action: 'typing',
      }, 10_000);
      if (!r.ok && r.parameters?.migrate_to_chat_id) {
        this.applyMigration(r.parameters.migrate_to_chat_id);
      }
    } catch {
      // tarmoq xato — runtime'da send/inbound heal qiladi.
    }
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
   * Guruhga JSON yuborish (matn) — SERIAL navbat (tartib + flood himoya) +
   * supergroup migratsiyada chat ID'ni yangilab QAYTA uradi. body.chat_id
   * this.chatId bo'lsa migratsiya qo'llanadi.
   */
  private sendQueued<T = unknown>(
    method: string,
    body: Record<string, unknown>,
  ): Promise<TgResponse<T>> {
    return this.enqueue(() => this.sendWithMigration<T>(method, body, false));
  }

  /**
   * Guruhga FAYL (multipart) yuborish — navbatdan TASHQARI (concurrent), shunda
   * katta fayl yuklash matn xabarlarini bloklamaydi ("sekin" muammosi). Flood
   * 429/migratsiya retry bilan qoplanadi.
   */
  private sendFileQueued<T = unknown>(
    method: string,
    fields: Record<string, string>,
    fileField: string,
    buffer: Buffer,
    fileName: string,
    mimeType: string,
  ): Promise<TgResponse<T>> {
    // MUHIM: media ham SERIAL navbatda (matn bilan bitta zanjir) — bitta
    // supergroup'ga parallel yuborish Telegram flood-control'iga (429) tushib
    // FAYL yoki keyingi MATNNI tushirib yuborardi. Fayl MinIO'dan oldin o'qilgan
    // (getObject navbatdan tashqari), faqat Telegram'ga yuborish navbatda.
    return this.enqueue(() =>
      this.sendWithMigration<T>(method, { ...fields }, true, {
        fileField,
        buffer,
        fileName,
        mimeType,
      }),
    );
  }

  /** Yuborish + 429/tarmoq retry + supergroup migratsiya heal (1 qayta urinish). */
  private async sendWithMigration<T = unknown>(
    method: string,
    body: Record<string, unknown>,
    isFile: boolean,
    file?: {
      fileField: string;
      buffer: Buffer;
      fileName: string;
      mimeType: string;
    },
  ): Promise<TgResponse<T>> {
    let payload = body;
    for (let attempt = 0; attempt < 2; attempt++) {
      const r = await this.withRetry<T>(() =>
        isFile
          ? this.apiMultipart<T>(
              method,
              payload as Record<string, string>,
              file!.fileField,
              file!.buffer,
              file!.fileName,
              file!.mimeType,
            )
          : this.api<T>(method, payload, 20_000),
      );
      if (r.ok) return r;
      const mig = r.parameters?.migrate_to_chat_id;
      // Faqat GURUHGA yuborishda (chat_id === this.chatId) migratsiya qo'llanadi.
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
    return { ok: false };
  }

  private escapeHtml(s: string): string {
    return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  }

  /**
   * Media caption'ni Telegram 1024-belgi limitiga keltiradi — oshsa sendDocument
   * 400 ("caption is too long") beradi va FAYL umuman ketmaydi. Oxiridagi yarim
   * HTML entity'ni (`&...`) olib tashlaydi (tag'lar faqat boshda — kesilmaydi).
   */
  private clampCaption(s: string): string {
    if (s.length <= 1024) return s;
    let cut = s.slice(0, 1020);
    const amp = cut.lastIndexOf('&');
    if (amp > cut.lastIndexOf(';')) cut = cut.slice(0, amp);
    return `${cut}…`;
  }

  private sleep(ms: number) {
    return new Promise((r) => setTimeout(r, ms));
  }

  /* ─────────────────── User xabari → GURUHGA ─────────────────── */

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

      // ── Biriktirma: MinIO'dan bayt o'qib MULTIPART yuboramiz (ishonchli) ──
      if (params.attachmentType && params.attachmentKey) {
        const caption = this.clampCaption(
          `${header}\n📎 ${this.escapeHtml(params.fileName ?? 'fayl')}` +
            (params.text ? `\n\n${this.escapeHtml(params.text)}` : ''),
        );
        const map: Record<
          string,
          { method: string; field: string; max: number }
        > = {
          image: {
            method: 'sendPhoto',
            field: 'photo',
            max: TelegramSupportService.MAX_PHOTO,
          },
          video: {
            method: 'sendVideo',
            field: 'video',
            max: TelegramSupportService.MAX_FILE,
          },
          document: {
            method: 'sendDocument',
            field: 'document',
            max: TelegramSupportService.MAX_FILE,
          },
        };
        const m = map[params.attachmentType] ?? map.document;
        try {
          const obj = await this.storage.getObject(
            BUCKETS.support,
            params.attachmentKey,
          );
          if (obj.body.length <= m.max) {
            const r = await this.sendFileQueued<{ message_id: number }>(
              m.method,
              {
                chat_id: this.chatId,
                caption,
                parse_mode: 'HTML',
                reply_markup: JSON.stringify(keyboard),
              },
              m.field,
              obj.body,
              params.fileName ?? 'fayl',
              obj.contentType,
            );
            if (r.ok) return r.result?.message_id ?? null;
            this.logger.warn(`Media yuborilmadi (${m.method}): ${r.description}`);
          }
        } catch (e) {
          this.logger.warn(`Media o'qib bo'lmadi: ${(e as Error).message}`);
        }
        // Zaxira: matn + havola (juda katta yoki xato bo'lsa).
        const base = this.config.get('PUBLIC_BASE_URL', { infer: true });
        const url = `${base}/api/support/attachments/${encodeURIComponent(
          params.attachmentKey,
        )}`;
        const fb = await this.sendQueued<{ message_id: number }>('sendMessage', {
          chat_id: this.chatId,
          text: `${caption}\n<a href="${url}">Faylni ochish</a>`,
          parse_mode: 'HTML',
          reply_markup: keyboard,
        });
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
          'javobni SHU XABARGA <i>reply</i> qilib yozing (matn yoki rasm/fayl).',
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

    // Guruh supergroup'ga ko'tarilgan service-xabari → chat ID'ni yangilaymiz.
    if (m.migrate_to_chat_id) {
      this.applyMigration(m.migrate_to_chat_id);
      return;
    }

    if (m.text?.trim().startsWith('/id')) {
      await this.sendQueued('sendMessage', {
        chat_id: m.chat.id,
        text: `Chat ID: <code>${m.chat.id}</code>`,
        parse_mode: 'HTML',
      });
      return;
    }

    // Operator javobi — faqat support guruhidan va faqat REPLY bo'lsa. Chat ID
    // boot-probe + send-heal + migrate-service-xabar orqali DOIM joriy
    // (migratsiya self-heal), shuning uchun bu filtr xavfsiz va boshqa guruhdan
    // noto'g'ri marshrutni (cross-group) to'sadi — migratsiyani FAQAT rasmiy
    // Telegram signallari qiladi, message_id taxmini emas.
    if (!this.chatId || String(m.chat.id) !== String(this.chatId)) return;
    const replyTo = m.reply_to_message?.message_id;
    if (!replyTo) return;

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

    const replyText = (m.text ?? m.caption ?? '').trim();
    const media = this.extractMedia(m);

    if (media) {
      await this.deliverOperatorMedia(userId, replyText, media, m.message_id);
      return;
    }
    if (!replyText) {
      // matnsiz, mediasiz reply — hech narsa yetkazmaymiz (e'tiborsiz).
      return;
    }
    await this.deliverOperatorReply(userId, replyText, m.message_id);
  }

  /** Operator xabaridagi media'ni aniqlaydi (rasm/video/hujjat). */
  private extractMedia(m: TgMessage): {
    type: string;
    fileId: string;
    fileName: string;
    mimeType: string;
  } | null {
    if (m.photo && m.photo.length > 0) {
      const largest = m.photo[m.photo.length - 1];
      return {
        type: 'image',
        fileId: largest.file_id,
        fileName: 'rasm.jpg',
        mimeType: 'image/jpeg',
      };
    }
    if (m.document) {
      const mt = m.document.mime_type ?? 'application/octet-stream';
      const type = mt.startsWith('image/')
        ? 'image'
        : mt.startsWith('video/')
          ? 'video'
          : 'document';
      return {
        type,
        fileId: m.document.file_id,
        fileName: m.document.file_name ?? 'fayl',
        mimeType: mt,
      };
    }
    if (m.video) {
      return {
        type: 'video',
        fileId: m.video.file_id,
        fileName: m.video.file_name ?? 'video.mp4',
        mimeType: m.video.mime_type ?? 'video/mp4',
      };
    }
    return null;
  }

  /** Telegram faylini yuklab oladi (getFile → file_path → download). */
  private async downloadTelegramFile(fileId: string): Promise<Buffer | null> {
    const r = await this.api<{ file_path?: string }>(
      'getFile',
      { file_id: fileId },
      20_000,
    );
    if (!r.ok || !r.result?.file_path) {
      this.logger.warn(`getFile xato: ${r.description ?? "file_path yo'q"}`);
      return null;
    }
    const fileUrl = `https://api.telegram.org/file/bot${this.token}/${r.result.file_path}`;
    try {
      const res = await fetch(fileUrl, { signal: AbortSignal.timeout(90_000) });
      if (!res.ok) {
        this.logger.warn(`Fayl download HTTP ${res.status}`);
        return null;
      }
      return Buffer.from(await res.arrayBuffer());
    } catch (e) {
      this.logger.warn(`Fayl download xato: ${(e as Error).message}`);
      return null;
    }
  }

  /** Operator media javobini yuklab MinIO'ga saqlaydi va user'ga yetkazadi. */
  private async deliverOperatorMedia(
    userId: string,
    text: string,
    media: { type: string; fileId: string; fileName: string; mimeType: string },
    operatorTgMessageId: number,
  ) {
    const buffer = await this.downloadTelegramFile(media.fileId);
    if (!buffer) {
      // Operatorni limit haqida ogohlantiramiz; izoh (matn) bo'lsa hech
      // bo'lmasa shuni user'ga yetkazamiz (butunlay quruq qolmasin).
      await this.sendQueued('sendMessage', {
        chat_id: this.chatId,
        text:
          "⚠️ Faylni yetkazib bo'lmadi (Telegram bot limiti ~20MB). " +
          'Kichikroq fayl yoki havola yuboring.',
        reply_parameters: { message_id: operatorTgMessageId },
      });
      if (text) {
        await this.deliverOperatorReply(userId, text, operatorTgMessageId);
      }
      return;
    }
    const ext = extname(media.fileName) || '';
    const key = `${userId}_${randomUUID()}${ext}`;
    try {
      await this.storage.upload(BUCKETS.support, key, buffer, media.mimeType);
    } catch (e) {
      this.logger.warn(`Operator media saqlash xato: ${(e as Error).message}`);
      await this.sendQueued('sendMessage', {
        chat_id: this.chatId,
        text: '⚠️ Faylni saqlashda xatolik.',
        reply_parameters: { message_id: operatorTgMessageId },
      });
      return;
    }
    await this.deliverOperatorReply(userId, text || null, operatorTgMessageId, {
      attachmentKey: key,
      attachmentType: media.type,
      fileName: media.fileName,
      fileSize: buffer.length,
      mimeType: media.mimeType,
    });
  }

  /** Operator javobini user'ga yetkazadi: DB + WS (DARHOL) + FCM (fonda). */
  private async deliverOperatorReply(
    userId: string,
    text: string | null,
    operatorTgMessageId: number,
    attachment?: {
      attachmentKey: string;
      attachmentType: string;
      fileName: string;
      fileSize: number;
      mimeType: string;
    },
  ) {
    const saved = await this.prisma.supportMessage.create({
      data: {
        userId,
        sender: 'operator',
        text: text || null,
        attachmentKey: attachment?.attachmentKey ?? null,
        attachmentType: attachment?.attachmentType ?? null,
        fileName: attachment?.fileName ?? null,
        fileSize: attachment?.fileSize ?? null,
        mimeType: attachment?.mimeType ?? null,
      },
    });

    // WS — ilova ochiq bo'lsa DARHOL ko'rinadi (asosiy tezkor yo'l).
    this.realtime.emitToUser(userId, 'support:message', {
      id: saved.id,
      sender: 'operator',
      text: saved.text,
      attachmentType: saved.attachmentType,
      attachmentKey: saved.attachmentKey,
      fileName: saved.fileName,
      fileSize: saved.fileSize,
      mimeType: saved.mimeType,
      createdAt: saved.createdAt.toISOString(),
    });

    // FCM push — FONDA (poll loop'ni bloklamasin).
    void this.sendSupportPush(userId, text ?? '📎 Fayl');

    // Guruhda tasdiq.
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
  parameters?: { retry_after?: number; migrate_to_chat_id?: number };
}

interface TgChat {
  id: number;
  type: string;
  title?: string;
}

interface TgPhotoSize {
  file_id: string;
}

interface TgDocument {
  file_id: string;
  file_name?: string;
  mime_type?: string;
}

interface TgVideo {
  file_id: string;
  file_name?: string;
  mime_type?: string;
}

interface TgMessage {
  message_id: number;
  chat: TgChat;
  text?: string;
  caption?: string;
  reply_to_message?: { message_id: number };
  photo?: TgPhotoSize[];
  document?: TgDocument;
  video?: TgVideo;
  // Guruh supergroup'ga ko'tarilganda keladi (yangi chat ID).
  migrate_to_chat_id?: number;
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
