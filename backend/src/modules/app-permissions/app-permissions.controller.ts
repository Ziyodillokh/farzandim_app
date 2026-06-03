import {
  Controller,
  Get,
  Put,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { AppPermissionsService } from './app-permissions.service';
import { UpsertAppPermissionDto } from './dto/upsert-app-permission.dto';

@ApiTags('App Permissions')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller()
export class AppPermissionsController {
  constructor(private readonly service: AppPermissionsService) {}

  @Get('children/:childId/app-permissions')
  @ApiOperation({
    summary: 'List per-app permission policies (optional ?permission=camera)',
  })
  list(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Query('permission') permission?: string,
  ) {
    return this.service.listByPermission(childId, user.userId, permission ?? '');
  }

  @Put('children/:childId/app-permissions')
  @ApiOperation({ summary: 'Upsert a per-app permission policy (parent only)' })
  upsert(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpsertAppPermissionDto,
  ) {
    return this.service.upsert(childId, user.userId, dto);
  }
}
