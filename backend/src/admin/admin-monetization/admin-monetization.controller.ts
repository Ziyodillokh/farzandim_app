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
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { AdminMonetizationService } from './admin-monetization.service';
import { CreatePlanDto } from './dto/create-plan.dto';
import { UpdatePlanDto } from './dto/update-plan.dto';
import { CreatePromocodeDto } from './dto/create-promocode.dto';
import { UpdatePromocodeDto } from './dto/update-promocode.dto';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { Permissions } from '../../common/decorators';

@ApiTags('Admin - Monetization')
@ApiBearerAuth('admin-jwt')
@Controller('admin/monetization')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_monetization')
export class AdminMonetizationController {
  constructor(private readonly service: AdminMonetizationService) {}

  // ─── Plans ─────────────────────────────────────────────────────

  @Get('plans')
  @ApiOperation({ summary: 'List all plans' })
  async listPlans() {
    return this.service.listPlans();
  }

  @Post('plans')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new plan' })
  async createPlan(@Body() dto: CreatePlanDto) {
    return this.service.createPlan(dto);
  }

  @Patch('plans/:id')
  @ApiOperation({ summary: 'Update a plan' })
  async updatePlan(@Param('id') id: string, @Body() dto: UpdatePlanDto) {
    return this.service.updatePlan(id, dto);
  }

  @Delete('plans/:id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete plan (soft if FK references exist)' })
  async deletePlan(@Param('id') id: string) {
    return this.service.deletePlan(id);
  }

  // ─── Promocodes ────────────────────────────────────────────────

  @Get('promocodes')
  @ApiOperation({ summary: 'List promocodes' })
  @ApiQuery({ name: 'q', required: false })
  @ApiQuery({ name: 'planId', required: false })
  @ApiQuery({ name: 'status', required: false })
  async listPromocodes(
    @Query('q') q?: string,
    @Query('planId') planId?: string,
    @Query('status') status?: string,
  ) {
    return this.service.listPromocodes({ q, planId, status });
  }

  @Post('promocodes')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new promocode' })
  async createPromocode(@Body() dto: CreatePromocodeDto) {
    return this.service.createPromocode(dto);
  }

  @Patch('promocodes/:id')
  @ApiOperation({ summary: 'Update a promocode' })
  async updatePromocode(
    @Param('id') id: string,
    @Body() dto: UpdatePromocodeDto,
  ) {
    return this.service.updatePromocode(id, dto);
  }

  @Delete('promocodes/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a promocode' })
  async deletePromocode(@Param('id') id: string) {
    await this.service.deletePromocode(id);
  }

  // ─── Payments ──────────────────────────────────────────────────

  @Get('payments')
  @ApiOperation({ summary: 'List payments (paginated, filterable)' })
  @ApiQuery({ name: 'q', required: false })
  @ApiQuery({ name: 'planId', required: false })
  @ApiQuery({ name: 'method', required: false })
  @ApiQuery({ name: 'status', required: false })
  async listPayments(
    @Query('q') q?: string,
    @Query('planId') planId?: string,
    @Query('method') method?: string,
    @Query('status') status?: string,
  ) {
    return this.service.listPayments({ q, planId, method, status });
  }

  // ─── Subscriptions ─────────────────────────────────────────────

  @Get('subscriptions')
  @ApiOperation({ summary: 'List subscriptions (paginated, filterable)' })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  async listSubscriptions(
    @Query('status') status?: string,
    @Query('page') page = 1,
    @Query('limit') limit = 20,
  ) {
    return this.service.listSubscriptions({
      status,
      page: +page || 1,
      limit: +limit || 20,
    });
  }
}
