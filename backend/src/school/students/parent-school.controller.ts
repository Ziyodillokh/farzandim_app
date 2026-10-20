import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { SCHOOL_LINK_LIMIT } from '../../common/throttle/throttle.config';
import { ParentLinksService } from './parent-links.service';

/** Parvoz Parents ilovasi: maktabga ulanish va o'quvchini farzand bilan moslash. */
@ApiTags('School (parent app)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('PARENT')
@Controller('parent/school')
export class ParentSchoolController {
  constructor(private readonly links: ParentLinksService) {}

  @Post('link')
  @UseGuards(ThrottlerGuard)
  @Throttle({ schoolLink: SCHOOL_LINK_LIMIT })
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Maktab taklif kodini kiritish (8 belgi, 7 kun)' })
  redeem(@CurrentUser() user: JwtPayload, @Body() body: unknown, @Req() req: FastifyRequest) {
    return this.links.redeem(user.userId, body, req.ip);
  }

  @Get('links')
  @ApiOperation({ summary: 'Maktab bog\'lanishlari va farzandlar (moslash uchun)' })
  list(@CurrentUser() user: JwtPayload) {
    return this.links.links(user.userId);
  }

  @Put('students/:studentId/child')
  @ApiOperation({ summary: 'O\'quvchini o\'z farzandi bilan moslash (childId: null — olib tashlash)' })
  setChild(
    @CurrentUser() user: JwtPayload,
    @Param('studentId', ParseUUIDPipe) studentId: string,
    @Body() body: unknown,
  ) {
    return this.links.setChild(user.userId, studentId, body);
  }

  @Delete('links/:guardianId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Maktab bilan aloqani uzish' })
  async unlink(@CurrentUser() user: JwtPayload, @Param('guardianId', ParseUUIDPipe) guardianId: string) {
    await this.links.unlink(user.userId, guardianId);
  }
}
