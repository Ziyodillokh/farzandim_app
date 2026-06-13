import {
  Body,
  Controller,
  Get,
  Post,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { ConsumerContentService } from './consumer-content.service';
import { PaginationDto } from './dto/pagination.dto';
import { CategoriesQueryDto } from './dto/categories-query.dto';
import { ReportDurationDto } from './dto/report-duration.dto';

@ApiTags('Consumer Content')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller('content')
export class ConsumerContentController {
  constructor(private readonly service: ConsumerContentService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get current child content context' })
  getMe(@CurrentUser() user: JwtPayload) {
    return this.service.getMe(user.userId);
  }

  @Get('videos')
  @ApiOperation({ summary: 'List videos (age + plan filtered)' })
  getVideos(
    @CurrentUser() user: JwtPayload,
    @Query() query: PaginationDto,
  ) {
    return this.service.getVideos(
      user.userId,
      query.page ?? 1,
      query.limit ?? 20,
    );
  }

  @Get('audiobooks')
  @ApiOperation({ summary: 'List audiobooks (age + plan filtered)' })
  getAudiobooks(
    @CurrentUser() user: JwtPayload,
    @Query() query: PaginationDto,
  ) {
    return this.service.getAudiobooks(
      user.userId,
      query.page ?? 1,
      query.limit ?? 20,
    );
  }

  @Get('books')
  @ApiOperation({ summary: 'List books (age + plan filtered)' })
  getBooks(
    @CurrentUser() user: JwtPayload,
    @Query() query: PaginationDto,
  ) {
    return this.service.getBooks(
      user.userId,
      query.page ?? 1,
      query.limit ?? 20,
    );
  }

  @Get('categories')
  @ApiOperation({ summary: 'List content categories' })
  getCategories(@Query() query: CategoriesQueryDto) {
    return this.service.getCategories(query.kind);
  }

  @Post('videos/:id/view')
  @ApiOperation({ summary: 'Record a video view' })
  recordVideoView(@Param('id') id: string) {
    return this.service.recordVideoView(id);
  }

  @Post('videos/:id/duration')
  @ApiOperation({ summary: 'Report real video duration (sets only if unknown)' })
  reportVideoDuration(
    @Param('id') id: string,
    @Body() dto: ReportDurationDto,
  ) {
    return this.service.reportVideoDuration(id, dto.durationSec);
  }

  @Post('videos/:id/like')
  @ApiOperation({ summary: 'Like a video' })
  recordVideoLike(@Param('id') id: string) {
    return this.service.recordVideoLike(id);
  }

  @Post('audiobooks/:id/play')
  @ApiOperation({ summary: 'Record an audiobook play' })
  recordAudiobookPlay(@Param('id') id: string) {
    return this.service.recordAudiobookPlay(id);
  }

  @Post('books/:id/read')
  @ApiOperation({ summary: 'Record a book read' })
  recordBookRead(@Param('id') id: string) {
    return this.service.recordBookRead(id);
  }
}
