import { Body, Controller, Get, Param, Put } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { ProfileService } from './profile.service';

@ApiTags('School - Profile')
@SchoolAuth()
@Controller('school/profile')
export class ProfileController {
  constructor(private readonly profile: ProfileService) {}

  @Get('me')
  me(@Actor() actor: SchoolActor) {
    return this.profile.me(actor);
  }

  @Get('avatars')
  avatars(@Actor() actor: SchoolActor) {
    return this.profile.avatars(actor);
  }

  @Put('photo/:staffId')
  setPhoto(
    @Actor() actor: SchoolActor,
    @Param('staffId') staffId: string,
    @Body() body: { photo?: unknown } | undefined,
  ) {
    return this.profile.setPhoto(actor, staffId, body?.photo ?? null);
  }
}
