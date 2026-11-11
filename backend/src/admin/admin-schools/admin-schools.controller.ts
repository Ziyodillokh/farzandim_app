import { Body, Controller, Get, Header, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { CurrentStaff, Permissions } from '../../common/decorators';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { AdminJwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { AdminSchoolsService } from './admin-schools.service';

/** Vaqtinchalik parol qaytadigan javoblar keshlanmasin. */
const NO_STORE = ['Cache-Control', 'no-store'] as const;

/** Parvoz maktablari: yangi maktab + direktor, psixolog hisobi, parolni tiklash. */
@ApiTags('Admin - Schools')
@ApiBearerAuth('admin-jwt')
@Controller('admin/schools')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_schools')
export class AdminSchoolsController {
  constructor(private readonly service: AdminSchoolsService) {}

  @Get()
  @ApiOperation({ summary: "Maktablar (qidiruv: nom, kod, shahar) — sonlar va direktorlar bilan" })
  list(@Query() query: Record<string, unknown>) {
    return this.service.list(query);
  }

  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.get(id);
  }

  @Post()
  @Header(...NO_STORE)
  @ApiOperation({ summary: 'Yangi maktab va direktor: vaqtinchalik parol javobda bir marta qaytadi' })
  create(@Body() body: unknown, @CurrentStaff() staff: AdminJwtPayload, @Req() req: FastifyRequest) {
    return this.service.create(body, { id: staff.sub, email: staff.email }, req);
  }

  @Post(':id/staff')
  @Header(...NO_STORE)
  @ApiOperation({ summary: "Direktor yoki psixolog hisobi (qolgan xodimlarni direktor panelda qo'shadi)" })
  addStaff(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: unknown,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.service.addStaff(id, body, { id: staff.sub, email: staff.email }, req);
  }

  @Post(':id/staff/:staffId/reset-password')
  @HttpCode(HttpStatus.OK)
  @Header(...NO_STORE)
  @ApiOperation({ summary: "Direktor / psixolog parolini tiklash (sessiyalar yopiladi, ixtiyoriy 2FA o'chiriladi)" })
  resetPassword(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('staffId', ParseUUIDPipe) staffId: string,
    @Body() body: unknown,
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: FastifyRequest,
  ) {
    return this.service.resetPassword(id, staffId, body, { id: staff.sub, email: staff.email }, req);
  }
}
