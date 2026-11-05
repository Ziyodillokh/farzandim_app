// Topshiriq ko'rinishlari: bola va xodim uchun (rasmlar imzolangan havola bilan).

import { SchoolHomeworkPhoto, SchoolHomeworkStatus, SchoolHomeworkSubmission } from '@prisma/client';

export type SubmissionWithPhotos = SchoolHomeworkSubmission & { photos: SchoolHomeworkPhoto[] };
export type PhotoUrl = (photoId: string) => string;

export function toPhotoViews(photos: readonly SchoolHomeworkPhoto[], urlOf: PhotoUrl) {
  return [...photos]
    .sort((a, b) => a.position - b.position)
    .map((p) => ({ id: p.id, url: urlOf(p.id), contentType: p.contentType, size: p.size, position: p.position }));
}

/** Bola ko'radigan topshiriq (xodim identifikatorisiz). */
export function toChildSubmissionView(s: SubmissionWithPhotos, urlOf: PhotoUrl) {
  return {
    id: s.id,
    assignmentId: s.assignmentId,
    status: s.status,
    comment: s.comment,
    submittedAt: s.submittedAt.toISOString(),
    reviewedAt: s.reviewedAt?.toISOString() ?? null,
    reviewNote: s.reviewNote,
    photos: toPhotoViews(s.photos, urlOf),
  };
}

export function toStaffSubmissionView(s: SubmissionWithPhotos, urlOf: PhotoUrl) {
  return { ...toChildSubmissionView(s, urlOf), reviewedByStaffId: s.reviewedByStaffId };
}

/** Bola ro'yxatidagi qisqa holat (rasm havolalarisiz). */
export function toSubmissionSummary(s: SchoolHomeworkSubmission, photoCount: number) {
  return {
    status: s.status,
    submittedAt: s.submittedAt.toISOString(),
    reviewedAt: s.reviewedAt?.toISOString() ?? null,
    reviewNote: s.reviewNote,
    photoCount,
  };
}

/** Holatlar bo'yicha hisob; `null` — topshirmagan. */
export function countStatuses(statuses: readonly (SchoolHomeworkStatus | null)[]) {
  const count = (status: SchoolHomeworkStatus | null) => statuses.filter((s) => s === status).length;
  return {
    total: statuses.length,
    submitted: count('SUBMITTED'),
    accepted: count('ACCEPTED'),
    returned: count('RETURNED'),
    missing: count(null),
  };
}
