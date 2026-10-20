import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { AssessmentsAssignService } from './assessments-assign.service';
import { AssessmentsCsvService } from './assessments-csv.service';
import { AssessmentsEditorService } from './assessments-editor.service';
import { AssessmentsLibraryService } from './assessments-library.service';
import { AssessmentsResultsService } from './assessments-results.service';
import { AssessmentsStatusService } from './assessments-status.service';

/** Psixologik testlar (skrining): kutubxona, konstruktor, tayinlash, natijalar. */
@ApiTags('School - Assessments')
@SchoolAuth()
@Controller('school/assessments')
export class AssessmentsController {
  constructor(
    private readonly library: AssessmentsLibraryService,
    private readonly editor: AssessmentsEditorService,
    private readonly status: AssessmentsStatusService,
    private readonly assignments: AssessmentsAssignService,
    private readonly results: AssessmentsResultsService,
    private readonly csv: AssessmentsCsvService,
  ) {}

  // ── Kutubxona va konstruktor (assessments.manage) ─────────────────

  @Get('tests')
  listTests(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.library.listTests(actor, query);
  }

  @Post('tests')
  createTest(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.editor.createTest(actor, body);
  }

  @Post('tests/import')
  @ApiOperation({ summary: 'JSON fayl (`parvoz.psych-test` v1) → IMPORTED qoralama; body `{ json }`' })
  importTest(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.editor.importTest(actor, body);
  }

  @Get('tests/:id')
  getTest(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.library.getTest(actor, id);
  }

  @Put('tests/:id')
  @ApiOperation({ summary: 'Tahrirlash (nashr etilgan testda savol/shkala o\'zgarsa — yangi versiya)' })
  updateTest(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.editor.updateTest(actor, id, body);
  }

  @Put('tests/:id/norms')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Me\'yorlar; `{ norms: null }` — standart me\'yorlar tiklanadi' })
  async updateNorms(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    await this.status.updateNorms(actor, id, body);
  }

  @Post('tests/:id/publish')
  @HttpCode(HttpStatus.OK)
  publishTest(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.status.publishTest(actor, id);
  }

  @Post('tests/:id/archive')
  @HttpCode(HttpStatus.OK)
  archiveTest(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.status.archiveTest(actor, id);
  }

  @Post('tests/:id/duplicate')
  duplicateTest(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.editor.duplicateTest(actor, id);
  }

  @Get('tests/:id/export')
  @ApiOperation({ summary: 'JSON fayl konverti (`parvoz.psych-test` v1)' })
  exportTest(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.library.exportTest(actor, id);
  }

  // ── Natijalar (psixolog — to'liq; sinf rahbari — o'z sinfi, darajalar) ──

  @Get('tests/:id/results')
  resultsByTest(@Actor() actor: SchoolActor, @Param('id') id: string, @Query() query: Record<string, unknown>) {
    return this.results.resultsByTest(actor, id, query);
  }

  @Post('results/csv/preview')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'CSV natijalar — oldindan ko\'rish (bazani o\'zgartirmaydi); body `{ text }`' })
  previewResultsCsv(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.csv.previewResultsCsv(actor, body);
  }

  @Post('results/csv/import')
  @HttpCode(HttpStatus.OK)
  importResultsCsv(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.csv.importResultsCsv(actor, body);
  }

  // ── Tayinlashlar ───────────────────────────────────────────────────

  @Get('class-options')
  classOptions(@Actor() actor: SchoolActor) {
    return this.library.classOptions(actor);
  }

  @Get('assignments')
  listAssignments(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.assignments.listAssignments(actor, query);
  }

  @Post('assignments')
  assign(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.assignments.assign(actor, body);
  }

  @Post('assignments/:id/unassign')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Natija yo\'q — CANCELLED, bor — CLOSED' })
  unassign(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.assignments.unassign(actor, id);
  }

  @Post('assignments/:id/close')
  @HttpCode(HttpStatus.OK)
  closeAssignment(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.assignments.closeAssignment(actor, id);
  }
}
