// «O'chirishni taqiqlash» siyosati v5 qobig'ida (fn-uninstall-guard-regression):
// ota-ona yoqsa — sessiyada ko'pi bilan bitta tizim dialogi; o'chirsa —
// dialogsiz; tarmoq xatosida holat o'zgarmaydi; parallel chaqiruv — bitta so'rov.

import 'dart:async';

import 'package:farzandim_child/growth/shell/uninstall_guard_syncer.dart';
import 'package:flutter_test/flutter_test.dart';

class _Device {
  _Device({this.policy, this.active = false});

  bool? policy;
  bool active;
  int reads = 0;
  final applied = <(bool?, bool)>[];
  Completer<void>? readGate;

  late final syncer = UninstallGuardSyncer(
    readPolicy: (childId) async {
      expect(childId, 'child-1');
      reads++;
      await readGate?.future;
      return policy;
    },
    isActive: () async => active,
    apply: (shouldProtect, {required allowPrompt}) async {
      applied.add((shouldProtect, allowPrompt));
      return active;
    },
  );
}

void main() {
  test('himoya kerak — dialog sessiyada faqat bir marta', () async {
    final device = _Device(policy: true);

    await device.syncer.sync('child-1'); // ilova ochildi
    await device.syncer.sync('child-1'); // qaytdi (bola rad etgan)
    await device.syncer.sync('child-1');

    expect(device.applied, [(true, true), (true, false), (true, false)]);
  });

  test('admin yoqilgan bo\'lsa dialog imkoniyati sarflanmaydi', () async {
    final device = _Device(policy: true, active: true);

    await device.syncer.sync('child-1');
    // Bola admin'ni Sozlamalardan o'chirdi — qaytganda bir marta so'raladi.
    device.active = false;
    await device.syncer.sync('child-1');
    await device.syncer.sync('child-1');

    expect(device.applied, [(true, false), (true, true), (true, false)]);
  });

  test('ota-ona o\'chirsa — dialogsiz qo\'llanadi', () async {
    final device = _Device(policy: false, active: true);

    await device.syncer.sync('child-1');

    expect(device.applied, [(false, false)]);
  });

  test('tarmoq xatosi (null) — holat o\'zgarmaydi', () async {
    final device = _Device();

    await device.syncer.sync('child-1');
    // Keyin siyosat keldi — dialog imkoniyati saqlangan.
    device.policy = true;
    await device.syncer.sync('child-1');

    expect(device.applied, [(null, false), (true, true)]);
  });

  test('ochilish va qaytish ustma-ust — bitta so\'rov', () async {
    final device = _Device(policy: true)..readGate = Completer<void>();

    final first = device.syncer.sync('child-1');
    final second = device.syncer.sync('child-1');
    device.readGate!.complete();
    await Future.wait([first, second]);

    expect(device.reads, 1);
    expect(device.applied, [(true, true)]);

    // Tugagach keyingi chaqiruv yana o'qiydi.
    await device.syncer.sync('child-1');
    expect(device.reads, 2);
  });
}
