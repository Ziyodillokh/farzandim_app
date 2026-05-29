import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { AdminModeratorsService } from './admin-moderators.service';
import { CreateModeratorDto } from './dto/create-moderator.dto';
import { UpdateModeratorDto } from './dto/update-moderator.dto';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { CurrentStaff, Permissions } from '../../common/decorators';
import { AdminJwtPayload } from '../../common/interfaces/jwt-payload.interface';

@ApiTags('Admin - Moderators')
@ApiBearerAuth('admin-jwt')
@Controller('admin/moderators')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_moderators')
export class AdminModeratorsController {
  constructor(private readonly service: AdminModeratorsService) {}

  @Get()
  @ApiOperation({ summary: 'List moderators (paginated, searchable)' })
  @ApiQuery({ name: 'q', required: false })
  @ApiQuery({ name: 'role', required: false })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  async list(
    @Query('q') q?: string,
    @Query('role') role?: string,
    @Query('status') status?: string,
    @Query('page') page = 1,
    @Query('limit') limit = 20,
  ) {
    return this.service.list({
      q,
      role,
      status,
      page: Math.max(1, +page || 1),
      limit: Math.min(100, Math.max(1, +limit || 20)),
    });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get moderator by ID' })
  async findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new moderator' })
  async create(
    @Body() dto: CreateModeratorDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    return this.service.create(dto, staff.sub, staff.email, {
      ip: req.ip,
      headers: req.headers,
    });
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a moderator' })
  async update(
    @Param('id') id: string,
    @Body() dto: UpdateModeratorDto,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    return this.service.update(id, dto, staff.sub, staff.email, {
      ip: req.ip,
      headers: req.headers,
    });
  }

  @Post(':id/block')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Block a moderator' })
  async block(
    @Param('id') id: string,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    return this.service.block(id, staff.sub, staff.email, {
      ip: req.ip,
      headers: req.headers,
    });
  }

  @Post(':id/unblock')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unblock a moderator' })
  async unblock(
    @Param('id') id: string,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    return this.service.unblock(id, staff.sub, staff.email, {
      ip: req.ip,
      headers: req.headers,
    });
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a moderator' })
  async remove(
    @Param('id') id: string,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    await this.service.remove(id, staff.sub, staff.email, {
      ip: req.ip,
      headers: req.headers,
    });
  }

  @Post(':id/reset-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reset moderator password' })
  async resetPassword(
    @Param('id') id: string,
    @Body('password') password: string,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: any,
  ) {
    return this.service.resetPassword(id, password, staff.sub, staff.email, {
      ip: req.ip,
      headers: req.headers,
    });
  }
}
