import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  Req,
  HttpCode,
  HttpStatus,
  UseGuards,
  StreamableFile,
  Header,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser, Public } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { InstalledAppsService } from './installed-apps.service';
import { BatchUpsertAppsDto } from './dto/batch-upsert-apps.dto';
import { ListInstalledAppsDto } from './dto/list-installed-apps.dto';
import { Request } from 'express';

@ApiTags('Installed Apps')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller()
export class InstalledAppsController {
  constructor(private readonly service: InstalledAppsService) {}

  @Post('children/:childId/installed-apps')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Batch upsert installed apps' })
  batchUpsert(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: BatchUpsertAppsDto,
    @Req() req: Request,
  ) {
    return this.service.batchUpsert(childId, user.userId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('children/:childId/installed-apps')
  @ApiOperation({ summary: 'List installed apps for a child' })
  list(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Query() query: ListInstalledAppsDto,
  ) {
    return this.service.list(
      childId,
      user.userId,
      query.includeSystem === 'true',
    );
  }

  // Ilova ikonasi proxy — telefon → backend → MinIO. @Public: ikona
  // childId + paket nomi orqali olinadi (past sezgirlikdagi rasm).
  @Get('children/:childId/installed-apps/:packageName/icon')
  @Public()
  @Header('Cache-Control', 'public, max-age=86400')
  @ApiOperation({ summary: 'Stream installed-app icon (proxy)' })
  async iconImage(
    @Param('childId') childId: string,
    @Param('packageName') packageName: string,
  ): Promise<StreamableFile> {
    const obj = await this.service.getIconObject(childId, packageName);
    return new StreamableFile(obj.body, { type: obj.contentType });
  }
}
