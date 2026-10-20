import { roleHas } from '@/auth/permissions';
import { matchesSearch } from '@/lib/normalize-search';
import { allowedClassIds, currentActor } from '../context';
import { getTables } from '../db';
import { buildIndexes, studentName } from '../lookups';

export type SearchResults = {
  students: Array<{ id: string; name: string; className: string; studentCode: string }>;
  classes: Array<{ id: string; name: string }>;
  staff: Array<{ id: string; name: string; position: string }>;
};

/** Global qidiruv (⌘K) — rol doirasida. */
export const searchService = {
  query(q: string, limit = 6): SearchResults {
    const actor = currentActor();
    const empty: SearchResults = { students: [], classes: [], staff: [] };
    if (q.trim().length < 2) return empty;
    const t = getTables();
    const idx = buildIndexes(t);
    const allowed = allowedClassIds(actor);
    const students = roleHas(actor.role, 'students.view')
      ? t.students
          .filter((s) => !s.archived && (!allowed || allowed.includes(s.classId)))
          .filter((s) => matchesSearch(`${studentName(s)} ${s.studentCode}`, q))
          .slice(0, limit)
          .map((s) => ({ id: s.id, name: studentName(s), className: idx.classes.get(s.classId)?.name ?? '', studentCode: s.studentCode }))
      : [];
    const classes = roleHas(actor.role, 'classes.view')
      ? t.classes
          .filter((c) => (!allowed || allowed.includes(c.id)) && matchesSearch(c.name, q))
          .slice(0, limit)
          .map((c) => ({ id: c.id, name: c.name }))
      : [];
    const staff = roleHas(actor.role, 'staff.view')
      ? t.staff
          .filter((s) => matchesSearch(`${s.fullName} ${s.position}`, q))
          .slice(0, limit)
          .map((s) => ({ id: s.id, name: s.fullName, position: s.position }))
      : [];
    return { students, classes, staff };
  },
};
