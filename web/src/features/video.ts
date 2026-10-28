export type VideoInfo = {
  readonly width: number;
  readonly height: number;
  readonly duration: number;
};

export function readVideoInfo(src: string): Promise<VideoInfo | null> {
  return new Promise((resolve) => {
    const video = document.createElement('video');

    const done = (size: VideoInfo | null) => {
      video.removeAttribute('src');
      video.load();
      resolve(size);
    };

    video.preload = 'metadata';
    video.muted = true;

    video.onloadedmetadata = () =>
      done(
        video.videoWidth && video.videoHeight
          ? { width: video.videoWidth, height: video.videoHeight, duration: video.duration }
          : null,
      );

    video.onerror = () => done(null);
    video.src = src;
  });
}
