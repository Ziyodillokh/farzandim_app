import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  Req,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { ListenSessionsService } from './listen-sessions.service';
import { Request } from 'express';

/**
 * Jonli eshitish sessiyalari. Ovoz WebRTC orqali (P2P) o'tadi — bu REST
 * faqat sessiyani boshlash/to'xtatish va audit uchun. Signaling (SDP/ICE)
 * RealtimeGateway'da (`listen:signal`).
 */
@ApiTags('Listen Sessions')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller()
export class ListenSessionsController {
  constructor(private readonly service: ListenSessionsService) {}

  @Post('children/:childId/listen-sessions')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Parent starts a live listen session' })
  start(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.service.start(childId, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Post('listen-sessions/:id/end')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Parent or child ends the session' })
  end(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.service.end(id, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('children/:childId/listen-sessions')
  @ApiOperation({ summary: 'Audit list of listen sessions (metadata only)' })
  list(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Query('limit') limit?: string,
  ) {
    const parsed = limit ? Number.parseInt(limit, 10) : undefined;
    return this.service.list(
      childId,
      user.userId,
      Number.isFinite(parsed) ? parsed : undefined,
    );
  }
}
