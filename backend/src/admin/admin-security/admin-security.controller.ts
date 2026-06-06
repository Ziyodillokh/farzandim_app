import {
  Body,
  Controller,
  Get,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { Permissions } from '../../common/decorators';
import { SecuritySettingsService } from '../../common/security/security-settings.service';
import { getClientIp } from '../../common/helpers/client-ip';
import { UpdateSecuritySettingsDto } from './dto/update-security-settings.dto';

@ApiTags('Admin - Security')
@ApiBearerAuth('admin-jwt')
@Controller('admin/security-settings')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_security')
export class AdminSecurityController {
  constructor(private readonly security: SecuritySettingsService) {}

  @Get()
  @ApiOperation({ summary: 'Get admin security settings + caller current IP' })
  async get(@Req() req: FastifyRequest) {
    const s = await this.security.getSettings();
    return { ...s, currentIp: getClientIp(req) };
  }

  @Patch()
  @ApiOperation({ summary: 'Update admin security settings (IP allowlist)' })
  async update(
    @Req() req: FastifyRequest,
    @Body() dto: UpdateSecuritySettingsDto,
  ) {
    const ip = getClientIp(req);
    const updated = await this.security.update(dto, ip);
    return { ...updated, currentIp: ip };
  }
}
