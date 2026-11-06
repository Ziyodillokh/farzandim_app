import { Body, Controller, Get, Header, HttpCode, HttpStatus, Param, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { StructuredUserThrottlerGuard } from '../../common/throttle/structured-throttler.guard';
import { CHILD_CREDENTIAL_ISSUE_LIMIT, THROTTLER_NAMES } from '../../common/throttle/throttle.config';
import {
  ChildCredentialsService,
  CredentialView,
  IssuedCredential,
} from './child-credentials.service';
import { ChildRecoveryService, RecoveryRequestView } from './child-recovery.service';
import { IssueChildCredentialDto } from './dto/issue-child-credential.dto';

/** Ota-ona: bolaning kirish maʼlumotlari va tiklash so'rovlari. */
@ApiTags('Child credentials')
@ApiBearerAuth('consumer-jwt')
@Controller('children/:childId')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('PARENT')
export class ChildCredentialsController {
  constructor(
    private readonly credentials: ChildCredentialsService,
    private readonly recovery: ChildRecoveryService,
  ) {}

  @Get('credentials')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Bolaning kirish maʼlumotlari (parolsiz) yoki null' })
  view(@CurrentUser() user: JwtPayload, @Param('childId') childId: string): Promise<CredentialView | null> {
    return this.credentials.viewForParent(user.userId, childId);
  }

  @Post('credentials')
  @UseGuards(StructuredUserThrottlerGuard)
  @Throttle({ [THROTTLER_NAMES.childCredentialIssue]: CHILD_CREDENTIAL_ISSUE_LIMIT })
  @HttpCode(HttpStatus.CREATED)
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Kirish maʼlumotlarini berish / qayta tiklash (vaqtinchalik parol BIR MARTA qaytadi)' })
  @ApiResponse({ status: 201, description: '{ login, temporaryPassword, issuedAt }' })
  @ApiResponse({ status: 409, description: 'LOGIN_TAKEN' })
  issue(
    @CurrentUser() user: JwtPayload,
    @Param('childId') childId: string,
    @Body() dto: IssueChildCredentialDto,
    @Req() req: Request,
  ): Promise<IssuedCredential> {
    return this.credentials.issueForParent(user.userId, childId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('recovery-requests')
  @ApiOperation({ summary: 'Bolaning ochiq tiklash so\'rovlari (ota-onaga yuborilganlar)' })
  listRecovery(@CurrentUser() user: JwtPayload, @Param('childId') childId: string): Promise<RecoveryRequestView[]> {
    return this.recovery.listForParent(user.userId, childId);
  }

  @Post('recovery-requests/:requestId/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Tiklash so\'rovini rad etadi' })
  @ApiResponse({ status: 404, description: 'REQUEST_NOT_FOUND' })
  @ApiResponse({ status: 409, description: 'ALREADY_RESOLVED' })
  rejectRecovery(
    @CurrentUser() user: JwtPayload,
    @Param('childId') childId: string,
    @Param('requestId') requestId: string,
    @Req() req: Request,
  ): Promise<RecoveryRequestView> {
    return this.recovery.rejectForParent(user.userId, childId, requestId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }
}
