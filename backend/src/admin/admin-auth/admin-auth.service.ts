import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../common/database/prisma.service';
import { AdminAuditService } from '../../common/audit/admin-audit.service';
import { AdminJwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { EnvConfig } from '../../common/config/env.schema';
import { hashPassword, verifyPassword } from './helpers/password';
import {
  findMatchingBackupCode,
  generateBackupCodes,
  generateSecret,
  hashBackupCodes,
  signChallenge,
  verifyChallenge,
  verifyTotpCode,
} from './helpers/two-factor';
import { LoginDto } from './dto/login.dto';
import { Verify2faDto } from './dto/verify-2fa.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { Enable2faDto } from './dto/enable-2fa.dto';
import { Disable2faDto } from './dto/disable-2fa.dto';

interface RequestMeta {
  ip?: string;
  headers?: Record<string, string | string[] | undefined>;
  cookies?: Record<string, string>;
}

@Injectable()
export class AdminAuthService {
  private readonly accessSecret: string;
  private readonly refreshSecret: string;
  private readonly accessExpires: string;
  private readonly refreshExpires: string;
  private readonly challengeSecret: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly audit: AdminAuditService,
  ) {
    this.accessSecret = this.config.get('ADMIN_JWT_ACCESS_SECRET', { infer: true });
    this.refreshSecret = this.config.get('ADMIN_JWT_REFRESH_SECRET', { infer: true });
    this.accessExpires = this.config.get('ADMIN_JWT_ACCESS_EXPIRES', { infer: true });
    this.refreshExpires = this.config.get('ADMIN_JWT_REFRESH_EXPIRES', { infer: true });
    this.challengeSecret = this.accessSecret + ':2fa-challenge';
  }

  private signAccessToken(claims: AdminJwtPayload): string {
    return this.jwtService.sign({ ...claims }, {
      secret: this.accessSecret,
      expiresIn: this.accessExpires as any,
      audience: 'admin-panel',
      issuer: 'farzandim-backend',
    });
  }

  private signRefreshToken(claims: AdminJwtPayload): string {
    return this.jwtService.sign({ ...claims }, {
      secret: this.refreshSecret,
      expiresIn: this.refreshExpires as any,
      audience: 'admin-panel',
      issuer: 'farzandim-backend',
    });
  }

  private verifyRefreshToken(token: string): AdminJwtPayload {
    return this.jwtService.verify(token, {
      secret: this.refreshSecret,
      audience: 'admin-panel',
      issuer: 'farzandim-backend',
    });
  }

  private profileOf(staff: {
    id: string;
    email: string;
    name: string;
    phone: string | null;
    moderatorRoleKey: string;
    permissions: string[];
    status: string;
    lastActivityAt: Date | null;
    twoFactorEnabled: boolean;
  }) {
    const isFullAccess = staff.moderatorRoleKey === 'super_admin';
    return {
      id: staff.id,
      email: staff.email,
      name: staff.name,
      phone: staff.phone,
      role: staff.moderatorRoleKey,
      moderatorRoleKey: staff.moderatorRoleKey,
      permissions: isFullAccess ? [] : staff.permissions,
      isFullAccess,
      status: staff.status,
      lastActivityAt: staff.lastActivityAt?.toISOString() ?? null,
      twoFactorEnabled: staff.twoFactorEnabled,
    };
  }

  async login(dto: LoginDto, req: RequestMeta) {
    const staff = await this.prisma.moderator.findUnique({
      where: { email: dto.email },
    });

    if (!staff) {
      void this.audit.log(req, {
        action: 'auth.login.failure',
        email: dto.email,
        status: 'failure',
        details: { reason: 'unknown_email' },
      });
      throw new UnauthorizedException('Invalid email or password');
    }

    if (staff.status === 'blocked') {
      void this.audit.log(req, {
        action: 'auth.login.failure',
        moderatorId: staff.id,
        email: dto.email,
        status: 'failure',
        details: { reason: 'blocked' },
      });
      throw new ForbiddenException('Account blocked');
    }

    const ok = await verifyPassword(dto.password, staff.passwordHash);
    if (!ok) {
      void this.audit.log(req, {
        action: 'auth.login.failure',
        moderatorId: staff.id,
        email: dto.email,
        status: 'failure',
        details: { reason: 'wrong_password' },
      });
      throw new UnauthorizedException('Invalid email or password');
    }

    // 2FA challenge flow
    if (staff.twoFactorEnabled) {
      const challengeId = signChallenge(staff.id, this.challengeSecret);
      void this.audit.log(req, {
        action: 'auth.login.2fa_required',
        moderatorId: staff.id,
        email: dto.email,
      });
      return {
        requires2fa: true,
        challengeId,
        maskedPhone: '',
      };
    }

    const updated = await this.prisma.moderator.update({
      where: { id: staff.id },
      data: { lastActivityAt: new Date() },
    });

    const claims: AdminJwtPayload = {
      sub: updated.id,
      email: updated.email,
      role: updated.moderatorRoleKey,
      tokenVersion: updated.tokenVersion,
    };

    void this.audit.log(req, {
      action: 'auth.login.success',
      moderatorId: updated.id,
      email: updated.email,
    });

    return {
      access_token: this.signAccessToken(claims),
      accessToken: this.signAccessToken(claims),
      refresh_token: this.signRefreshToken(claims),
      refreshToken: this.signRefreshToken(claims),
      user: this.profileOf(updated),
    };
  }

  async verify2fa(dto: Verify2faDto, req: RequestMeta) {
    const challenge = verifyChallenge(dto.challengeId, this.challengeSecret);
    if (!challenge) {
      throw new UnauthorizedException('Challenge expired or invalid');
    }

    const staff = await this.prisma.moderator.findUnique({
      where: { id: challenge.sub },
    });
    if (
      !staff ||
      staff.status === 'blocked' ||
      !staff.twoFactorEnabled ||
      !staff.twoFactorSecret
    ) {
      throw new UnauthorizedException('Session invalid');
    }

    let codeOk = verifyTotpCode(dto.code, staff.twoFactorSecret);
    let usedBackupIndex = -1;
    if (!codeOk) {
      usedBackupIndex = await findMatchingBackupCode(
        dto.code,
        staff.twoFactorBackupCodes,
      );
      if (usedBackupIndex >= 0) codeOk = true;
    }

    if (!codeOk) {
      void this.audit.log(req, {
        action: 'auth.2fa.verify.failure',
        moderatorId: staff.id,
        email: staff.email,
        status: 'failure',
      });
      throw new UnauthorizedException('Invalid 2FA code');
    }

    const nextBackupCodes =
      usedBackupIndex >= 0
        ? staff.twoFactorBackupCodes.filter((_, i) => i !== usedBackupIndex)
        : staff.twoFactorBackupCodes;

    const updated = await this.prisma.moderator.update({
      where: { id: staff.id },
      data: {
        lastActivityAt: new Date(),
        twoFactorBackupCodes: nextBackupCodes,
      },
    });

    const claims: AdminJwtPayload = {
      sub: updated.id,
      email: updated.email,
      role: updated.moderatorRoleKey,
      tokenVersion: updated.tokenVersion,
    };

    void this.audit.log(req, {
      action:
        usedBackupIndex >= 0
          ? 'auth.2fa.verify.backup_code'
          : 'auth.2fa.verify.success',
      moderatorId: updated.id,
      email: updated.email,
      details: { remainingBackupCodes: nextBackupCodes.length },
    });

    return {
      access_token: this.signAccessToken(claims),
      accessToken: this.signAccessToken(claims),
      refresh_token: this.signRefreshToken(claims),
      refreshToken: this.signRefreshToken(claims),
      user: this.profileOf(updated),
      usedBackupCode: usedBackupIndex >= 0,
      remainingBackupCodes: nextBackupCodes.length,
    };
  }

  async get2faStatus(staffId: string) {
    const staff = await this.prisma.moderator.findUnique({
      where: { id: staffId },
    });
    if (!staff) throw new NotFoundException('Staff not found');
    return {
      enabled: staff.twoFactorEnabled,
      enabledAt: staff.twoFactorEnabledAt?.toISOString() ?? null,
      remainingBackupCodes: staff.twoFactorBackupCodes.length,
    };
  }

  async setup2fa(staffId: string) {
    const staff = await this.prisma.moderator.findUnique({
      where: { id: staffId },
    });
    if (!staff) throw new NotFoundException('Staff not found');
    if (staff.twoFactorEnabled) {
      throw new ConflictException('2FA already enabled. Disable first.');
    }

    const { secret, otpauthUri } = generateSecret(staff.email);

    await this.prisma.moderator.update({
      where: { id: staff.id },
      data: { twoFactorSecret: secret },
    });

    return {
      secret,
      otpauthUri,
      qrInstruction:
        "Authenticator app (Google Authenticator, Authy, 1Password) da QR code skanlang yoki secret ni qo'lda kiriting.",
    };
  }

  async enable2fa(staffId: string, dto: Enable2faDto, req: RequestMeta) {
    const staff = await this.prisma.moderator.findUnique({
      where: { id: staffId },
    });
    if (!staff) throw new NotFoundException('Staff not found');
    if (staff.twoFactorEnabled) {
      throw new ConflictException('2FA already enabled');
    }
    if (!staff.twoFactorSecret) {
      throw new BadRequestException('Run /2fa/setup first');
    }

    if (!verifyTotpCode(dto.code, staff.twoFactorSecret)) {
      throw new UnauthorizedException('Invalid verification code');
    }

    const plaintextBackupCodes = generateBackupCodes(8);
    const hashedBackupCodes = await hashBackupCodes(plaintextBackupCodes);

    await this.prisma.moderator.update({
      where: { id: staff.id },
      data: {
        twoFactorEnabled: true,
        twoFactorEnabledAt: new Date(),
        twoFactorBackupCodes: hashedBackupCodes,
      },
    });

    void this.audit.log(req, {
      action: 'auth.2fa.enable',
      moderatorId: staff.id,
      email: staff.email,
    });

    return {
      enabled: true,
      backupCodes: plaintextBackupCodes,
      warning:
        "Backup kodlarni xavfsiz joyga saqlang. Bular faqat hozir ko'rsatiladi.",
    };
  }

  async disable2fa(staffId: string, dto: Disable2faDto, req: RequestMeta) {
    const staff = await this.prisma.moderator.findUnique({
      where: { id: staffId },
    });
    if (!staff) throw new NotFoundException('Staff not found');

    const passwordOk = await verifyPassword(dto.password, staff.passwordHash);
    if (!passwordOk) throw new UnauthorizedException('Invalid password');

    if (staff.twoFactorEnabled && staff.twoFactorSecret) {
      if (!dto.code) {
        throw new BadRequestException('TOTP code required to disable 2FA');
      }
      let codeOk = verifyTotpCode(dto.code, staff.twoFactorSecret);
      if (!codeOk) {
        const backupIdx = await findMatchingBackupCode(
          dto.code,
          staff.twoFactorBackupCodes,
        );
        if (backupIdx >= 0) codeOk = true;
      }
      if (!codeOk) throw new UnauthorizedException('Invalid 2FA code');
    }

    await this.prisma.moderator.update({
      where: { id: staff.id },
      data: {
        twoFactorEnabled: false,
        twoFactorSecret: null,
        twoFactorEnabledAt: null,
        twoFactorBackupCodes: [],
      },
    });

    void this.audit.log(req, {
      action: 'auth.2fa.disable',
      moderatorId: staff.id,
      email: staff.email,
    });

    return { disabled: true };
  }

  async refresh(refreshToken: string | undefined, cookieToken: string | undefined) {
    const token = cookieToken ?? refreshToken;
    if (!token) throw new BadRequestException('Missing refresh token');

    let payload: AdminJwtPayload;
    try {
      payload = this.verifyRefreshToken(token);
    } catch {
      throw new UnauthorizedException('Refresh token expired or invalid');
    }

    const staff = await this.prisma.moderator.findUnique({
      where: { id: payload.sub },
    });
    if (!staff || staff.status === 'blocked') {
      throw new UnauthorizedException('Session invalid');
    }
    if ((payload.tokenVersion ?? 0) !== staff.tokenVersion) {
      throw new UnauthorizedException('Token revoked');
    }

    const claims: AdminJwtPayload = {
      sub: staff.id,
      email: staff.email,
      role: staff.moderatorRoleKey,
      tokenVersion: staff.tokenVersion,
    };

    return {
      access_token: this.signAccessToken(claims),
      accessToken: this.signAccessToken(claims),
    };
  }

  async getProfile(staffId: string) {
    const staff = await this.prisma.moderator.findUnique({
      where: { id: staffId },
    });
    if (!staff) throw new NotFoundException('Staff not found');
    return this.profileOf(staff);
  }

  async changePassword(
    staffId: string,
    dto: ChangePasswordDto,
    req: RequestMeta,
  ) {
    const staff = await this.prisma.moderator.findUnique({
      where: { id: staffId },
    });
    if (!staff) throw new NotFoundException('Staff not found');

    const ok = await verifyPassword(dto.currentPassword, staff.passwordHash);
    if (!ok) throw new UnauthorizedException('Current password is incorrect');

    await this.prisma.moderator.update({
      where: { id: staffId },
      data: { passwordHash: await hashPassword(dto.newPassword) },
    });

    void this.audit.log(req, {
      action: 'auth.change_password',
      moderatorId: staffId,
      email: staff.email,
    });

    return { ok: true };
  }

  async logout(staffId: string, req: RequestMeta) {
    await this.prisma.moderator.update({
      where: { id: staffId },
      data: { tokenVersion: { increment: 1 } },
    });

    void this.audit.log(req, {
      action: 'auth.logout',
      moderatorId: staffId,
    });

    return { ok: true };
  }
}
