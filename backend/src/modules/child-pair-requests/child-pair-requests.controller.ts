import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { ChildPairRequestsService } from './child-pair-requests.service';
import { ListPairRequestsDto } from './dto/list-pair-requests.dto';
import { Request } from 'express';

@ApiTags('Child Pair Requests')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller()
export class ChildPairRequestsController {
  constructor(private readonly service: ChildPairRequestsService) {}

  @Get('children/:childId/pair-requests')
  @ApiOperation({ summary: 'List pair requests for a child (parent only)' })
  list(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Query() query: ListPairRequestsDto,
  ) {
    return this.service.list(childId, user.userId, query.status);
  }

  @Post('children/:childId/pair-requests/:id/approve')
  @ApiOperation({ summary: 'Approve pair request (parent only)' })
  approve(
    @Param('childId') childId: string,
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.service.approve(childId, id, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Post('children/:childId/pair-requests/:id/reject')
  @ApiOperation({ summary: 'Reject pair request (parent only)' })
  reject(
    @Param('childId') childId: string,
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.service.reject(childId, id, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }
}
