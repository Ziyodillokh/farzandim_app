import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import {
  ApiBody,
  ApiConsumes,
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
} from '@nestjs/swagger';
import { BooksService } from './books.service';
import { CreateBookDto, UpdateBookDto } from './dto/create-book.dto';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../../common/guards';
import { Permissions } from '../../../common/decorators';

@ApiTags('Admin - Content Books')
@ApiBearerAuth('admin-jwt')
@Controller('admin/content/books')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_content')
export class BooksController {
  constructor(private readonly service: BooksService) {}

  @Get()
  @ApiOperation({ summary: 'List books (paginated)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'q', required: false })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'category', required: false })
  async list(
    @Query('page') page = 1,
    @Query('limit') limit = 20,
    @Query('q') q?: string,
    @Query('status') status?: string,
    @Query('category') category?: string,
    @Query('planRequired') planRequired?: string,
    @Query('ageFrom') ageFrom?: string,
    @Query('ageTo') ageTo?: string,
  ) {
    return this.service.list({
      page: Math.max(1, +page || 1),
      limit: Math.min(100, Math.max(1, +limit || 20)),
      q, status, category, planRequired,
      ageFrom: ageFrom ? +ageFrom : undefined,
      ageTo: ageTo ? +ageTo : undefined,
    });
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a book entry' })
  async create(@Body() dto: CreateBookDto) {
    return this.service.create(dto);
  }

  /**
   * Port of Fastify `POST /admin/books/upload` — multipart MinIO upload.
   * FormData: pdfFile (required), coverFile (optional), metadata JSON string.
   */
  @Post('upload')
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(
    FileFieldsInterceptor([
      { name: 'pdfFile', maxCount: 1 },
      { name: 'coverFile', maxCount: 1 },
    ]),
  )
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        pdfFile: { type: 'string', format: 'binary' },
        coverFile: { type: 'string', format: 'binary' },
        metadata: { type: 'string' },
      },
    },
  })
  @ApiOperation({ summary: 'Upload PDF + optional cover to MinIO' })
  async upload(
    @UploadedFiles()
    files: {
      pdfFile?: Express.Multer.File[];
      coverFile?: Express.Multer.File[];
    },
    @Body('metadata') metadata?: string,
  ) {
    const pdf = files?.pdfFile?.[0];
    const cover = files?.coverFile?.[0];
    if (!pdf) throw new BadRequestException('pdfFile field required');
    if (!metadata) throw new BadRequestException('metadata field required');
    let meta: any;
    try {
      meta = JSON.parse(metadata);
    } catch {
      throw new BadRequestException('Invalid metadata JSON');
    }
    return this.service.upload(
      {
        buffer: pdf.buffer,
        mimetype: pdf.mimetype,
        originalname: pdf.originalname,
      },
      cover
        ? {
            buffer: cover.buffer,
            mimetype: cover.mimetype,
            originalname: cover.originalname,
          }
        : null,
      meta,
    );
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a book' })
  async update(@Param('id') id: string, @Body() dto: UpdateBookDto) {
    return this.service.update(id, dto);
  }

  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve a book' })
  async approve(@Param('id') id: string) {
    return this.service.approve(id);
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject a book' })
  async reject(@Param('id') id: string) {
    return this.service.reject(id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a book' })
  async remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
