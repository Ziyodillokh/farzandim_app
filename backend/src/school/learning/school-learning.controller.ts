import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { SchoolLearningChildService } from './school-learning-child.service';
import { SchoolLearningService } from './school-learning.service';

@ApiTags('School - Learning')
@SchoolAuth()
@Controller('school/learning')
export class SchoolLearningController {
  constructor(private readonly learning: SchoolLearningService) {}

  @Get('activity')
  @ApiOperation({ summary: 'Sinflar faolligi (Daily Learning, faqat sinf darajasi)' })
  activity(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.learning.activity(actor, query);
  }

  @Get('interests')
  interests(@Actor() actor: SchoolActor) {
    return this.learning.interests(actor);
  }

  @Get('materials')
  materials(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.learning.materials(actor, query);
  }

  @Get('assignments')
  assignments(@Actor() actor: SchoolActor) {
    return this.learning.assignments(actor);
  }

  @Get('class-options')
  classOptions(@Actor() actor: SchoolActor) {
    return this.learning.classOptions(actor);
  }

  @Post('assignments')
  createAssignment(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.learning.createAssignment(actor, body);
  }

  @Delete('assignments/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteAssignment(@Actor() actor: SchoolActor, @Param('id') id: string) {
    await this.learning.deleteAssignment(actor, id);
  }
}

/** Parvoz Growth bola ilovasi: maktab topshiriqlari. */
@ApiTags('School (child app)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('child/school/assignments')
export class SchoolLearningChildController {
  constructor(private readonly learning: SchoolLearningChildService) {}

  @Get()
  list(@CurrentUser() user: JwtPayload) {
    return this.learning.assignments(user.userId);
  }
}
