// Admin → Maktablar: platforma admini yangi maktab va uning direktorini
// yaratadi, himoyalangan rol (psixolog) hisobini beradi va direktor /
// psixolog parolini tiklaydi. Qolgan xodimlar, sinflar va o'quvchilarni
// direktor panelda o'zi qo'shadi.
//
// Vaqtinchalik parol serverda yaratiladi va faqat javobda BIR MARTA qaytadi
// (birinchi kirishda almashtiriladi); audit yozuvlarida parol yo'q. Har amal
// ikki jurnalga yoziladi: admin audit (kim qildi) va maktab audit jurnali
// ("Parvoz admin" — direktor panelda ko'radi).

import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AdminAuditService } from '../../common/audit/admin-audit.service';
import { PrismaService } from '../../common/database/prisma.service';
import { hashStaffPassword } from '../../school/auth/school-auth.service';
import { SchoolAuditService } from '../../school/common/school-audit.service';
import { insertSchoolWithDirector } from '../../school/common/school-bootstrap';
import { generateTempPassword } from '../../school/common/temp-password';
import {
  addStaffSchema,
  createSchoolSchema,
  defaultPosition,
  isAdminManagedRole,
  listSchoolsSchema,
  parseAdminInput,
  resetPasswordSchema,
} from './admin-schools.input';
import {
  ACCOUNT_SELECT,
  AdminCredentialsView,
  AdminSchoolView,
  SCHOOL_SELECT,
  toAccountView,
  toSchoolView,
} from './admin-schools.views';

/** Maktab audit jurnalida ko'rinadigan muallif. */
export const ADMIN_ACTOR = 'Parvoz admin';

export interface AdminActor {
  id: string;
  email?: string;
}

type Req = { ip?: string; headers?: Record<string, string | string[] | undefined> };
type Tx = Prisma.TransactionClient;

const isUniqueViolation = (e: unknown) =>
  e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002';

const schoolNotFound = () => new NotFoundException({ code: 'NOT_FOUND', message: 'Maktab topilmadi' });
const staffNotFound = () => new NotFoundException({ code: 'NOT_FOUND', message: 'Xodim topilmadi' });
const codeTaken = (code: string) =>
  new ConflictException({ code: 'SCHOOL_CODE_TAKEN', message: `«${code}» kodli maktab allaqachon bor` });
const usernameTaken = (username: string) =>
  new ConflictException({ code: 'USERNAME_TAKEN', message: `«${username}» logini bu maktabda band` });

@Injectable()
export class AdminSchoolsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AdminAuditService,
    private readonly schoolAudit: SchoolAuditService,
  ) {}

  async list(query: unknown) {
    const { q, page, limit } = parseAdminInput(listSchoolsSchema, query);
    const where: Prisma.SchoolWhereInput = q
      ? {
          OR: [
            { name: { contains: q, mode: 'insensitive' } },
            { code: { contains: q.toLowerCase() } },
            { city: { contains: q, mode: 'insensitive' } },
          ],
        }
      : {};
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.school.count({ where }),
      this.prisma.school.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: SCHOOL_SELECT,
      }),
    ]);
    const now = new Date();
    return {
      items: rows.map((row) => toSchoolView(row, now)),
      pagination: { page, limit, total, totalPages: Math.max(1, Math.ceil(total / limit)) },
    };
  }

  async get(id: string): Promise<AdminSchoolView> {
    const row = await this.prisma.school.findUnique({ where: { id }, select: SCHOOL_SELECT });
    if (!row) throw schoolNotFound();
    return toSchoolView(row);
  }

  /** Maktab + standart smena + direktor hisobi. */
  async create(input: unknown, admin: AdminActor, req: Req) {
    const data = parseAdminInput(createSchoolSchema, input);
    if (await this.prisma.school.findUnique({ where: { code: data.code }, select: { id: true } })) {
      throw codeTaken(data.code);
    }
    const temporaryPassword = generateTempPassword();
    const passwordHash = await hashStaffPassword(temporaryPassword);
    const { school, director } = await this.prisma
      .$transaction(async (tx) => {
        const created = await insertSchoolWithDirector(tx, data, passwordHash);
        await this.schoolAudit.writeExternal(
          created.school.id,
          ADMIN_ACTOR,
          {
            module: 'SCHOOL',
            action: 'school.create',
            summary: `Maktab ochildi: ${created.school.name} (${created.school.code}); direktor — ${created.director.fullName} (${created.director.username})`,
            entityId: created.school.id,
            params: { name: created.school.name, code: created.school.code },
          },
          tx,
        );
        return created;
      })
      .catch((e: unknown) => {
        // Parallel so'rov bir xil kod bilan — 500 emas, 409.
        throw isUniqueViolation(e) ? codeTaken(data.code) : e;
      });
    void this.audit.log(req, {
      action: 'school.create',
      moderatorId: admin.id,
      email: admin.email,
      resourceType: 'school',
      resourceId: school.id,
      details: { code: school.code, name: school.name, director: director.username },
    });
    const view = await this.get(school.id);
    return { school: view, credentials: this.credentials(view.code, director.id, temporaryPassword, view) };
  }

  /** Direktor yoki himoyalangan rol (psixolog) hisobi. */
  async addStaff(schoolId: string, input: unknown, admin: AdminActor, req: Req): Promise<AdminCredentialsView> {
    const data = parseAdminInput(addStaffSchema, input);
    const school = await this.findSchool(schoolId);
    const temporaryPassword = generateTempPassword();
    const passwordHash = await hashStaffPassword(temporaryPassword);
    const staff = await this.prisma
      .$transaction(async (tx) => {
        await this.assertUsernameFree(tx, school.id, data.username);
        const created = await tx.schoolStaff.create({
          data: {
            schoolId: school.id,
            fullName: data.fullName,
            position: data.position ?? defaultPosition(data.role),
            role: data.role,
            username: data.username,
            passwordHash,
            mustChangePassword: true,
          },
          select: ACCOUNT_SELECT,
        });
        await this.writeAccountAudit(tx, school.id, 'staff.accountCreate', created, false);
        return created;
      })
      .catch((e: unknown) => {
        throw isUniqueViolation(e) ? usernameTaken(data.username) : e;
      });
    void this.audit.log(req, {
      action: 'school.staff.create',
      moderatorId: admin.id,
      email: admin.email,
      resourceType: 'school_staff',
      resourceId: staff.id,
      details: { school: school.code, role: staff.role, username: staff.username },
    });
    return { schoolCode: school.code, username: data.username, temporaryPassword, account: toAccountView(staff) };
  }

  /**
   * Direktor / psixolog parolini tiklash: yangi vaqtinchalik parol, blok
   * ochiladi, barcha sessiyalar yopiladi; ixtiyoriy — 2FA o'chiriladi.
   * Login yo'q bo'lsa (direktor hisobni o'chirgan) — `username` beriladi.
   */
  async resetPassword(
    schoolId: string,
    staffId: string,
    input: unknown,
    admin: AdminActor,
    req: Req,
  ): Promise<AdminCredentialsView> {
    const { resetTotp, username: newUsername } = parseAdminInput(resetPasswordSchema, input);
    const school = await this.findSchool(schoolId);
    const temporaryPassword = generateTempPassword();
    const passwordHash = await hashStaffPassword(temporaryPassword);
    const staff = await this.prisma
      .$transaction(async (tx) => {
        const target = await tx.schoolStaff.findFirst({ where: { id: staffId, schoolId: school.id } });
        if (!target) throw staffNotFound();
        if (!isAdminManagedRole(target.role)) {
          throw new ConflictException({
            code: 'MANAGED_BY_SCHOOL',
            message: "Bu xodimning hisobini maktab direktori panelda o'zi boshqaradi",
          });
        }
        const username = target.username ?? newUsername;
        if (!username) {
          throw new ConflictException({
            code: 'USERNAME_REQUIRED',
            message: "Xodimning panel logini yo'q — yangi login kiriting",
          });
        }
        if (!target.username) await this.assertUsernameFree(tx, school.id, username);
        const updated = await tx.schoolStaff.update({
          where: { id: target.id },
          data: {
            username,
            passwordHash,
            mustChangePassword: true,
            failedLogins: 0,
            lockedUntil: null,
            tokenVersion: { increment: 1 },
            ...(resetTotp && { totpEnabled: false, totpSecret: null }),
          },
          select: ACCOUNT_SELECT,
        });
        await tx.schoolStaffSession.updateMany({
          where: { staffId: target.id, revokedAt: null },
          data: { revokedAt: new Date() },
        });
        await this.writeAccountAudit(tx, school.id, 'staff.accountReset', updated, resetTotp);
        return updated;
      })
      .catch((e: unknown) => {
        throw isUniqueViolation(e) ? usernameTaken(newUsername ?? '') : e;
      });
    void this.audit.log(req, {
      action: 'school.staff.resetPassword',
      moderatorId: admin.id,
      email: admin.email,
      resourceType: 'school_staff',
      resourceId: staff.id,
      details: { school: school.code, role: staff.role, username: staff.username, resetTotp },
    });
    return {
      schoolCode: school.code,
      username: staff.username ?? '',
      temporaryPassword,
      account: toAccountView(staff),
    };
  }

  private async findSchool(id: string) {
    const school = await this.prisma.school.findUnique({ where: { id }, select: { id: true, code: true } });
    if (!school) throw schoolNotFound();
    return school;
  }

  private async assertUsernameFree(tx: Tx, schoolId: string, username: string): Promise<void> {
    const taken = await tx.schoolStaff.findUnique({
      where: { schoolId_username: { schoolId, username } },
      select: { id: true },
    });
    if (taken) throw usernameTaken(username);
  }

  private writeAccountAudit(
    tx: Tx,
    schoolId: string,
    action: 'staff.accountCreate' | 'staff.accountReset',
    staff: { id: string; fullName: string; username: string | null },
    resetTotp: boolean,
  ): Promise<void> {
    const username = staff.username ?? '';
    return this.schoolAudit.writeExternal(
      schoolId,
      ADMIN_ACTOR,
      {
        module: 'STAFF',
        action,
        summary: `Panel hisobi: ${staff.fullName} (${username}) — Parvoz admin${resetTotp ? ", 2FA o'chirildi" : ''}`,
        entityId: staff.id,
        params: { name: staff.fullName, username },
      },
      tx,
    );
  }

  private credentials(
    schoolCode: string,
    staffId: string,
    temporaryPassword: string,
    view: AdminSchoolView,
  ): AdminCredentialsView {
    const account = view.accounts.find((a) => a.id === staffId);
    if (!account?.username) throw staffNotFound();
    return { schoolCode, username: account.username, temporaryPassword, account };
  }
}
