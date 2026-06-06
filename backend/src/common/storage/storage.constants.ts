export const BUCKETS = {
  avatars: 'farzandim-avatars',
  voice: 'farzandim-voice',
  video: 'farzandim-video',
  appIcons: 'farzandim-app-icons',
  contentVideos: 'farzandim-content-videos',
  contentAudio: 'farzandim-content-audio',
  contentBooks: 'farzandim-content-books',
  contentThumbnails: 'farzandim-content-thumbnails',
  support: 'farzandim-support',
  chat: 'farzandim-chat',
  olympiad: 'farzandim-olympiad',
} as const;

export type BucketName = (typeof BUCKETS)[keyof typeof BUCKETS];
