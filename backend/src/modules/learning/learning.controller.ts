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
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import {
  ListResultsQueryDto,
  SaveLearningProfileDto,
  StartAttemptDto,
  SubmitAnswerDto,
} from './dto/learning.dto';
import { LearningService } from './learning.service';

/** Bola ilovasi: kunlik testlar (Growth). */
@ApiTags('Learning (child)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('learning')
export class LearningController {
  constructor(private readonly learning: LearningService) {}

  @Get('profile')
  @ApiOperation({ summary: 'O\'quv profili (sinf + fanlar); tanlanmagan bo\'lsa null' })
  async getProfile(@CurrentUser() user: JwtPayload) {
    const childId = await this.learning.childIdForUser(user.userId);
    return { profile: await this.learning.getProfile(childId) };
  }

  @Put('profile')
  @ApiOperation({ summary: 'Sinf va fanlarni saqlash' })
  async saveProfile(@CurrentUser() user: JwtPayload, @Body() dto: SaveLearningProfileDto) {
    const childId = await this.learning.childIdForUser(user.userId);
    return { profile: await this.learning.saveProfile(childId, dto) };
  }

  @Post('attempts')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Fan testini boshlash yoki bugungi yarim qolganini davom ettirish' })
  async start(@CurrentUser() user: JwtPayload, @Body() dto: StartAttemptDto) {
    const childId = await this.learning.childIdForUser(user.userId);
    return this.learning.startAttempt(childId, dto.subject);
  }

  @Get('attempts/:id')
  @ApiOperation({ summary: 'Urinish holati (savollar + berilgan javoblar)' })
  async attempt(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) {
    const childId = await this.learning.childIdForUser(user.userId);
    return this.learning.attemptView(childId, id);
  }

  @Post('attempts/:id/answers')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Javob — to\'g\'ri / xato, to\'g\'ri javob va izoh (idempotent)' })
  async answer(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SubmitAnswerDto,
  ) {
    const childId = await this.learning.childIdForUser(user.userId);
    return this.learning.submitAnswer(childId, id, dto);
  }

  @Post('attempts/:id/complete')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Yakunlash — natija va DON (idempotent)' })
  async complete(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) {
    const childId = await this.learning.childIdForUser(user.userId);
    return this.learning.completeAttempt(childId, id);
  }

  @Get('attempts/:id/review')
  @ApiOperation({ summary: 'Yakunlangan urinish tahlili' })
  async review(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) {
    const childId = await this.learning.childIdForUser(user.userId);
    return this.learning.review(childId, id);
  }

  @Get('results')
  @ApiOperation({ summary: 'Natijalar tarixi (yangisi birinchi, kursor bilan)' })
  async results(@CurrentUser() user: JwtPayload, @Query() query: ListResultsQueryDto) {
    const childId = await this.learning.childIdForUser(user.userId);
    return this.learning.listResults(childId, query);
  }
}
