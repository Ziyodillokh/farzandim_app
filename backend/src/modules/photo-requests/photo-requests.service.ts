import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  BadRequestException,
  UnsupportedMediaTypeException,
  PayloadTooLargeException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { BUCKETS } from '../../common/storage/storage.constants';
import { CreatePhotoRequestDto } from './dto/create-photo-request.dto';
import { ListPhotoRequestsDto } from './dto/list-photo-requests.dto';

const ALLOWED_IMAGE_MIMES = [
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
];
const MAX_IMAGE_SIZE_BYTES = 15 * 1024 * 1024; // 15 MB

@Injectable()
export class PhotoRequestsService {
  private readonly logger = new Logger(PhotoRequestsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async list(childId: string, userId: string, query: ListPhotoRequestsDto) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const { status, limit } = query;
    const requests = await this.prisma.photoRequest.findMany({
      where: { childId, ...(status && { status }) },
      orderBy: { requestedAt: 'desc' },
      take: limit,
    });

    return { requests, count: requests.length };
  }

  async create(
    childId: string,
    userId: string,
    dto: CreatePhotoRequestDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can request photos');
    }

    const photoRequest = await this.prisma.photoRequest.create({
      data: {
        parentId: userId,
        childId,
        message: dto.message,
      },
    });

    await this.audit.log(
      userId,
      'photo_request',
      'CREATE',
      photoRequest.id,
      dto,
      request,
    );

    if (child.childUserId) {
      this.realtime.emitToUser(
        child.childUserId,
        'photo_request:received',
        photoRequest,
      );
    }
    this.realtime.emitToChild(
      childId,
      'photo_request:created',
      photoRequest,
    );

    return photoRequest;
  }

  async respond(
    id: string,
    userId: string,
    file: Express.Multer.File,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const photoRequest = await this.prisma.photoRequest.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!photoRequest) throw new NotFoundException('Photo request not found');
    if (photoRequest.child.childUserId !== userId) {
      throw new ForbiddenException(
        'Only child can upload photo for this request',
      );
    }
    if (photoRequest.status !== 'PENDING') {
      throw new ConflictException('Request already processed');
    }

    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    if (!ALLOWED_IMAGE_MIMES.includes(file.mimetype)) {
      throw new UnsupportedMediaTypeException(
        `Unsupported image format: ${file.mimetype}`,
      );
    }
    if (file.size > MAX_IMAGE_SIZE_BYTES) {
      throw new PayloadTooLargeException(
        `File too large, max ${MAX_IMAGE_SIZE_BYTES} bytes`,
      );
    }

    const ext = file.originalname?.split('.').pop() || 'jpg';
    const storagePath = `photo-requests/${photoRequest.childId}/${id}.${ext}`;

    await this.storage.upload(
      BUCKETS.avatars,
      storagePath,
      file.buffer,
      file.mimetype,
    );

    const updated = await this.prisma.photoRequest.update({
      where: { id },
      data: {
        photoPath: storagePath,
        status: 'COMPLETED',
        completedAt: new Date(),
      },
    });

    await this.audit.log(
      userId,
      'photo_request',
      'UPDATE',
      id,
      { status: 'COMPLETED' },
      request,
    );
    this.realtime.emitToUser(
      photoRequest.parentId,
      'photo_request:completed',
      updated,
    );
    this.realtime.emitToChild(
      photoRequest.childId,
      'photo_request:completed',
      updated,
    );

    return updated;
  }

  async decline(
    id: string,
    userId: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const photoRequest = await this.prisma.photoRequest.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!photoRequest) throw new NotFoundException('Photo request not found');
    if (photoRequest.child.childUserId !== userId) {
      throw new ForbiddenException('Only child can decline');
    }
    if (photoRequest.status !== 'PENDING') {
      throw new ConflictException('Request already processed');
    }

    const updated = await this.prisma.photoRequest.update({
      where: { id },
      data: { status: 'DECLINED', declinedAt: new Date() },
    });

    await this.audit.log(
      userId,
      'photo_request',
      'UPDATE',
      id,
      { status: 'DECLINED' },
      request,
    );
    this.realtime.emitToUser(
      photoRequest.parentId,
      'photo_request:declined',
      updated,
    );

    return updated;
  }

  async getPhoto(id: string, userId: string) {
    const photoRequest = await this.prisma.photoRequest.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!photoRequest) throw new NotFoundException('Photo request not found');
    if (
      photoRequest.parentId !== userId &&
      photoRequest.child.childUserId !== userId
    ) {
      throw new ForbiddenException('Forbidden');
    }
    if (!photoRequest.photoPath) {
      throw new NotFoundException('Photo not uploaded yet');
    }

    const url = await this.storage.getSignedUrl(
      BUCKETS.avatars,
      photoRequest.photoPath,
      3600,
    );
    return { url, expiresIn: 3600 };
  }

  async remove(
    id: string,
    userId: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const photoRequest = await this.prisma.photoRequest.findUnique({
      where: { id },
    });
    if (!photoRequest) throw new NotFoundException('Photo request not found');
    if (photoRequest.parentId !== userId) {
      throw new ForbiddenException('Only parent can delete');
    }

    if (photoRequest.photoPath) {
      try {
        await this.storage.delete(BUCKETS.avatars, photoRequest.photoPath);
      } catch (err) {
        this.logger.warn('MinIO delete failed for photo, removing DB row anyway', err);
      }
    }

    await this.prisma.photoRequest.delete({ where: { id } });
    await this.audit.log(
      userId,
      'photo_request',
      'DELETE',
      id,
      undefined,
      request,
    );

    return { ok: true };
  }
}
