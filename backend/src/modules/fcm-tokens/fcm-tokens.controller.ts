import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiParam,
} from '@nestjs/swagger';
import { FcmTokensService } from './fcm-tokens.service';
import { RegisterTokenDto } from './dto/register-token.dto';
import { CurrentUser } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';

@ApiTags('FCM Tokens')
@ApiBearerAuth('consumer-jwt')
@Controller('fcm')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
export class FcmTokensController {
  constructor(private readonly fcmTokensService: FcmTokensService) {}

  @Post('tokens')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Register FCM device token (upsert — token is unique key)',
  })
  @ApiResponse({ status: 201, description: 'Token registered / updated' })
  async register(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RegisterTokenDto,
  ) {
    return this.fcmTokensService.register(user.userId, dto);
  }

  @Get('tokens')
  @ApiOperation({
    summary: "List user's registered FCM tokens (token values hidden)",
  })
  @ApiResponse({ status: 200, description: 'Array of token metadata' })
  async findAll(@CurrentUser() user: JwtPayload) {
    return this.fcmTokensService.findAllByUser(user.userId);
  }

  @Post('test')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Send a test push to self (diagnostics — returns token/sent/failed)',
  })
  @ApiResponse({
    status: 200,
    description: '{ tokens, sent, failed, invalid }',
  })
  async test(@CurrentUser() user: JwtPayload) {
    return this.fcmTokensService.sendTestPush(user.userId);
  }

  @Delete('tokens/:id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unregister a single FCM token by ID' })
  @ApiParam({ name: 'id', description: 'FCM token row ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Token deleted' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @ApiResponse({ status: 404, description: 'Token not found' })
  async remove(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.fcmTokensService.remove(id, user.userId);
  }

  @Delete('tokens')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Unregister all user's FCM tokens (full logout)" })
  @ApiResponse({ status: 200, description: 'All tokens deleted' })
  async removeAll(@CurrentUser() user: JwtPayload) {
    return this.fcmTokensService.removeAll(user.userId);
  }
}
