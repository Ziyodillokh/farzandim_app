import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
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
import { SosAlertsService } from './sos-alerts.service';
import { CreateSosAlertDto } from './dto/create-sos-alert.dto';
import { ListSosAlertsDto } from './dto/list-sos-alerts.dto';
import { Request } from 'express';

@ApiTags('SOS Alerts')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller()
export class SosAlertsController {
  constructor(private readonly service: SosAlertsService) {}

  @Post('children/:childId/sos-alerts')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Trigger SOS alert (child sends)' })
  create(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateSosAlertDto,
    @Req() req: Request,
  ) {
    return this.service.create(childId, user.userId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('sos-alerts')
  @ApiOperation({ summary: 'List SOS alerts (parent sees own children)' })
  list(
    @CurrentUser() user: JwtPayload,
    @Query() query: ListSosAlertsDto,
  ) {
    return this.service.list(user.userId, query);
  }

  @Put('sos-alerts/:id/resolve')
  @ApiOperation({ summary: 'Resolve SOS alert (parent only)' })
  resolve(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.service.resolve(id, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }
}
