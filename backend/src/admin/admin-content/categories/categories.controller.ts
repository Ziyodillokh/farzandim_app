import {
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
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { CategoriesService } from './categories.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../../common/guards';
import { Permissions } from '../../../common/decorators';

@ApiTags('Admin - Content Categories')
@ApiBearerAuth('admin-jwt')
@Controller('admin/categories')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('manage_content')
export class CategoriesController {
  constructor(private readonly service: CategoriesService) {}

  @Get()
  @ApiOperation({ summary: 'List content categories' })
  @ApiQuery({ name: 'kind', required: false })
  async list(@Query('kind') kind?: string) {
    return this.service.list(kind);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a category' })
  async create(@Body() dto: CreateCategoryDto) {
    return this.service.create(dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a category' })
  async update(@Param('id') id: string, @Body() dto: Partial<CreateCategoryDto>) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a category' })
  async remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
