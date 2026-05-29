/**
 * Diagnostic — so'nggi 10 ta location yozuvini ko'rsatadi.
 * Ishlatish: node scripts/last-locations.js
 */
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  const locations = await prisma.location.findMany({
    take: 10,
    orderBy: { createdAt: 'desc' },
    select: {
      id: true,
      childId: true,
      latitude: true,
      longitude: true,
      accuracy: true,
      batteryLevel: true,
      createdAt: true,
    },
  });

  // Child device info — qaysi qurilmadan kelayotganini ko'rsatish
  const childIds = [...new Set(locations.map((l) => l.childId))];
  const children = await prisma.child.findMany({
    where: { id: { in: childIds } },
    select: {
      id: true,
      name: true,
      deviceModel: true,
      androidVersion: true,
      appVersion: true,
      wifiName: true,
      batteryLevel: true,
      isCharging: true,
      lastSeenAt: true,
    },
  });
  const childMap = Object.fromEntries(children.map((c) => [c.id, c]));

  if (locations.length === 0) {
    console.log('❌ Locations jadvali BO\'SH — birorta POST /api/location qabul qilinmagan');
    return;
  }

  const now = new Date();
  console.log(`📍 So'nggi ${locations.length} ta location:\n`);
  console.log('Hozirgi vaqt (UTC):', now.toISOString());
  console.log('Hozirgi vaqt (Tashkent UTC+5):', new Date(now.getTime() + 5 * 60 * 60 * 1000).toISOString().replace('Z', ' +05:00'));
  console.log('');

  // Device info qisqacha
  console.log('📱 Qurilma ma\'lumotlari (Child obyektidan):');
  for (const c of children) {
    const dev = c.deviceModel ?? '—';
    const os = c.androidVersion ?? '—';
    const app = c.appVersion ?? '—';
    const wifi = c.wifiName ?? '—';
    const batt = c.batteryLevel !== null ? `${c.batteryLevel}%` : '—';
    const charge = c.isCharging === true ? '⚡' : c.isCharging === false ? '🔋' : '—';
    console.log(`  ${c.name} (${c.id.slice(0, 8)}…): ${dev} | Android ${os} | App ${app} | Wi-Fi: ${wifi} | ${batt} ${charge}`);
  }
  console.log('');

  for (const loc of locations) {
    const ageMs = now.getTime() - loc.createdAt.getTime();
    const ageMin = Math.floor(ageMs / 1000 / 60);
    const ageStr =
      ageMin < 1 ? 'hozirgina' :
      ageMin < 60 ? `${ageMin} daqiqa oldin` :
      ageMin < 1440 ? `${Math.floor(ageMin / 60)} soat ${ageMin % 60} daq oldin` :
      `${Math.floor(ageMin / 1440)} kun oldin`;

    console.log(`  childId: ${loc.childId.slice(0, 8)}…`);
    console.log(`    coords:  ${loc.latitude.toFixed(6)}, ${loc.longitude.toFixed(6)}`);
    console.log(`    battery: ${loc.batteryLevel ?? '—'}%`);
    console.log(`    vaqt:    ${loc.createdAt.toISOString()} (${ageStr})`);
    console.log('');
  }

  // Aniq tashxis
  const lastAge = (now.getTime() - locations[0].createdAt.getTime()) / 1000 / 60;
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  if (lastAge < 5) {
    console.log('✅ TASHXIS: Child App REAL POST qilyapti (oxirgi yozuv ${lastAge.toFixed(1)} daq oldin)');
  } else if (lastAge < 60) {
    console.log(`🟡 TASHXIS: Oxirgi yozuv ${Math.floor(lastAge)} daqiqa oldin — Child App ishlamayotgan bo'lishi mumkin`);
  } else {
    console.log(`🔴 TASHXIS: Oxirgi yozuv ${(lastAge / 60).toFixed(1)} soat oldin — Child App POST QILMAYAPTI`);
    console.log('   Mumkin sabablar:');
    console.log('   1. Background location service o\'lgan (battery saver / doze mode)');
    console.log('   2. Location permission "Always" emas');
    console.log('   3. Child App ochilmagan');
    console.log('   4. Network/auth muammosi');
  }
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
}

main()
  .catch((e) => {
    console.error('XATO:', e.message);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
