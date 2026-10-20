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
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { GuardiansService } from './guardians.service';
import { Student360Service } from './student-360.service';
import { StudentsWriteService } from './students-write.service';
import { StudentsService } from './students.service';

@ApiTags('School - Students')
@SchoolAuth()
@Controller('school/students')
export class StudentsController {
  constructor(
    private readonly students: StudentsService,
    private readonly write: StudentsWriteService,
    private readonly card: Student360Service,
    private readonly guardians: GuardiansService,
  ) {}

  @Get('class-options')
  @ApiOperation({ summary: 'Filtr va formalar uchun doiradagi sinflar' })
  classOptions(@Actor() actor: SchoolActor) {
    return this.students.classOptions(actor);
  }

  @Get()
  list(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.students.list(actor, query);
  }

  @Post()
  create(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.write.create(actor, body);
  }

  @Post('import')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'CSV import (yaroqsiz qatorlar sababi bilan qaytadi)' })
  importRows(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.write.importRows(actor, body);
  }

  @Delete('notes/:noteId')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteNote(@Actor() actor: SchoolActor, @Param('noteId') noteId: string) {
    await this.card.deleteNote(actor, noteId);
  }

  @Get(':id')
  get(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.students.get(actor, id);
  }

  @Put(':id')
  update(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.write.update(actor, id, body);
  }

  @Put(':id/archived')
  setArchived(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: { archived?: unknown } | undefined) {
    return this.write.setArchived(actor, id, body?.archived);
  }

  @Post(':id/guardians')
  addGuardian(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.guardians.addToStudent(actor, id, body);
  }

  @Get(':id/history')
  @ApiOperation({ summary: '360° tarix: erta ketish, tuzatish, xabar, istisno, to\'lov' })
  history(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.card.history(actor, id);
  }

  @Get(':id/notes')
  notes(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.card.notes(actor, id);
  }

  @Post(':id/notes')
  addNote(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.card.addNote(actor, id, body);
  }
}
