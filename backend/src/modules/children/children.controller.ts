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
import { Request } from 'express';
import { FastifyRequest } from 'fastify';
import { ChildrenService } from './children.service';
import { CreateChildDto } from './dto/create-child.dto';
import { UpdateChildDto } from './dto/update-child.dto';
import { UpdateDeviceInfoDto } from './dto/update-device-info.dto';
import { UpdateInterestsDto } from './dto/update-interests.dto';
import { UpdateMyProfileDto } from './dto/update-my-profile.dto';
import { CurrentUser, Roles, Public } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';

/** @fastify/multipart yuklagan fayl (req.file()). */
interface MultipartFile {
  toBuffer(): Promise<Buffer>;
  mimetype: string;
  filename: string;
}
interface MultipartRequest {
  file(): Promise<MultipartFile | undefined>;
}

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

  @Get(':id/parent')
  @ApiOperation({
    summary: "Bog'langan ota-ona profili (ism) — bola yoki ota-ona o'qiydi",
  })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Parent public profile' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  async getParentProfile(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.childrenService.getParentProfile(id, user.userId);
  }

  @Get(':id/device-policy')
  @ApiOperation({
    summary: 'Qurilma siyosati (blockUnknownSources) — ota-ona yoki bola o\'qiydi',
  })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: '{ blockUnknownSources }' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @ApiResponse({ status: 404, description: 'Child not found' })
  async getDevicePolicy(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.childrenService.getDevicePolicy(id, user.userId);
  }

  @Post(':id/uninstall-guard-disabled')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Bola Device Admin (o\'chirish himoyasi)ni o\'chirdi — ota-onaga xabar',
  })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  async reportUninstallGuardDisabled(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.childrenService.reportUninstallGuardDisabled(id, user.userId);
  }

  @Post(':id/device-info')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Child device heartbeat (model/battery/wifi + lastSeen, no GPS)',
  })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Device info updated' })
  async updateDeviceInfo(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateDeviceInfoDto,
  ) {
    return this.childrenService.updateDeviceInfo(id, user.userId, dto);
  }

  @Post(':id/ring')
  @Roles('PARENT')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Ring the child device loudly even on silent (find device)',
  })
  @ApiParam({ name: 'id', description: 'Child ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Ring command sent via FCM' })
  @ApiResponse({ status: 400, description: 'Child device not paired' })
  async ring(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.childrenService.ring(id, user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  // Diqqat: `/me/interests` `:id` dan OLDIN — static route param'ga tushib
  // qolmasin (`me` UUID emas, lekin `:id` bilan moslashadi).
  @Put('me/interests')
  @Roles('CHILD')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: "Joriy bola qiziqishlarini yangilash (onboarding'dan keladi)",
  })
  @ApiResponse({ status: 200, description: 'Qiziqishlar saqlandi' })
  @ApiResponse({ status: 403, description: 'Faqat bola o\'zini yangilay oladi' })
  @ApiResponse({ status: 404, description: 'Bola yozuvi topilmadi' })
  async updateMyInterests(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateInterestsDto,
    @Req() req: Request,
  ) {
    return this.childrenService.updateMyInterests(user.userId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  // Diqqat: `me` `:id` dan OLDIN — bola o'z profilini (ism/yosh/hudud)
  // tahrirlaydi. Account Edit ekrani shu endpoint'ni chaqiradi.
  @Put('me')
  @Roles('CHILD')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Joriy bola o\'z profilini yangilaydi (ism/yosh/hudud)' })
  @ApiResponse({ status: 200, description: 'Yangilangan bola ma\'lumoti' })
  @ApiResponse({ status: 404, description: 'Bola yozuvi topilmadi' })
  async updateMe(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateMyProfileDto,
    @Req() req: Request,
  ) {
    return this.childrenService.updateMe(user.userId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  // Bola o'z profil rasmini yuklaydi (MinIO). `me/avatar` `:id/avatar` dan oldin.
  @Post('me/avatar')
  @Roles('CHILD')
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
      },
    },
  })
  @ApiOperation({ summary: 'Joriy bola o\'z rasmini yuklaydi (max 5 MB)' })
  @ApiResponse({ status: 200, description: 'Rasm yuklandi, photoPath yangilandi' })
  @ApiResponse({ status: 413, description: 'Fayl juda katta' })
  @ApiResponse({ status: 415, description: 'Qo\'llab-quvvatlanmaydigan format' })
  async uploadMyAvatar(
    @CurrentUser() user: JwtPayload,
    @Req() req: FastifyRequest,
  ) {
    const data = await (req as unknown as MultipartRequest).file();
    if (!data) {
      throw new BadRequestException('No file uploaded');
    }
    const buffer = await data.toBuffer();
    return this.childrenService.uploadMyAvatar(
      user.userId,
      {
        buffer,
        mimetype: data.mimetype,
        originalname: data.filename,
      },
      {
        ip: req.ip,
        headers: req.headers as Record<string, string | string[] | undefined>,
      },
    );
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
    @Req() req: FastifyRequest,
  ) {
    // Fastify adapter — Multer ishlamaydi. @fastify/multipart req.file() bilan
    // o'qiymiz (main.ts'da ro'yxatdan o'tgan).
    const data = await (req as unknown as MultipartRequest).file();
    if (!data) {
      throw new BadRequestException('No file uploaded');
    }
    const buffer = await data.toBuffer();
    return this.childrenService.uploadAvatar(
      id,
      user.userId,
      {
        buffer,
        mimetype: data.mimetype,
        originalname: data.filename,
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
