const int kMaxAudioUploadBytes = 500 * 1024 * 1024;

bool isAllowedAudioFileName(String name) {
  final i = name.lastIndexOf('.');
  if (i < 0) return false;
  final ext = name.substring(i).toLowerCase();
  return const {
    '.mp3',
    '.m4a',
    '.aac',
    '.wav',
    '.ogg',
    '.opus',
    '.webm',
  }.contains(ext);
}
