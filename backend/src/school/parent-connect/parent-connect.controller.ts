import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { ParentOverviewService } from './parent-overview.service';
import { ParentThreadsService } from './parent-threads.service';

/** Parvoz Parents: maktab kontaktlari, xodim bilan yozishma, farzandning maktab statistikasi. */
@ApiTags('School connect (parent)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('PARENT')
@Controller('parent/school')
export class ParentConnectController {
  constructor(
    private readonly threads: ParentThreadsService,
    private readonly overviewService: ParentOverviewService,
  ) {}

  @Get('contacts')
  @ApiOperation({ summary: "O'quvchi bo'yicha maktab kontaktlari (sinf rahbari, rahbariyat, psixolog, o'qituvchilar)" })
  contacts(@CurrentUser() user: JwtPayload, @Query() query: Record<string, unknown>) {
    return this.threads.contacts(user.userId, query);
  }

  @Get('threads')
  @ApiOperation({ summary: 'Murojaatlarim (yangisi oldin) va jami o\'qilmaganlar' })
  list(@CurrentUser() user: JwtPayload) {
    return this.threads.list(user.userId);
  }

  @Post('threads')
  @ApiOperation({ summary: 'Xodimga xabar (yozishma bo\'lmasa ochiladi)' })
  start(@CurrentUser() user: JwtPayload, @Body() body: unknown) {
    return this.threads.start(user.userId, body);
  }

  @Get('threads/:id')
  @ApiOperation({ summary: 'Yozishma va xabarlar' })
  get(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.threads.get(user.userId, id);
  }

  @Post('threads/:id/messages')
  @ApiOperation({ summary: 'Yozishmaga xabar' })
  send(@CurrentUser() user: JwtPayload, @Param('id') id: string, @Body() body: unknown) {
    return this.threads.send(user.userId, id, body);
  }

  @Post('threads/:id/read')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Yozishma o'qildi" })
  read(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.threads.markRead(user.userId, id);
  }

  @Get('students/:studentId/overview')
  @ApiOperation({ summary: "Farzandim maktabda: davomat, kelish vaqti, sinf o'rtachasi, topshiriqlar" })
  overview(@CurrentUser() user: JwtPayload, @Param('studentId') studentId: string) {
    return this.overviewService.overview(user.userId, studentId);
  }
}
