import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { AnnouncementSendService } from './announcement-send.service';
import { AnnouncementsService } from './announcements.service';

/** E'lonlar (panel `commsService.announcements`). */
@ApiTags('School - Comms')
@SchoolAuth()
@Controller('school/comms/announcements')
export class CommsAnnouncementsController {
  constructor(
    private readonly announcements: AnnouncementsService,
    private readonly sender: AnnouncementSendService,
  ) {}

  @Get()
  list(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.announcements.list(actor, query);
  }

  @Get(':id')
  get(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.announcements.get(actor, id);
  }

  /** Yangi qoralama. */
  @Post('drafts')
  createDraft(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.announcements.saveDraft(actor, body);
  }

  /** Mavjud qoralama / rejalashtirilgan xabarni qoralama sifatida saqlash. */
  @Put(':id/draft')
  saveDraft(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.announcements.saveDraft(actor, body, id);
  }

  /** Yangi xabar: darhol yoki `scheduledAt` bo'yicha. */
  @Post('send')
  @HttpCode(HttpStatus.OK)
  send(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.sender.send(actor, body);
  }

  /** Mavjud qoralama / rejalashtirilgan xabarni (tahrirlab) yuborish yoki rejalashtirish. */
  @Post(':id/send')
  @HttpCode(HttpStatus.OK)
  sendExisting(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.sender.send(actor, body, id);
  }

  @Post(':id/send-now')
  @HttpCode(HttpStatus.OK)
  sendNow(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.sender.sendNow(actor, id);
  }

  @Post(':id/duplicate')
  duplicate(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.announcements.duplicate(actor, id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Actor() actor: SchoolActor, @Param('id') id: string) {
    await this.announcements.remove(actor, id);
  }
}
