import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Public } from '../../common/decorators';
import { AppVersionService } from './app-version.service';
import { AppVersionQueryDto } from './dto/app-version-query.dto';

@ApiTags('App Version')
@Controller('app')
export class AppVersionController {
  constructor(private readonly service: AppVersionService) {}

  @Get('version')
  @Public()
  @ApiOperation({ summary: 'Get app version info (no auth required)' })
  getVersion(@Query() query: AppVersionQueryDto) {
    return this.service.getVersion(query.app);
  }
}
