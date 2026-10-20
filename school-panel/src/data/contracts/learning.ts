import type { Id, IsoDate, IsoDateTime } from './common';

export type MaterialKind = 'AUDIOBOOK' | 'VIDEO' | 'TEST';
export type Subject =
  | 'MATH'
  | 'ENGLISH'
  | 'HISTORY'
  | 'LITERATURE'
  | 'GEOGRAPHY'
  | 'BIOLOGY'
  | 'IT'
  | 'NATIVE'
  | 'PHYSICS'
  | 'CHEMISTRY'
  | 'RUSSIAN';

export type LearningMaterial = {
  id: Id;
  kind: MaterialKind;
  title: string;
  subject: Subject;
  grades: number[];
  durationMin: number;
  questions: number; // test bo'lsa
};

export type LearningAssignment = {
  id: Id;
  materialId: Id;
  classIds: Id[];
  dueDate: IsoDate;
  note: string;
  createdAt: IsoDateTime;
  byStaffId: Id;
};

export type ClassActivity = {
  classId: Id;
  weekStart: IsoDate;
  activeStudents: number;
  completedTasks: number;
  avgScore: number; // 0..100
  donPoints: number;
};
