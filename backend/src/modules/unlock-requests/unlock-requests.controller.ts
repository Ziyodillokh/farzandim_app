import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { UnlockRequestsService } from './unlock-requests.service';
import { CreateUnlockRequestDto } from './dto/create-unlock-request.dto';
import { DecideUnlockRequestDto } from './dto/decide-unlock-request.dto';
import { ListUnlockRequestsDto } from './dto/list-unlock-requests.dto';

@ApiTags('Unlock Requests')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller('unlock-requests')
export class UnlockRequestsController {
  constructor(private readonly service: UnlockRequestsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Child requests extra time for a blocked app/screen' })
  create(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateUnlockRequestDto,
  ) {
    return this.service.create(user.userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Parent lists unlock requests (filter by status)' })
  list(
    @CurrentUser() user: JwtPayload,
    @Query() query: ListUnlockRequestsDto,
  ) {
    return this.service.listForParent(user.userId, query.status);
  }

  @Get('active')
  @ApiOperation({ summary: 'Child lists its currently active (approved) grants' })
  active(@CurrentUser() user: JwtPayload) {
    return this.service.listActiveGrants(user.userId);
  }

  @Post(':id/decide')
  @ApiOperation({ summary: 'Parent approves (with minutes) or denies a request' })
  decide(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: DecideUnlockRequestDto,
  ) {
    return this.service.decide(id, user.userId, dto);
  }
}
