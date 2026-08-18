export class AppConstants {
  static readonly MAX_VIDEO_DURATION_S: number = 10;
  static readonly MAX_IMAGE_SIZE_BYTES: number = 100 * 1024 * 1024;
  static readonly MAX_VIDEO_SIZE_BYTES: number = 200 * 1024 * 1024;
  static readonly ASPECT_RATIO_TOLERANCE: number = 0.1;
  static readonly SANDBOX_DIR: string = 'live_photo_temp';
  static readonly IMAGE_EXTENSIONS: string[] = ['jpg', 'jpeg'];
  static readonly VIDEO_EXTENSIONS: string[] = ['mp4'];
  static readonly OUTPUT_TYPE_L0: string = 'L0';
  static readonly OUTPUT_TYPE_L1: string = 'L1';
  static readonly OUTPUT_TYPE_L2: string = 'L2';
}
