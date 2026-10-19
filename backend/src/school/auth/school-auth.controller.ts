import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { FastifyReply, FastifyRequest } from 'fastify';
import { EnvConfig } from '../../common/config/env.schema';
import { SCHOOL_LOGIN_LIMIT } from '../../common/throttle/throttle.config';
import { Actor, SchoolAuth } from './decorators';
import { SchoolActor } from './school-actor';
import { IssuedSession, SchoolAuthService } from './school-auth.service';
import { SCHOOL_REFRESH_TTL_MS } from './school-tokens.service';

export const SCHOOL_REFRESH_COOKIE = 'parvoz_school_rt';
const COOKIE_PATH = '/api/school/auth';

type Req = FastifyRequest & { cookies?: Record<string, string | undefined> };

@ApiTags('School - Auth')
@Controller('school/auth')
export class SchoolAuthController {
  constructor(
    private readonly auth: SchoolAuthService,
    private readonly config: ConfigService<EnvConfig, true>,
  ) {}

  @Post('login')
  @UseGuards(ThrottlerGuard)
  @Throttle({ schoolLogin: SCHOOL_LOGIN_LIMIT })
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Kirish: maktab kodi + login + parol (+ TOTP)' })
  async login(
    @Body() body: unknown,
    @Req() req: Req,
    @Res({ passthrough: true }) reply: FastifyReply,
  ) {
    return this.respond(reply, await this.auth.login(body, meta(req)));
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Access tokenni yangilash (httpOnly cookie, rotatsiya)' })
  async refresh(@Req() req: Req, @Res({ passthrough: true }) reply: FastifyReply) {
    try {
      return this.respond(reply, await this.auth.refresh(req.cookies?.[SCHOOL_REFRESH_COOKIE], meta(req)));
    } catch (e) {
      this.clearCookie(reply);
      throw e;
    }
  }

  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Chiqish — sessiya yopiladi' })
  async logout(@Req() req: Req, @Res({ passthrough: true }) reply: FastifyReply) {
    await this.auth.logout(req.cookies?.[SCHOOL_REFRESH_COOKIE]);
    this.clearCookie(reply);
  }

  @Get('me')
  @SchoolAuth()
  @ApiOperation({ summary: 'Joriy xodim, maktab, rol ruxsatlari va sinf doirasi' })
  me(@Actor() actor: SchoolActor) {
    return this.auth.me(actor);
  }

  @Post('password')
  @SchoolAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Parolni almashtirish (boshqa sessiyalar yopiladi)' })
  async changePassword(@Actor() actor: SchoolActor, @Body() body: unknown) {
    await this.auth.changePassword(actor, body);
  }

  @Post('2fa/setup')
  @SchoolAuth()
  @HttpCode(HttpStatus.OK)
  setupTotp(@Actor() actor: SchoolActor) {
    return this.auth.setupTotp(actor);
  }

  @Post('2fa/enable')
  @SchoolAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  async enableTotp(@Actor() actor: SchoolActor, @Body() body: { code?: unknown } | undefined) {
    await this.auth.enableTotp(actor, body?.code);
  }

  @Post('2fa/disable')
  @SchoolAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  async disableTotp(@Actor() actor: SchoolActor, @Body() body: { password?: unknown } | undefined) {
    await this.auth.disableTotp(actor, body?.password);
  }

  private respond(reply: FastifyReply, issued: IssuedSession) {
    reply.setCookie(SCHOOL_REFRESH_COOKIE, issued.refreshToken, {
      httpOnly: true,
      secure: this.secureCookies(),
      sameSite: 'strict',
      path: COOKIE_PATH,
      maxAge: Math.floor(SCHOOL_REFRESH_TTL_MS / 1000),
    });
    return { accessToken: issued.accessToken, expiresIn: issued.expiresIn, me: issued.me };
  }

  private clearCookie(reply: FastifyReply) {
    reply.clearCookie(SCHOOL_REFRESH_COOKIE, { path: COOKIE_PATH });
  }

  private secureCookies(): boolean {
    return this.config.get('NODE_ENV', { infer: true }) === 'production';
  }
}

function meta(req: Req) {
  const ua = req.headers['user-agent'];
  return { ip: req.ip, userAgent: typeof ua === 'string' ? ua : undefined };
}
