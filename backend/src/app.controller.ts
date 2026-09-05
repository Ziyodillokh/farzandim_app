import { Controller, Get, Res } from '@nestjs/common';
import { ApiExcludeEndpoint } from '@nestjs/swagger';
import { readFile } from 'fs/promises';
import { join } from 'path';
import type { FastifyReply } from 'fastify';
import { PrismaService } from './common/database/prisma.service';
import { Public } from './common/decorators/public.decorator';

/**
 * Statik fayllar `src/static/` da yotadi va `nest-cli.json` dagi `assets`
 * orqali `dist/static/` ga ko'chiriladi — shuning uchun `__dirname` ikkala
 * muhitda ham (ts-node va build qilingan dist) to'g'ri ishlaydi.
 */
const STATIC_DIR = join(__dirname, 'static');

@Controller()
export class AppController {
  /** Bir marta o'qib keshlanadi — har so'rovda diskka tegmaslik uchun. */
  private conceptHtml?: string;
  private conceptOg?: Buffer;

  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @Get()
  root() {
    return { message: 'Farzandim API ishlaydi!' };
  }

  @Public()
  @Get('health')
  async health() {
    let dbStatus = 'ok';
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      dbStatus = 'error';
    }

    return {
      status: dbStatus === 'ok' ? 'ok' : 'degraded',
      service: 'Farzandim Backend',
      version: '2.0.0',
      timestamp: new Date().toISOString(),
      database: dbStatus,
    };
  }

  /**
   * Investorlarga ulashiladigan konseptsiya sahifasi.
   *
   * Nega backend'da: landing sayti (`/var/www/farzandim-landing`) manbasi
   * repoda EMAS va uning avtomatik deploy'i ataylab o'chirilgan (2026-09-05,
   * `deploy-landing.yml` izohiga qarang) — u yerga fayl qo'shish jonli
   * saytni eski versiya bilan bosib ketish xavfini tug'diradi. Backend esa
   * har push'da xavfsiz deploy bo'ladi.
   *
   * Sahifa `noindex` — havola orqali ochiladi, qidiruvda chiqmaydi.
   */
  @Public()
  @Get('konsepsiya')
  @ApiExcludeEndpoint()
  async concept(@Res() res: FastifyReply) {
    this.conceptHtml ??= await readFile(
      join(STATIC_DIR, 'konsepsiya.html'),
      'utf8',
    );
    await res
      .header('Content-Type', 'text/html; charset=utf-8')
      .header('Cache-Control', 'public, max-age=300')
      .header('X-Robots-Tag', 'noindex, nofollow')
      .send(this.conceptHtml);
  }

  /** Telegram/WhatsApp havola ko'rinishi uchun og:image. */
  @Public()
  @Get('konsepsiya-og.png')
  @ApiExcludeEndpoint()
  async conceptOgImage(@Res() res: FastifyReply) {
    this.conceptOg ??= await readFile(join(STATIC_DIR, 'konsepsiya-og.png'));
    await res
      .header('Content-Type', 'image/png')
      .header('Cache-Control', 'public, max-age=86400')
      .header('Cross-Origin-Resource-Policy', 'cross-origin')
      .send(this.conceptOg);
  }
}
