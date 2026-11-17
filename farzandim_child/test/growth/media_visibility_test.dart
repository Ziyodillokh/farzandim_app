// Audio / video yashirin: qaysi manzillar bloklanadi.

import 'package:farzandim_child/growth/common/media_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audio / video manzillari yashirin, qolganlari ochiq', () {
    for (final route in [
      '/videos',
      '/audiobooks',
      '/video-player',
      '/oqish/kutubxona',
      '/oqish/kutubxona/audio/b1',
      '/content?tab=video',
    ]) {
      expect(isHiddenMediaRoute(route), !kShowAudioVideo, reason: route);
    }
    for (final route in ['/oqish', '/oqish/olimpiada', '/voice-chat', null]) {
      expect(isHiddenMediaRoute(route), isFalse, reason: '$route');
    }
  });
}
