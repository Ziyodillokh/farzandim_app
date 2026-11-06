import { Body, Controller, Get, Header, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { CredentialView, IssuedCredential } from '../../modules/child-auth/child-credentials.service';
import { RecoveryRequestView } from '../../modules/child-auth/child-recovery.service';
import { IssueChildCredentialDto } from '../../modules/child-auth/dto/issue-child-credential.dto';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { StudentCredentialsService } from './student-credentials.service';

@ApiTags('School - Student credentials')
@SchoolAuth()
@Controller('school/students/:studentId')
export class StudentCredentialsController {
  constructor(private readonly service: StudentCredentialsService) {}

  @Get('credentials')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'O\'quvchining bola ilovasi kirish maʼlumotlari (parolsiz) yoki null' })
  @ApiResponse({ status: 409, description: 'NOT_LINKED — o\'quvchi Parvoz bola profiliga bog\'lanmagan' })
  view(@Actor() actor: SchoolActor, @Param('studentId') studentId: string): Promise<CredentialView | null> {
    return this.service.view(actor, studentId);
  }

  @Post('credentials')
  @HttpCode(HttpStatus.CREATED)
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Kirish maʼlumotlarini berish / qayta tiklash (vaqtinchalik parol BIR MARTA qaytadi)' })
  @ApiResponse({ status: 201, description: '{ login, temporaryPassword, issuedAt }' })
  @ApiResponse({ status: 409, description: 'NOT_LINKED | LOGIN_TAKEN | STUDENT_ARCHIVED' })
  issue(
    @Actor() actor: SchoolActor,
    @Param('studentId') studentId: string,
    @Body() dto: IssueChildCredentialDto,
  ): Promise<IssuedCredential> {
    return this.service.issue(actor, studentId, dto);
  }

  @Post('recovery-requests/:requestId/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Maktab kanaliga tushgan tiklash so\'rovini rad etadi' })
  rejectRecovery(
    @Actor() actor: SchoolActor,
    @Param('studentId') studentId: string,
    @Param('requestId') requestId: string,
  ): Promise<RecoveryRequestView> {
    return this.service.rejectRecovery(actor, studentId, requestId);
  }
}
