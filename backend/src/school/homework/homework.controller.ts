import { Body, Controller, Get, Header, HttpCode, HttpStatus, Param, Post, Query, Req, Res, StreamableFile, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { FastifyReply, FastifyRequest } from 'fastify';
import { CurrentUser, Public, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { HomeworkPhotoService } from './homework-photo.service';
import { HomeworkStaffService } from './homework-staff.service';
import { HomeworkSubmitService } from './homework-submit.service';

/** Yozma vazifa — xodim paneli. */
@ApiTags('School - Homework')
@SchoolAuth()
@Controller('school/learning')
export class HomeworkStaffController {
  constructor(private readonly staff: HomeworkStaffService) {}

  @Get('assignments/:id/submissions')
  @ApiOperation({ summary: "Yozma vazifa: sinf o'quvchilari va ularning topshiriqlari (rasm havolalari bilan)" })
  submissions(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.staff.submissions(actor, id);
  }

  @Post('submissions/:id/review')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Topshiriqni qabul qilish (ACCEPTED) yoki qaytarish (RETURNED)' })
  review(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.staff.review(actor, id, body);
  }
}

/** Yozma vazifa — Parvoz Growth bola ilovasi. */
@ApiTags('School (child app)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('child/school/assignments')
export class HomeworkChildController {
  constructor(private readonly submit: HomeworkSubmitService) {}

  @Post(':id/submission')
  @HttpCode(HttpStatus.OK)
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: "Yozma vazifani topshirish: 1-5 rasm (JPEG/PNG/WebP, <= 8 MB) + comment + requestId" })
  submission(@CurrentUser() user: JwtPayload, @Param('id') id: string, @Req() req: FastifyRequest) {
    return this.submit.submit(user.userId, id, req);
  }
}

/**
 * Rasm proksisi: autentifikatsiyasiz, lekin imzolangan havola (`?exp=&sig=`) bilan.
 * `<img>` Authorization yubora olmaydi; havolani faqat server (xodim / bola javobi) beradi.
 */
@ApiTags('School - Homework')
@Controller('school/homework/photos')
export class HomeworkPhotoController {
  constructor(private readonly photos: HomeworkPhotoService) {}

  @Get(':photoId')
  @Public()
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({ summary: 'Yozma vazifa rasmi (imzolangan havola)' })
  async photo(
    @Param('photoId') photoId: string,
    @Res({ passthrough: true }) reply: FastifyReply,
    @Query('exp') exp?: string,
    @Query('sig') sig?: string,
  ) {
    const object = await this.photos.read(photoId, exp, sig);
    // Faqat muvaffaqiyatli javob keshlanadi (403/404/503 emas).
    reply.header('Cache-Control', 'private, max-age=3600');
    return new StreamableFile(object.body, { type: object.contentType });
  }
}
