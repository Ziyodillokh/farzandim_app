import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { CareInsightsService } from './care-insights.service';
import { CareRequestsService } from './care-requests.service';
import { CareSurveysService } from './care-surveys.service';

@ApiTags('School - Care')
@SchoolAuth()
@Controller('school/care')
export class CareController {
  constructor(
    private readonly insights: CareInsightsService,
    private readonly requests: CareRequestsService,
    private readonly surveys: CareSurveysService,
  ) {}

  // ── Anonim natija (care.aggregate) ─────────────────────────────────

  @Get('surveys/options')
  surveyOptions(@Actor() actor: SchoolActor) {
    return this.insights.surveyOptions(actor);
  }

  @Get('surveys/summaries')
  surveySummaries(@Actor() actor: SchoolActor) {
    return this.insights.surveySummaries(actor);
  }

  @Get('aggregate')
  @ApiOperation({ summary: 'Umumlashgan natija (K=5, kesimlararo izchil yashirish)' })
  aggregate(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.insights.aggregate(actor, query);
  }

  // ── Murojaatlar (care.individual) ──────────────────────────────────

  @Get('requests')
  listRequests(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.requests.listRequests(actor, query);
  }

  @Get('requests/:id')
  getRequest(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.requests.getRequest(actor, id);
  }

  @Put('requests/:id/status')
  updateStatus(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.requests.updateRequestStatus(actor, id, body);
  }

  @Post('requests/:id/notes')
  addNote(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.requests.addRequestNote(actor, id, body);
  }

  @Put('requests/:id/meeting')
  scheduleMeeting(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.requests.scheduleMeeting(actor, id, body);
  }

  @Post('requests/:id/protocol')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Himoya protokoli: direktor va navbatchiga signal (tafsilotsiz)' })
  activateProtocol(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.requests.activateProtocol(actor, id);
  }

  // ── So'rovnomalar va savollar banki (care.surveys) ─────────────────

  @Get('surveys')
  listSurveys(@Actor() actor: SchoolActor) {
    return this.surveys.listSurveys(actor);
  }

  @Post('surveys')
  createSurvey(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.surveys.createSurvey(actor, body);
  }

  @Put('surveys/:id')
  updateSurvey(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.surveys.updateSurvey(actor, id, body);
  }

  @Delete('surveys/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteSurvey(@Actor() actor: SchoolActor, @Param('id') id: string) {
    await this.surveys.deleteSurvey(actor, id);
  }

  @Post('surveys/:id/activate')
  @HttpCode(HttpStatus.OK)
  activateSurvey(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.surveys.activateSurvey(actor, id);
  }

  @Post('surveys/:id/close')
  @HttpCode(HttpStatus.OK)
  closeSurvey(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.surveys.closeSurvey(actor, id);
  }

  @Get('questions')
  listQuestions(@Actor() actor: SchoolActor) {
    return this.surveys.listQuestions(actor);
  }

  @Post('questions')
  createQuestion(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.surveys.createQuestion(actor, body);
  }

  @Put('questions/:id')
  updateQuestion(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.surveys.updateQuestion(actor, id, body);
  }

  @Delete('questions/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteQuestion(@Actor() actor: SchoolActor, @Param('id') id: string) {
    await this.surveys.deleteQuestion(actor, id);
  }
}
