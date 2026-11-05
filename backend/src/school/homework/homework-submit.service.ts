// Parvoz Growth bola ilovasi: yozma vazifani rasm bilan topshirish. (topshiriq, o'quvchi)
// bo'yicha bitta yozuv: qayta yuborish rasmlar va izohni ALMASHTIRADI (holat -> SUBMITTED,
// baho tozalanadi, eski obyektlar o'chadi). QABUL QILINGAN (ACCEPTED) vazifa o'zgarmaydi.
// Idempotentlik: klient `requestId` — shu so'rov bilan allaqachon saqlangan yozuv
// qaytadi (rasmlar takrorlanmaydi). Tenant: faqat bolaning o'z sinfiga berilgan topshiriq.

import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, SchoolHomeworkPhoto } from '@prisma/client';
import type { FastifyRequest } from 'fastify';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { requireEnrolledStudent } from '../common/child-student';
import { childAssignmentWhere } from '../learning/assignment-visibility';
import { WRITTEN_KIND } from '../learning/school-learning.schemas';
import { homeworkPhotoKey } from './homework-image';
import { HomeworkPhotoUrlService } from './homework-photo-url.service';
import { HomeworkStorageService } from './homework-storage.service';
import { HomeworkUpload, readHomeworkUpload } from './homework-upload';
import { SubmissionWithPhotos, toChildSubmissionView } from './homework-view';

type StoredPhoto = Pick<SchoolHomeworkPhoto, 'key' | 'contentType' | 'size' | 'position'>;

interface CommitResult {
  submission: SubmissionWithPhotos;
  /** Takroriy so'rov (requestId mos) — yangi yuklangan obyektlar kerak emas. */
  replayed: boolean;
  /** Almashtirilgan eski rasmlar kalitlari. */
  replacedKeys: string[];
}

const assignmentNotFound = () => new NotFoundException({ code: 'ASSIGNMENT_NOT_FOUND', message: 'Written assignment not found' });
const alreadyAccepted = () => new ConflictException({ code: 'ALREADY_ACCEPTED', message: 'Accepted homework cannot be changed' });

@Injectable()
export class HomeworkSubmitService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: HomeworkStorageService,
    private readonly urls: HomeworkPhotoUrlService,
  ) {}

  async submit(childUserId: string, assignmentId: string, req: FastifyRequest) {
    const student = await requireEnrolledStudent(this.prisma, childUserId);
    const assignment = await this.prisma.schoolLearningAssignment.findFirst({
      where: { AND: [childAssignmentWhere(student, tashkentDay()), { id: assignmentId, materialKind: WRITTEN_KIND }] },
      select: { id: true },
    });
    if (!assignment) throw assignmentNotFound();
    const upload = await readHomeworkUpload(req);
    const key = { assignmentId, studentId: student.studentId };

    const earlier = await this.prisma.schoolHomeworkSubmission.findUnique({
      where: { assignmentId_studentId: key },
      include: { photos: true },
    });
    if (earlier && upload.fields.requestId && earlier.requestId === upload.fields.requestId) return this.view(earlier);
    if (earlier?.status === 'ACCEPTED') throw alreadyAccepted();

    const stored = await this.uploadAll(student.schoolId, key, upload);
    let result: CommitResult;
    try {
      result = await this.commit(key, upload, stored);
    } catch (err) {
      await this.storage.deleteKeys(stored.map((p) => p.key));
      throw err;
    }
    await this.storage.deleteKeys(result.replayed ? stored.map((p) => p.key) : result.replacedKeys);
    return this.view(result.submission);
  }

  private async uploadAll(schoolId: string, ids: { assignmentId: string; studentId: string }, upload: HomeworkUpload): Promise<StoredPhoto[]> {
    const stored: StoredPhoto[] = [];
    try {
      for (const [position, photo] of upload.photos.entries()) {
        const key = homeworkPhotoKey({ schoolId, ...ids, uuid: randomUUID(), ext: photo.ext });
        await this.storage.upload(key, photo.buffer, photo.contentType);
        stored.push({ key, contentType: photo.contentType, size: photo.buffer.length, position });
      }
    } catch (err) {
      await this.storage.deleteKeys(stored.map((p) => p.key));
      throw err;
    }
    return stored;
  }

  /** Bitta (topshiriq, o'quvchi) bo'yicha navbat — parallel so'rovlar bir-birini bosib ketmaydi. */
  private commit(ids: { assignmentId: string; studentId: string }, upload: HomeworkUpload, stored: StoredPhoto[]): Promise<CommitResult> {
    const { comment, requestId } = upload.fields;
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended(${`homework:${ids.assignmentId}:${ids.studentId}`}, 0))`;
      const current = await tx.schoolHomeworkSubmission.findUnique({
        where: { assignmentId_studentId: ids },
        include: { photos: true },
      });
      if (current && requestId && current.requestId === requestId) return { submission: current, replayed: true, replacedKeys: [] };
      if (current?.status === 'ACCEPTED') throw alreadyAccepted();
      const data = {
        comment,
        requestId,
        status: 'SUBMITTED' as const,
        submittedAt: new Date(),
        reviewedAt: null,
        reviewedByStaffId: null,
        reviewNote: null,
      } satisfies Prisma.SchoolHomeworkSubmissionUpdateInput;
      if (!current) {
        const created = await tx.schoolHomeworkSubmission.create({
          data: { ...ids, ...data, photos: { create: stored } },
          include: { photos: true },
        });
        return { submission: created, replayed: false, replacedKeys: [] };
      }
      await tx.schoolHomeworkPhoto.deleteMany({ where: { submissionId: current.id } });
      const updated = await tx.schoolHomeworkSubmission.update({
        where: { id: current.id },
        data: { ...data, photos: { create: stored } },
        include: { photos: true },
      });
      return { submission: updated, replayed: false, replacedKeys: current.photos.map((p) => p.key) };
    });
  }

  private view(submission: SubmissionWithPhotos) {
    return toChildSubmissionView(submission, (id) => this.urls.url(id));
  }
}
