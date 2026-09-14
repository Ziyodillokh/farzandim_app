import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { AdminUsersService } from './admin-users.service';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { CurrentStaff, Permissions } from '../../common/decorators';
import { AdminJwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { GrantSubscriptionDto } from './dto/grant-subscription.dto';
import { WarnUserDto } from './dto/warn-user.dto';

@ApiTags('Admin - Users')
@ApiBearerAuth('admin-jwt')
@Controller('admin/users')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('view_users', 'manage_users', 'block_users', 'warn_users', 'edit_user_data')
export class AdminUsersController {
  constructor(private readonly service: AdminUsersService) {}

  @Get()
  @ApiOperation({ summary: 'List users (parents + children, paginated)' })
  @ApiQuery({ name: 'q', required: false })
  @ApiQuery({ name: 'role', required: false })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'plan', required: false })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  async list(
    @Query('q') q?: string,
    @Query('role') role?: string,
    @Query('status') status?: string,
    @Query('plan') plan?: string,
    @Query('page') page = 1,
    @Query('limit') limit = 20,
  ) {
    return this.service.list({
      q,
      role,
      status,
      plan,
      page: Math.max(1, +page || 1),
      limit: Math.min(100, Math.max(1, +limit || 20)),
    });
  }

  @Get('child-profiles/:id')
  @ApiOperation({ summary: 'Get child profile detail' })
  async findChildProfile(@Param('id') id: string) {
    return this.service.findChildProfile(id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get user detail with children' })
  async findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }

  @Post(':id/block')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Block a parent user' })
  async block(@Param('id') id: string) {
    return this.service.blockUser(id);
  }

  @Post(':id/unblock')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unblock a parent user' })
  async unblock(@Param('id') id: string) {
    return this.service.unblockUser(id);
  }

  // Ogohlantirish — push (ota-ona) yoki push + in-app inbox (bola).
  @Post(':id/warn')
  @HttpCode(HttpStatus.OK)
  @Permissions('warn_users', 'manage_users')
  @ApiOperation({ summary: 'Send a warning push to a user (parent or child)' })
  async warn(
    @Param('id') id: string,
    @Body() dto: WarnUserDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    return this.service.warnUser(id, dto.message, staff, {
      ip: req.ip,
      headers: req.headers,
    });
  }

  // Sovg'a — tanlangan tarifni N kun bepul (demo). Faqat ota-ona.
  @Post(':id/grant-subscription')
  @HttpCode(HttpStatus.OK)
  @Permissions('manage_users', 'edit_user_data')
  @ApiOperation({
    summary: 'Gift a plan to a parent for N days (free trial/demo)',
  })
  async grantSubscription(
    @Param('id') id: string,
    @Body() dto: GrantSubscriptionDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    return this.service.grantSubscription(id, dto, staff, {
      ip: req.ip,
      headers: req.headers,
    });
  }

  // Halokatli amal — faqat `manage_users` ruxsatiga ega admin (method-level
  // @Permissions class-level'ni override qiladi).
  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @Permissions('manage_users')
  @ApiOperation({
    summary: 'Delete a user and ALL their data from the server (cascade)',
  })
  async remove(@Param('id') id: string) {
    return this.service.deleteUser(id);
  }
}
