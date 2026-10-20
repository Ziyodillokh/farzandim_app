import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
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
  SummaryQueryDto,
} from './dto/learning.dto';
import { LearningInsightsService } from './learning-insights.service';
import { LearningService } from './learning.service';

/** Ota-ona ilovasi: bolaning kunlik testlari xulosasi va natijalari. */
@ApiTags('Learning (parent)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('PARENT')
@Controller('children/:childId/learning')
export class LearningParentController {
  constructor(
    private readonly learning: LearningService,
    private readonly insights: LearningInsightsService,
  ) {}

  @Get('summary')
  @ApiOperation({ summary: '7 / 30 kunlik xulosa: testlar, foiz, o\'sish, fanlar, streak' })
  async summary(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Query() query: SummaryQueryDto,
  ) {
    await this.learning.assertParentOwns(user.userId, childId);
    return this.insights.summary(childId, query.days ?? 7);
  }

  @Get('results')
  @ApiOperation({ summary: 'Natijalar tarixi' })
  async results(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Query() query: ListResultsQueryDto,
  ) {
    await this.learning.assertParentOwns(user.userId, childId);
    return this.learning.listResults(childId, query);
  }

  @Get('profile')
  @ApiOperation({ summary: 'Bolaning sinfi va fanlari' })
  async getProfile(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
  ) {
    await this.learning.assertParentOwns(user.userId, childId);
    return { profile: await this.learning.getProfile(childId) };
  }

  @Put('profile')
  @ApiOperation({ summary: 'Bolaning sinfi va fanlarini o\'zgartirish' })
  async saveProfile(
    @CurrentUser() user: JwtPayload,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Body() dto: SaveLearningProfileDto,
  ) {
    await this.learning.assertParentOwns(user.userId, childId);
    return { profile: await this.learning.saveProfile(childId, dto) };
  }
}
