// Kirgandan keyin qaysi sahifa ochiladi (sof mantiq — testlanadi).
//
// Egasi qarori (Maktab markazda): maktabga ulangan oila — Maktab tabida;
// maktabsiz oila — Nazorat tabida (hozirgi foydalanuvchilar uchun hech
// narsa o'zgarmaydi). Farzand ham, maktab ham yo'q yangi ota-ona — bir
// marta «Qanday boshlaymiz?».

import 'package:farzandim/core/routing/app_routes.dart';

/// «Qanday boshlaymiz?» ko'rilgan / o'tkazib yuborilgan (SharedPreferences).
const kHomeStartSeenKey = 'home.startSeen.v1';

String homeLanding({
  required bool hasChildren,
  required bool hasSchool,
  required bool startSeen,
}) {
  if (hasSchool) return AppRoutes.school;
  if (!hasChildren && !startSeen) return AppRoutes.start;
  return AppRoutes.dashboard;
}
