import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Req,
  HttpCode,
  HttpStatus,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
  StreamableFile,
  Header,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiParam,
  ApiConsumes,
  ApiBody,
} from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request } from 'express';
import { ChildrenService } from './children.service';
import { CreateChildDto } from './dto/create-child.dto';
import { UpdateChildDto } from './dto/update-child.dto';
import { CurrentUser, Roles, Public } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';

@ApiTags('Children')
@ApiBearerAuth('consumer-jwt')
@Controller('children')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
export class ChildrenController {
  constructor(private readonly childrenService: ChildrenService) {}

  @Get()
  @ApiOperation({ summary: 'List all children of the current parent' })
  @ApiResponse({ status: 200, description: 'Array of children' })
  async findAll(@CurrentUser() user: JwtPayload) {
    return this.childrenService.findAll(user.userId);
  }

  @Post()
  @Roles('PARENT')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new child (parent only)' })
  @ApiResponse({ status: 201, description: 'Child created with family code' })
  @ApiResponse({ status: 403, description: 'Only parents can create children' })
  async create(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateChildDto,
    @Req() req: Request,
  ) {
    return this.childrenService.create(user.userId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get child details by ID' })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Child data' })
  @ApiResponse({ status: 404, description: 'Child not found' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  async findOne(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.childrenService.findOne(id, user.userId);
  }

  @Put(':id')
  @Roles('PARENT')
  @ApiOperation({ summary: 'Update child data (parent only)' })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Updated child data' })
  @ApiResponse({ status: 403, description: 'Only parent can update' })
  @ApiResponse({ status: 404, description: 'Child not found' })
  async update(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateChildDto,
    @Req() req: Request,
  ) {
    return this.childrenService.update(id, user.userId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Delete(':id')
  @Roles('PARENT')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete a child (parent only, cascade)' })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Child deleted' })
  @ApiResponse({ status: 403, description: 'Only parent can delete' })
  @ApiResponse({ status: 404, description: 'Child not found' })
  async remove(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.childrenService.remove(id, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Post(':id/avatar')
  @Roles('PARENT')
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
      },
    },
  })
  @ApiOperation({ summary: 'Upload child avatar (parent only, max 5 MB)' })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Child updated with avatar path' })
  @ApiResponse({ status: 413, description: 'File too large' })
  @ApiResponse({ status: 415, description: 'Unsupported image format' })
  async uploadAvatar(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    return this.childrenService.uploadAvatar(
      id,
      user.userId,
      {
        buffer: file.buffer,
        mimetype: file.mimetype,
        originalname: file.originalname,
      },
      {
        ip: req.ip,
        headers: req.headers as Record<string, string | string[] | undefined>,
      },
    );
  }

  @Get(':id/avatar')
  @ApiOperation({ summary: 'Get signed avatar URL (1 hour)' })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Signed URL + expiresIn' })
  @ApiResponse({ status: 404, description: 'No avatar uploaded' })
  async getAvatar(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.childrenService.getAvatarUrl(id, user.userId);
  }

  // Avatar rasm proxy — telefon → backend → MinIO (signed URL reachability
  // muammosini chetlaydi). @Public: rasm childId UUID orqali olinadi.
  @Get(':id/avatar/image')
  @Public()
  @Header('Cache-Control', 'public, max-age=3600')
  @ApiOperation({ summary: 'Stream child avatar image (proxy)' })
  async avatarImage(@Param('id') id: string): Promise<StreamableFile> {
    const obj = await this.childrenService.getAvatarObject(id);
    return new StreamableFile(obj.body, { type: obj.contentType });
  }

  @Delete(':id/avatar')
  @Roles('PARENT')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete child avatar (parent only)' })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Avatar deleted' })
  async deleteAvatar(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.childrenService.deleteAvatar(id, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Post(':id/pair-code')
  @Roles('PARENT')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Regenerate family code (unpairs current child device, parent only)',
  })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: 'New family code returned' })
  @ApiResponse({ status: 403, description: 'Only parent can regenerate' })
  @ApiResponse({ status: 404, description: 'Child not found' })
  async regeneratePairCode(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.childrenService.regeneratePairCode(id, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }
}
