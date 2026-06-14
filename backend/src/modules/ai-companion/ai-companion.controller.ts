import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { AiCompanionService } from './ai-companion.service';
import { ChatDto } from './dto/chat.dto';

@ApiTags('AI Companion')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller()
export class AiCompanionController {
  constructor(private readonly service: AiCompanionService) {}

  @Post('ai/chat')
  @ApiOperation({ summary: 'Child sends a message to Faro (AI companion)' })
  chat(@CurrentUser() user: JwtPayload, @Body() dto: ChatDto) {
    return this.service.chat(user.userId, dto.message);
  }

  @Get('ai/history')
  @ApiOperation({ summary: 'Child reads own AI conversation' })
  history(@CurrentUser() user: JwtPayload) {
    return this.service.getHistory(user.userId);
  }

  @Get('children/:childId/ai-history')
  @ApiOperation({ summary: 'Parent views child AI conversation (#70)' })
  parentHistory(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.getHistoryForParent(user.userId, childId);
  }
}
