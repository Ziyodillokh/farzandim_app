import { Body, Controller, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { CareChildService } from './care-child.service';

/** Parvoz Growth bola ilovasi: maktab so'rovnomasi va psixologga murojaat. */
@ApiTags('School (child app)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('child/school/care')
export class CareChildController {
  constructor(private readonly care: CareChildService) {}

  @Get('survey')
  @ApiOperation({ summary: 'Faol so\'rovnoma (yosh guruhi bo\'yicha) yoki null' })
  survey(@CurrentUser() user: JwtPayload) {
    return this.care.activeSurvey(user.userId);
  }

  @Post('survey/:surveyId/responses')
  @HttpCode(HttpStatus.CREATED)
  submit(@CurrentUser() user: JwtPayload, @Param('surveyId', ParseUUIDPipe) surveyId: string, @Body() body: unknown) {
    return this.care.submitSurvey(user.userId, surveyId, body);
  }

  @Get('requests')
  myRequests(@CurrentUser() user: JwtPayload) {
    return this.care.myRequests(user.userId);
  }

  @Post('requests')
  @ApiOperation({ summary: 'Psixologga murojaat (matn shifrlanadi)' })
  createRequest(@CurrentUser() user: JwtPayload, @Body() body: unknown) {
    return this.care.createRequest(user.userId, body);
  }
}
