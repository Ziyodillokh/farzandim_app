import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { AdminUsersService } from './admin-users.service';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { Permissions } from '../../common/decorators';

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
}
