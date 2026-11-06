import { Body, Controller, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { CareChildRequestsService } from './care-child-requests.service';
import { CareChildService } from './care-child.service';

/** Parvoz Growth bola ilovasi: anonim so'rovnoma va psixologga murojaat (yozishma). */
@ApiTags('School (child app)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('child/school/care')
export class CareChildController {
  constructor(
    private readonly care: CareChildService,
    private readonly requests: CareChildRequestsService,
  ) {}

  @Get('survey')
  @ApiOperation({ summary: 'Faol so\'rovnoma (yosh guruhi bo\'yicha) yoki null' })
  survey(@CurrentUser() user: JwtPayload) {
    return this.care.activeSurvey(user.userId);
  }

  @Post('survey/:surveyId/responses')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Anonim javob (bir marta): ishtirok va javob alohida saqlanadi' })
  submit(@CurrentUser() user: JwtPayload, @Param('surveyId', ParseUUIDPipe) surveyId: string, @Body() body: unknown) {
    return this.care.submitSurvey(user.userId, surveyId, body);
  }

  @Get('contact')
  @ApiOperation({ summary: 'Kim javob beradi, ish vaqti va hozir ochiqmi' })
  contact(@CurrentUser() user: JwtPayload) {
    return this.requests.contact(user.userId);
  }

  @Get('requests')
  @ApiOperation({ summary: 'Bolaning murojaatlari (matnsiz): holat, bosqich, o\'qilmaganlar' })
  myRequests(@CurrentUser() user: JwtPayload) {
    return this.requests.list(user.userId);
  }

  @Post('requests')
  @ApiOperation({ summary: 'Psixologga murojaat (matn shifrlanadi; clientRequestId — idempotent)' })
  createRequest(@CurrentUser() user: JwtPayload, @Body() body: unknown) {
    return this.requests.create(user.userId, body);
  }

  @Get('requests/:id')
  @ApiOperation({ summary: 'Murojaat tafsiloti va yozishma (xodim xabarlari o\'qildi deb belgilanadi)' })
  request(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) {
    return this.requests.detail(user.userId, id);
  }

  @Post('requests/:id/messages')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Yozishmaga xabar (clientMessageId — idempotent, kuniga 30 ta)' })
  message(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string, @Body() body: unknown) {
    return this.requests.addMessage(user.userId, id, body);
  }
}
