import {
  Injectable,
  Logger,
  ForbiddenException,
  NotFoundException,
  ConflictException,
  BadRequestException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { GamificationService } from '../gamification/gamification.service';
import { XpEventType } from '../gamification/dto/create-xp-event.dto';
import { RANKING_REGION_ME } from './dto/ranking-query.dto';

// Javob vaqti chegarasi grace (sekund) — answerQuestion VA submitAttempt
// AYNI shu qiymatdan foydalanadi (ikki endpoint bir xil vaqt xulqi).
const GRACE_SEC = 30;

/** Sertifikat (#56) uchun minimal natija foizi — bundan past bo'lsa berilmaydi. */
const CERT_THRESHOLD_PERCENT = 80;

/** Mukofot uchun minimal natija foizi — bundan past bo'lsa DON/XP berilmaydi. */
const REWARD_THRESHOLD_PERCENT = 30;

/**
 * Test mukofoti (DON = XP) — to'g'ri javoblarga PROPORSIONAL.
 *
 * `pool` — testga ajratilgan to'liq mukofot (`Olympiad.xpReward`; admin
 * panelda "DON mukofoti"). Har bir savol shu fonddan teng ulush oladi:
 *
 *   natija < 30%  → 0 (mukofot yo'q)
 *   natija >= 30% → to'g'ri javoblar × (pool / jami savollar)
 *
 * Masalan 20 talik testga 20 DON ajratilgan: 8 ta topgan bola 8 DON, 20 ta
 * topgan 20 DON, 5 ta topgan (25%) esa 0 DON oladi.
 *
 * `correct <= total` bo'lgani uchun natija hech qachon `pool` dan oshmaydi.
 */
export function rewardFor(
  pool: number,
  correct: number,
  total: number,
): number {
  if (pool <= 0 || total <= 0 || correct <= 0) return 0;
  const percent = (correct / total) * 100;
  if (percent < REWARD_THRESHOLD_PERCENT) return 0;
  return Math.round(correct * (pool / total));
}

function lifecycleOf(o: {
  status: string;
  startTime: Date;
  endTime: Date;
}): string {
  if (o.status !== 'published') return o.status;
  const now = Date.now();
  if (o.endTime.getTime() < now) return 'finished';
  if (o.startTime.getTime() > now) return 'scheduled';
  return 'active';
}

function olympiadRow(o: {
  id: string;
  title: string;
  description: string | null;
  coverKey: string | null;
  subject: string;
  ageFrom: number;
  ageTo: number;
  type: string;
  difficulty: string;
  startTime: Date;
  endTime: Date;
  durationMin: number;
  xpReward: number;
  status: string;
  createdAt: Date;
  _count?: { attempts: number; questions: number };
}) {
  return {
    id: o.id,
    title: o.title,
    description: o.description,
    coverKey: o.coverKey ?? null,
    subject: o.subject,
    ageFrom: o.ageFrom,
    ageTo: o.ageTo,
    type: o.type,
    difficulty: o.difficulty,
    startTime: o.startTime.toISOString(),
    endTime: o.endTime.toISOString(),
    durationMin: o.durationMin,
    xpReward: o.xpReward,
    status: o.status,
    lifecycle: lifecycleOf(o),
    participantCount: o._count?.attempts ?? 0,
    questionCount: o._count?.questions ?? 0,
    createdAt: o.createdAt.toISOString(),
  };
}

function questionRow(q: {
  id: string;
  text: string;
  options: string[];
  optionImages?: string[];
  points: number;
  orderIdx: number;
  imageKey?: string | null;
}) {
  return {
    id: q.id,
    text: q.text,
    options: q.options,
    // Variant rasmlari (kalitlar) — `options` bilan parallel; child URL quradi.
    optionImages: q.optionImages ?? [],
    points: q.points,
    orderIdx: q.orderIdx,
    imageKey: q.imageKey ?? null,
  };
}

@Injectable()
export class ConsumerOlympiadsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gamification: GamificationService,
  ) {}

  private readonly logger = new Logger(ConsumerOlympiadsService.name);

  /// Test (olympiad) tugatilganda XP + DON beradi. Idempotent
  /// (relatedId=attemptId). Xato submit/answer javobini buzmasligi uchun
  /// try/catch (faqat log).
  ///
  /// MUKOFOT NATIJAGA BOG'LIQ:
  ///   - natija < 30%  → mukofot YO'Q (0 DON, 0 XP)
  ///   - natija >= 30% → har bir to'g'ri javob uchun ulush:
  ///       don = to'g'ri javoblar × (olympiad.xpReward / jami savollar)
  ///     Masalan 20 talik testga 20 DON ajratilgan bo'lsa, 8 ta topgan bola
  ///     8 DON oladi.
  ///
  /// `olympiad.xpReward` — testga ajratilgan TO'LIQ fond (admin panelda
  /// "DON mukofoti" deb yozilgan, bola kartasida "N DON gacha" ko'rinadi).
  ///
  /// Avval mukofot natijadan QAT'I NAZAR to'liq berilardi — bola bitta ham
  /// topmasa ham butun fondni olardi.
  private async grantOlympiadXp(
    childId: string,
    attemptId: string,
    xpReward: number,
    correctAnswers: number,
    questionsTotal: number,
  ): Promise<void> {
    const reward = rewardFor(xpReward, correctAnswers, questionsTotal);
    // Hech nima berilmasa XpEvent ham yaratmaymiz — reytingdagi davrli
    // hisob (donDelta yig'indisi) bo'sh yozuvlar bilan to'lmasin.
    if (reward <= 0) return;
    try {
      await this.gamification.awardXp(childId, {
        type: XpEventType.CONTEST_WIN,
        xpDelta: reward,
        donDelta: reward,
        relatedId: attemptId,
      });
    } catch (e) {
      this.logger.error(
        `awardXp muvaffaqiyatsiz (attempt ${attemptId})`,
        e as Error,
      );
    }
  }

  private async loadChild(
    userId: string,
  ): Promise<{ childId: string; age: number | null; region: string | null }> {
    const u = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { childRecord: true },
    });
    if (!u || u.role !== 'CHILD' || !u.childRecord) {
      throw new ForbiddenException('Child profile required');
    }
    // `region` — reytingdagi "o'z viloyatim" filtri uchun (`region=me`).
    return {
      childId: u.childRecord.id,
      age: u.childRecord.age,
      region: u.childRecord.region,
    };
  }

  async listOlympiads(userId: string) {
    const child = await this.loadChild(userId);
    const a = child.age ?? 8;

    const where: Prisma.OlympiadWhereInput = {
      status: 'published',
      ageFrom: { lte: a },
      ageTo: { gte: a },
    };

    const rows = await this.prisma.olympiad.findMany({
      where,
      include: { _count: { select: { attempts: true, questions: true } } },
      orderBy: [{ startTime: 'desc' }],
      take: 100,
    });

    return { items: rows.map(olympiadRow) };
  }

  async getOlympiadDetail(userId: string, id: string) {
    await this.loadChild(userId);

    const o = await this.prisma.olympiad.findUnique({
      where: { id },
      include: {
        _count: { select: { attempts: true, questions: true } },
        questions: { orderBy: [{ orderIdx: 'asc' }] },
      },
    });
    if (!o || o.status !== 'published') {
      throw new NotFoundException('Olympiad not found');
    }

    return {
      ...olympiadRow(o),
      questions: o.questions.map(questionRow),
    };
  }

  async startAttempt(userId: string, olympiadId: string) {
    const child = await this.loadChild(userId);

    const olympiad = await this.prisma.olympiad.findUnique({
      where: { id: olympiadId },
      include: { _count: { select: { questions: true } } },
    });
    if (!olympiad || olympiad.status !== 'published') {
      throw new NotFoundException('Olympiad not found');
    }

    // Lifecycle nazorati: FAQAT faol oynada boshlash mumkin. Avval tekshirilmasdi
    // — kelajakdagi (scheduled, startTime > now) yoki tugagan (finished, endTime
    // < now) konkursni ham boshlash mumkin edi.
    if (lifecycleOf(olympiad) !== 'active') {
      throw new ForbiddenException('Konkurs hozir faol emas');
    }

    // Konkursda ISHTIROK bonusi (30 XP / 5 DON) — BIR olympiad uchun bir marta
    // (idempotent, relatedId=olympiadId). Avval bu bonus BOLA ilovasida
    // Firestore'ga yozilardi (o'lik oqim: dashboard ko'rmasdi, ilova qayta
    // o'rnatilganda yo'qolardi). Endi backend beradi → ChildProfile.donBalance
    // (childId bo'yicha saqlanadi, reinstall'da ham turadi).
    try {
      await this.gamification.awardXp(child.childId, {
        type: XpEventType.CONTEST_JOIN,
        xpDelta: 30,
        donDelta: 5,
        relatedId: olympiadId,
      });
    } catch (e) {
      this.logger.error('contest join bonus failed', e as Error);
    }

    // Check existing attempt (unique constraint: olympiadId + childId)
    const existing = await this.prisma.olympiadAttempt.findUnique({
      where: {
        olympiadId_childId: { olympiadId, childId: child.childId },
      },
    });
    if (existing) {
      // Testlar QAYTA yechilishi mumkin (praktika): tugagan urinishni
      // xato bilan bloklamaymiz (avval 409 berib "hammasi xato" ko'rinardi —
      // bola qayta yechganda attemptId olmasdi). Tugagan urinishni TOZALAB
      // (score/answers reset) qaytadan boshlaymiz. Davom etayotgani resume.
      if (existing.status === 'finished') {
        const reset = await this.prisma.olympiadAttempt.update({
          where: { id: existing.id },
          data: {
            status: 'in_progress',
            score: 0,
            correctAnswers: 0,
            timeSec: 0,
            answers: [],
            finishedAt: null,
            startedAt: new Date(),
          },
        });
        return {
          attemptId: reset.id,
          startedAt: reset.startedAt.toISOString(),
          status: reset.status,
          score: 0,
          resumed: false,
        };
      }
      return {
        attemptId: existing.id,
        startedAt: existing.startedAt.toISOString(),
        status: existing.status,
        score: existing.score,
        resumed: true,
      };
    }

    const totalPoints = await this.prisma.olympiadQuestion.aggregate({
      where: { olympiadId },
      _sum: { points: true },
    });

    const created = await this.prisma.olympiadAttempt.create({
      data: {
        olympiadId,
        childId: child.childId,
        status: 'in_progress',
        totalPoints: totalPoints._sum.points ?? 0,
        questionsTotal: olympiad._count.questions,
      },
    });

    return {
      attemptId: created.id,
      startedAt: created.startedAt.toISOString(),
      status: created.status,
      score: 0,
      resumed: false,
    };
  }

  async answerQuestion(
    userId: string,
    attemptId: string,
    questionId: string,
    selectedIndex: number,
  ) {
    const child = await this.loadChild(userId);

    const attempt = await this.prisma.olympiadAttempt.findUnique({
      where: { id: attemptId },
      include: { olympiad: true },
    });
    if (!attempt || attempt.childId !== child.childId) {
      throw new NotFoundException('Attempt not found');
    }
    if (attempt.status === 'finished') {
      throw new ConflictException('Attempt already finished');
    }

    // Time enforcement (durationMin + 30s grace)
    const elapsedSec = Math.floor(
      (Date.now() - attempt.startedAt.getTime()) / 1000,
    );
    const limitSec = attempt.olympiad.durationMin * 60 + GRACE_SEC;
    if (elapsedSec >= limitSec) {
      await this.prisma.olympiadAttempt.update({
        where: { id: attemptId },
        data: {
          status: 'finished',
          finishedAt: new Date(),
          timeSec: elapsedSec,
        },
      });
      throw new HttpException(
        {
          error: 'Time limit exceeded',
          autoFinished: true,
          score: attempt.score,
        },
        HttpStatus.REQUEST_TIMEOUT,
      );
    }

    const question = await this.prisma.olympiadQuestion.findUnique({
      where: { id: questionId },
    });
    if (!question || question.olympiadId !== attempt.olympiadId) {
      throw new BadRequestException(
        'Question does not belong to this olympiad',
      );
    }

    const isCorrect = selectedIndex === question.correctIndex;

    // Check for duplicate answer
    const prevAnswers = Array.isArray(attempt.answers)
      ? attempt.answers
      : [];
    const already = (
      prevAnswers as Array<{ questionId: string }>
    ).some((a) => a.questionId === questionId);
    if (already) {
      throw new ConflictException({
        error: 'This question already answered',
        correctIndex: question.correctIndex,
      });
    }

    const newAnswer = { questionId, selectedIndex, isCorrect };
    const nextAnswers = [
      ...(prevAnswers as Array<unknown>),
      newAnswer,
    ];
    const isLastQuestion = nextAnswers.length >= attempt.questionsTotal;

    const updated = await this.prisma.olympiadAttempt.update({
      where: { id: attemptId },
      data: {
        answers: nextAnswers as Prisma.InputJsonValue,
        score: { increment: isCorrect ? question.points : 0 },
        correctAnswers: { increment: isCorrect ? 1 : 0 },
        timeSec: elapsedSec,
        status: isLastQuestion ? 'finished' : 'in_progress',
        finishedAt: isLastQuestion ? new Date() : null,
      },
    });

    // Savol-savol oqimida ham test tugaganda XP beriladi (submitAttempt
    // ishlatilmasligi mumkin). Idempotent (relatedId=attemptId).
    if (isLastQuestion) {
      await this.grantOlympiadXp(
        child.childId,
        updated.id,
        attempt.olympiad.xpReward,
        updated.correctAnswers,
        updated.questionsTotal,
      );
    }

    return {
      isCorrect,
      correctIndex: question.correctIndex,
      points: isCorrect ? question.points : 0,
      scoreSoFar: updated.score,
      correctAnswers: updated.correctAnswers,
      questionsAnswered: nextAnswers.length,
      questionsTotal: updated.questionsTotal,
      isLastQuestion,
      attemptFinished: updated.status === 'finished',
    };
  }

  async submitAttempt(
    userId: string,
    attemptId: string,
    answers: Array<{ questionId: string; selectedIndex: number }>,
    _clientTimeSec: number,
  ) {
    const child = await this.loadChild(userId);

    const attempt = await this.prisma.olympiadAttempt.findUnique({
      where: { id: attemptId },
      include: {
        olympiad: { include: { questions: true } },
      },
    });
    if (!attempt || attempt.childId !== child.childId) {
      throw new NotFoundException('Attempt not found');
    }
    if (attempt.status === 'finished') {
      throw new ConflictException('Attempt already finished');
    }

    // Aralash oqimni taqiqlash: savol-savol (answerQuestion) javoblari mavjud
    // bo'lsa batch submit ishlatib bo'lmaydi (score override / dublikat
    // shishishi). Mock fallback oqimida answers bo'sh bo'ladi → ruxsat.
    const prevAnswers = Array.isArray(attempt.answers)
      ? (attempt.answers as unknown[])
      : [];
    if (prevAnswers.length > 0) {
      throw new ConflictException(
        'Javoblar savol-savol berilgan — submit kerak emas',
      );
    }

    // Server-side vaqt nazorati — answerQuestion bilan IDENTIK. Client timeSec
    // ishonchsiz (reyting timeSec bo'yicha tartiblanadi → manipulyatsiya).
    const elapsedSec = Math.floor(
      (Date.now() - attempt.startedAt.getTime()) / 1000,
    );
    const limitSec = attempt.olympiad.durationMin * 60 + GRACE_SEC;
    if (elapsedSec >= limitSec) {
      await this.prisma.olympiadAttempt.update({
        where: { id: attemptId },
        data: {
          status: 'finished',
          finishedAt: new Date(),
          timeSec: elapsedSec,
        },
      });
      throw new HttpException(
        { error: 'Time limit exceeded', autoFinished: true },
        HttpStatus.REQUEST_TIMEOUT,
      );
    }

    const questionMap = new Map(
      attempt.olympiad.questions.map((q) => [q.id, q]),
    );
    // Dublikat questionId dedup — bir xil to'g'ri javob ikki marta score
    // qo'shmasin (answerQuestion'da dedup bor edi, bu yerda yo'q edi).
    const uniqueAnswers = Array.from(
      new Map(answers.map((a) => [a.questionId, a])).values(),
    );
    let score = 0;
    let correctAnswers = 0;
    const graded: Array<{
      questionId: string;
      selectedIndex: number;
      isCorrect: boolean;
    }> = [];
    for (const a of uniqueAnswers) {
      const q = questionMap.get(a.questionId);
      if (!q) continue;
      const isCorrect = a.selectedIndex === q.correctIndex;
      if (isCorrect) {
        score += q.points;
        correctAnswers += 1;
      }
      graded.push({
        questionId: a.questionId,
        selectedIndex: a.selectedIndex,
        isCorrect,
      });
    }

    const updated = await this.prisma.olympiadAttempt.update({
      where: { id: attemptId },
      data: {
        status: 'finished',
        score,
        correctAnswers,
        timeSec: elapsedSec,
        finishedAt: new Date(),
        answers: graded as Prisma.InputJsonValue,
      },
    });

    // Mukofot — natijaga proporsional (30% dan past bo'lsa berilmaydi).
    // Idempotent (relatedId=attemptId) + xato submit'ni buzmaydi
    // (try/catch helper'da).
    await this.grantOlympiadXp(
      child.childId,
      updated.id,
      attempt.olympiad.xpReward,
      updated.correctAnswers,
      updated.questionsTotal,
    );

    return {
      attemptId: updated.id,
      score: updated.score,
      totalPoints: updated.totalPoints,
      correctAnswers: updated.correctAnswers,
      questionsTotal: updated.questionsTotal,
      timeSec: updated.timeSec,
      finishedAt: updated.finishedAt?.toISOString() ?? null,
    };
  }

  async getRanking(
    userId: string,
    range: string,
    limit: number,
    region?: string,
  ) {
    const child = await this.loadChild(userId);

    const since =
      range === 'daily'
        ? new Date(Date.now() - 86_400_000)
        : range === 'weekly'
          ? new Date(Date.now() - 7 * 86_400_000)
          : range === 'monthly'
            ? new Date(Date.now() - 30 * 86_400_000)
            : null;

    // Viloyat filtri SERVER tomonda. `region=me` → bolaning o'z viloyati.
    // Avval filtr faqat klientda, global top-N ustida ishlardi — boshqa
    // viloyat bolasi top-N ga kirmasa ro'yxat bo'sh chiqib, filtr
    // ishlamayotgandek ko'rinardi. Endi top-N O'SHA viloyat ichidan olinadi.
    const effectiveRegion =
      region === RANKING_REGION_ME ? (child.region ?? undefined) : region;
    const regionWhere = effectiveRegion
      ? { child: { is: { region: effectiveRegion } } }
      : {};

    const grouped = await this.prisma.olympiadAttempt.groupBy({
      by: ['childId'],
      where: {
        status: 'finished',
        ...(since ? { finishedAt: { gte: since } } : {}),
        ...regionWhere,
      },
      _sum: { score: true },
      _count: { _all: true },
      orderBy: { _sum: { score: 'desc' } },
      take: limit,
    });

    const childIds = grouped.map((g) => g.childId);
    if (childIds.length === 0) {
      return {
        items: [],
        range,
        currentUserId: child.childId,
        currentUser: null,
      };
    }

    const childRows = await this.prisma.child.findMany({
      where: { id: { in: childIds } },
      select: { id: true, name: true, age: true, region: true },
    });
    const childMap = new Map(childRows.map((c) => [c.id, c]));

    const items = grouped.map((g, i) => {
      const c = childMap.get(g.childId);
      return {
        position: i + 1,
        childId: g.childId,
        name: c?.name ?? '--',
        age: c?.age ?? null,
        region: c?.region ?? null,
        totalScore: g._sum.score ?? 0,
        attemptCount: g._count._all,
        isCurrentUser: g.childId === child.childId,
      };
    });

    // If current user not in top, add them separately.
    // MUHIM: viloyat filtri yoqilgan va bola BOSHQA viloyatdan bo'lsa, "Siz"
    // qatorini ko'rsatmaymiz — u bu viloyat reytingiga umuman kirmaydi.
    const childInScope =
      !effectiveRegion || child.region === effectiveRegion;
    let currentUserRow = items.find((x) => x.isCurrentUser) ?? null;
    if (!currentUserRow && childInScope) {
      const all = await this.prisma.olympiadAttempt.aggregate({
        where: {
          childId: child.childId,
          status: 'finished',
          ...(since ? { finishedAt: { gte: since } } : {}),
        },
        _sum: { score: true },
        _count: { _all: true },
      });
      const score = all._sum.score ?? 0;
      if (score > 0 || (all._count._all ?? 0) > 0) {
        const c = await this.prisma.child.findUnique({
          where: { id: child.childId },
        });
        // Viloyat filtri bu yerda ham qo'llanadi — aks holda "Siz" qatoridagi
        // o'rin GLOBAL bo'yicha hisoblanib, viloyat ro'yxatiga mos kelmasdi.
        const higher = await this.prisma.olympiadAttempt.groupBy({
          by: ['childId'],
          where: {
            status: 'finished',
            ...(since ? { finishedAt: { gte: since } } : {}),
            ...regionWhere,
          },
          _sum: { score: true },
          having: { score: { _sum: { gt: score } } },
        });
        currentUserRow = {
          position: higher.length + 1,
          childId: child.childId,
          name: c?.name ?? '--',
          age: c?.age ?? null,
          region: c?.region ?? null,
          totalScore: score,
          attemptCount: all._count._all,
          isCurrentUser: true,
        };
      }
    }

    return {
      items,
      currentUserId: child.childId,
      currentUser: currentUserRow,
      range,
    };
  }

  /* ------------------------------------------------------------------ */
  /*  #56 — Sertifikat (g'olib uchun)                                    */
  /* ------------------------------------------------------------------ */

  /**
   * Sertifikat ma'lumoti (child-side widget render qiladi → rasm/PDF).
   * Server-side PDF generatsiya O'RNIGA JSON qaytaramiz (variant b): kam
   * bog'liqlik (yangi paket yo'q), dizayn to'liq child tomonda boshqariladi,
   * va ulashish/saqlash native (share_plus) bilan ishlaydi.
   *
   * Shartlar: attempt shu bolaники, status='finished', certificateEnabled,
   * natija >= chegara (CERT_THRESHOLD_PERCENT). Aks holda 404/403.
   *
   * Privacy: to'liq ism o'rniga xavfsiz nick (ism + familiya bosh harfi).
   */
  async getCertificate(userId: string, attemptId: string) {
    const child = await this.loadChild(userId);

    const attempt = await this.prisma.olympiadAttempt.findUnique({
      where: { id: attemptId },
      include: { olympiad: true },
    });
    // Mavjud emas yoki boshqa bolaники — 404 (mavjudligini oshkor qilmaymiz).
    if (!attempt || attempt.childId !== child.childId) {
      throw new NotFoundException('Certificate not available');
    }
    if (attempt.status !== 'finished') {
      throw new NotFoundException('Attempt not finished');
    }
    if (!attempt.olympiad.certificateEnabled) {
      throw new NotFoundException('Certificate not enabled for this olympiad');
    }

    const percent = this.computePercent(attempt);
    if (percent < CERT_THRESHOLD_PERCENT) {
      throw new ForbiddenException(
        `Score ${percent}% is below the ${CERT_THRESHOLD_PERCENT}% threshold`,
      );
    }

    const childRow = await this.prisma.child.findUnique({
      where: { id: child.childId },
      select: { name: true },
    });

    return {
      certificateId: this.certificateId(attempt.id),
      childNick: this.privacyNick(childRow?.name ?? ''),
      olympiadTitle: attempt.olympiad.title,
      subject: attempt.olympiad.subject,
      score: attempt.score,
      percent,
      date: (attempt.finishedAt ?? attempt.startedAt).toISOString(),
    };
  }

  private computePercent(a: {
    score: number;
    totalPoints: number;
    correctAnswers: number;
    questionsTotal: number;
  }): number {
    if (a.totalPoints > 0) {
      return Math.round((a.score / a.totalPoints) * 100);
    }
    if (a.questionsTotal > 0) {
      return Math.round((a.correctAnswers / a.questionsTotal) * 100);
    }
    return 0;
  }

  /** Barqaror, qisqa sertifikat ID (attempt'dan). */
  private certificateId(attemptId: string): string {
    return `PRV-${attemptId.replace(/-/g, '').slice(0, 10).toUpperCase()}`;
  }

  /** "Alisher Karimov" → "Alisher K." (privacy — to'liq familiya yashiriladi). */
  private privacyNick(name: string): string {
    const parts = name.trim().split(/\s+/).filter(Boolean);
    if (parts.length === 0) return 'Parvoz yulduzi';
    if (parts.length === 1) return parts[0];
    const initial = parts[1].charAt(0).toUpperCase();
    return `${parts[0]} ${initial}.`;
  }
}
