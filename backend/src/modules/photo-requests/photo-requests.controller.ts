import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  Query,
  Req,
  HttpCode,
  HttpStatus,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { PhotoRequestsService } from './photo-requests.service';
import { CreatePhotoRequestDto } from './dto/create-photo-request.dto';
import { ListPhotoRequestsDto } from './dto/list-photo-requests.dto';
import { Request } from 'express';

@ApiTags('Photo Requests')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller()
export class PhotoRequestsController {
  constructor(private readonly service: PhotoRequestsService) {}

  @Get('children/:childId/photo-requests')
  @ApiOperation({ summary: 'List photo requests for a child' })
  list(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Query() query: ListPhotoRequestsDto,
  ) {
    return this.service.list(childId, user.userId, query);
  }

  @Post('children/:childId/photo-requests')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a photo request (parent only)' })
  create(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreatePhotoRequestDto,
    @Req() req: Request,
  ) {
    return this.service.create(childId, user.userId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Post('photo-requests/:id/respond')
  @ApiOperation({ summary: 'Child responds with a photo upload' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file'))
  respond(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request,
  ) {
    return this.service.respond(id, user.userId, file, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Put('photo-requests/:id/decline')
  @ApiOperation({ summary: 'Child declines photo request' })
  decline(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.service.decline(id, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('photo-requests/:id/photo')
  @ApiOperation({ summary: 'Get signed URL for photo request photo' })
  getPhoto(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.getPhoto(id, user.userId);
  }

  @Delete('photo-requests/:id')
  @ApiOperation({ summary: 'Delete photo request (parent only)' })
  remove(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.service.remove(id, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }
}
