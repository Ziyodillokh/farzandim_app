import {
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Anthropic from '@anthropic-ai/sdk';
import { PrismaService } from '../../common/database/prisma.service';
import { EnvConfig } from '../../common/config/env.schema';
import { buildSystemPrompt } from './system-prompt';
import { screenContent, SAFE_REDIRECT_REPLY } from './content-filter';

/** Claude modeli — suhbat uchun tezkor/arzon Haiku. */
const AI_MODEL = 'claude-haiku-4-5-20251001';
const MAX_TOKENS = 400;
/** Kontekst uchun so'nggi xabarlar soni. */
const CONTEXT_TURNS = 10;
/** Kunlik (24s) xabar chegarasi — abuse oldini olish. */
const DAILY_CAP = 40;
/** Qisqa oyna (60s) burst chegarasi. */
const BURST_WINDOW_MS = 60_000;
const BURST_CAP = 15;

/** API kalit yo'q yoki Claude xato bo'lsa — xavfsiz, do'stona fallback. */
const AI_OFFLINE_REPLY =
  'Salom! Men Faro 🦊. Hozircha javob bera olmayapman — birozdan keyin ' +
  "yana yozib ko'r!";

interface ClaudeMsg {
  role: 'user' | 'assistant';
  content: string;
}

@Injectable()
export class AiCompanionService {
  private readonly logger = new Logger(AiCompanionService.name);
  private client: Anthropic | null = null;
  private clientResolved = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService<EnvConfig, true>,
  ) {}

  /** API kalit bo'lsa Anthropic client (lazy). Yo'q bo'lsa null. */
  private getClient(): Anthropic | null {
    if (this.clientResolved) return this.client;
    this.clientResolved = true;
    const apiKey = this.config.get('ANTHROPIC_API_KEY', { infer: true });
    this.client = apiKey ? new Anthropic({ apiKey }) : null;
    if (!this.client) {
      this.logger.warn('ANTHROPIC_API_KEY yo\'q — AI hamroh offline rejimda');
    }
    return this.client;
  }

  private async resolveChild(userId: string) {
    const child = await this.prisma.child.findFirst({
      where: { childUserId: userId },
      select: { id: true, age: true },
    });
    if (!child) {
      throw new ForbiddenException('Only a paired child can use AI companion');
    }
    return child;
  }

  /* ------------------------------------------------------------------ */
  /*  POST /ai/chat — bola Faro bilan yozadi                            */
  /* ------------------------------------------------------------------ */
  async chat(userId: string, message: string) {
    const child = await this.resolveChild(userId);

    // Rate-limit + kunlik chegara (abuse).
    const now = Date.now();
    const [dayCount, burstCount] = await Promise.all([
      this.prisma.aiMessage.count({
        where: {
          childId: child.id,
          role: 'user',
          createdAt: { gte: new Date(now - 24 * 60 * 60 * 1000) },
        },
      }),
      this.prisma.aiMessage.count({
        where: {
          childId: child.id,
          role: 'user',
          createdAt: { gte: new Date(now - BURST_WINDOW_MS) },
        },
      }),
    ]);
    if (dayCount >= DAILY_CAP) {
      throw new HttpException(
        'Bugungi suhbat chegarasiga yetding. Ertaga yana gaplashamiz! 😊',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    if (burstCount >= BURST_CAP) {
      throw new HttpException(
        'Birozdan keyin yana yozib ko\'r 😊',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // #69 — KIRUVCHI matn filtri. Xavfli bo'lsa Claude chaqirilmaydi.
    const inputScreen = screenContent(message);
    if (inputScreen.flagged) {
      await this.prisma.aiMessage.create({
        data: { childId: child.id, role: 'user', text: message, flagged: true },
      });
      const safe = await this.prisma.aiMessage.create({
        data: {
          childId: child.id,
          role: 'assistant',
          text: SAFE_REDIRECT_REPLY,
          flagged: true,
        },
      });
      return this.serialize(safe);
    }

    // Bola xabarini saqlaymiz (kontekstga kiradi).
    await this.prisma.aiMessage.create({
      data: { childId: child.id, role: 'user', text: message, flagged: false },
    });

    // Kontekst — so'nggi xabarlar (user bilan tugaydi).
    const context = await this.buildContext(child.id);
    const system = buildSystemPrompt(child.age);

    let reply: string;
    let online = true;
    try {
      reply = await this.callClaude(system, context);
    } catch (err) {
      this.logger.warn({ err }, 'Claude chaqiruvi muvaffaqiyatsiz');
      reply = AI_OFFLINE_REPLY;
      online = false;
    }

    // #69 — CHIQUVCHI matn filtri (model nojo'ya javob bermasin).
    let flagged = false;
    if (online) {
      const out = screenContent(reply);
      if (out.flagged) {
        reply = SAFE_REDIRECT_REPLY;
        flagged = true;
      }
    }

    const saved = await this.prisma.aiMessage.create({
      data: { childId: child.id, role: 'assistant', text: reply, flagged },
    });
    return this.serialize(saved);
  }

  private async buildContext(childId: string): Promise<ClaudeMsg[]> {
    const rows = await this.prisma.aiMessage.findMany({
      where: { childId },
      orderBy: { createdAt: 'desc' },
      take: CONTEXT_TURNS,
    });
    const chrono = rows.reverse();
    const msgs: ClaudeMsg[] = chrono.map((m) => ({
      role: m.role === 'assistant' ? 'assistant' : 'user',
      content: m.text,
    }));
    // Anthropic: birinchi xabar 'user' bo'lishi shart — boshidagi
    // assistant xabarlarni olib tashlaymiz.
    while (msgs.length > 0 && msgs[0].role !== 'user') msgs.shift();
    return msgs;
  }

  private async callClaude(
    system: string,
    messages: ClaudeMsg[],
  ): Promise<string> {
    const client = this.getClient();
    if (!client) throw new Error('AI offline (no API key)');
    const resp = await client.messages.create({
      model: AI_MODEL,
      max_tokens: MAX_TOKENS,
      system,
      messages,
    });
    const block = resp.content.find((b) => b.type === 'text');
    const text = block && block.type === 'text' ? block.text.trim() : '';
    return text || AI_OFFLINE_REPLY;
  }

  /* ------------------------------------------------------------------ */
  /*  GET /ai/history — bola o'z suhbati                                */
  /* ------------------------------------------------------------------ */
  async getHistory(userId: string, limit = 100) {
    const child = await this.resolveChild(userId);
    const rows = await this.prisma.aiMessage.findMany({
      where: { childId: child.id },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });
    return { messages: rows.map((r) => this.serialize(r)) };
  }

  /* ------------------------------------------------------------------ */
  /*  GET /children/:id/ai-history — ota-ona ko'radi (#70)             */
  /* ------------------------------------------------------------------ */
  async getHistoryForParent(parentUserId: string, childId: string, limit = 200) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
      select: { parentId: true },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== parentUserId) {
      throw new ForbiddenException('Only the parent can view AI history');
    }
    const rows = await this.prisma.aiMessage.findMany({
      where: { childId },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });
    const messages = rows.map((r) => this.serialize(r));
    const flaggedCount = messages.filter((m) => m.flagged).length;
    return { messages, flaggedCount };
  }

  private serialize(m: {
    id: string;
    role: string;
    text: string;
    flagged: boolean;
    createdAt: Date;
  }) {
    return {
      id: m.id,
      role: m.role,
      text: m.text,
      flagged: m.flagged,
      createdAt: m.createdAt.toISOString(),
    };
  }
}
