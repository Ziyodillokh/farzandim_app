import { Body, Controller, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { AssessmentsChildService } from './assessments-child.service';

/** Parvoz Growth bola ilovasi: maktab psixologi tayinlagan testlar. */
@ApiTags('School (child app)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('child/school/assessments')
export class AssessmentsChildController {
  constructor(private readonly assessments: AssessmentsChildService) {}

  @Get()
  @ApiOperation({ summary: 'Bolaning sinfiga ochiq, hali yechilmagan testlar' })
  list(@CurrentUser() user: JwtPayload) {
    return this.assessments.openAssignments(user.userId);
  }

  @Get(':assignmentId')
  @ApiOperation({ summary: 'Test savollari (to\'g\'ri javoblarsiz, bola tilida)' })
  get(@CurrentUser() user: JwtPayload, @Param('assignmentId', ParseUUIDPipe) assignmentId: string) {
    return this.assessments.assignment(user.userId, assignmentId);
  }

  @Post(':assignmentId/submit')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Javoblar (bir marta): server baholaydi, bolaga ball qaytmaydi' })
  submit(@CurrentUser() user: JwtPayload, @Param('assignmentId', ParseUUIDPipe) assignmentId: string, @Body() body: unknown) {
    return this.assessments.submit(user.userId, assignmentId, body);
  }
}
