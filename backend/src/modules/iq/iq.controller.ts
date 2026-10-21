import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { IqAnswerDto } from './dto/iq.dto';
import { IqService } from './iq.service';

/** Bola ilovasi: IQ test (rasmli matritsalar) — docs/IQ-REJA.md §4. */
@ApiTags('IQ (child)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('iq')
export class IqController {
  constructor(private readonly iq: IqService) {}

  @Get('overview')
  @ApiOperation({
    summary: 'Yosh holati, faol sessiya, oxirgi natija va tarix',
  })
  async overview(@CurrentUser() user: JwtPayload) {
    return this.iq.overview(await this.iq.childIdForUser(user.userId));
  }

  @Post('sessions')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Yangi yoki davom etayotgan sessiya' })
  async start(@CurrentUser() user: JwtPayload) {
    return this.iq.startSession(await this.iq.childIdForUser(user.userId));
  }

  @Get('sessions/:id')
  @ApiOperation({ summary: 'Sessiya: savollar, tanlangan javoblar va natija' })
  async session(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) {
    return this.iq.sessionView(await this.iq.childIdForUser(user.userId), id);
  }

  @Put('sessions/:id/answers/:itemId')
  @ApiOperation({
    summary: "Javobni saqlash yoki o'zgartirish (to'g'riligi qaytarilmaydi)",
  })
  async answer(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: IqAnswerDto,
  ) {
    return this.iq.answer(await this.iq.childIdForUser(user.userId), id, itemId, dto);
  }

  @Post('sessions/:id/complete')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Yakunlash — natija bilan (idempotent)' })
  async complete(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) {
    return this.iq.complete(await this.iq.childIdForUser(user.userId), id);
  }
}
