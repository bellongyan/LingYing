import { image } from '@kit.ImageKit';
import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ErrorCode } from '../constants/ErrorCode';
import { AppConstants } from '../constants/AppConstants';
import { SandboxHelper } from './SandboxHelper';

const TAG: string = 'LingYing';
const DOMAIN: number = 0xFF00;

export class FileValidator {
  static async validateImage(context: common.UIAbilityContext, imageUri: string): Promise<number> {
    const ext: string = SandboxHelper.extractExtension(imageUri);
    const validExts: string[] = AppConstants.IMAGE_EXTENSIONS;
    if (validExts.indexOf(ext) < 0) {
      return ErrorCode.INVALID_IMAGE_FORMAT;
    }

    const fileSize: number = SandboxHelper.getFileSize(imageUri);
    if (fileSize > AppConstants.MAX_IMAGE_SIZE_BYTES) {
      return ErrorCode.FILE_TOO_LARGE;
    }

    return 0;
  }

  static async validateVideo(context: common.UIAbilityContext, videoUri: string): Promise<number> {
    const ext: string = SandboxHelper.extractExtension(videoUri);
    const validExts: string[] = AppConstants.VIDEO_EXTENSIONS;
    if (validExts.indexOf(ext) < 0) {
      return ErrorCode.INVALID_VIDEO_FORMAT;
    }

    const fileSize: number = SandboxHelper.getFileSize(videoUri);
    if (fileSize > AppConstants.MAX_VIDEO_SIZE_BYTES) {
      return ErrorCode.FILE_TOO_LARGE;
    }

    const duration: number = await FileValidator.getVideoDuration(videoUri);
    if (duration > AppConstants.MAX_VIDEO_DURATION_S) {
      return ErrorCode.VIDEO_TOO_LONG;
    }

    return 0;
  }

  static async validateAspectRatio(imageUri: string, videoUri: string): Promise<number> {
    const imageDim = await FileValidator.getImageDimensions(imageUri);
    const videoDim = await FileValidator.getVideoDimensions(videoUri);

    if (imageDim.width <= 0 || imageDim.height <= 0 || videoDim.width <= 0 || videoDim.height <= 0) {
      return 0;
    }

    const imageRatio: number = imageDim.width / imageDim.height;
    const videoRatio: number = videoDim.width / videoDim.height;
    const diff: number = Math.abs(imageRatio - videoRatio) / Math.max(imageRatio, videoRatio);

    if (diff > AppConstants.ASPECT_RATIO_TOLERANCE) {
      return ErrorCode.ASPECT_RATIO_MISMATCH;
    }

    return 0;
  }

  static async getImageDimensions(imageUri: string): Promise<ImageDimensions> {
    const dims: ImageDimensions = new ImageDimensions();
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(imageUri, fs.OpenMode.READ_ONLY);
      const source: image.ImageSource = image.createImageSource(file.fd);
      const info: image.ImageInfo = await source.getImageInfo();
      dims.width = info.size.width;
      dims.height = info.size.height;
      source.release();
    } catch (e) {
      dims.width = 0;
      dims.height = 0;
    } finally {
      if (file !== undefined) {
        fs.closeSync(file);
      }
    }
    return dims;
  }

  static async getVideoDuration(videoUri: string): Promise<number> {
    hilog.info(DOMAIN, TAG, `[FileValidator] getVideoDuration uri=%{public}s`, videoUri);
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(videoUri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const fdValue: number = file.fd;
      const fileSize: number = stat.size;
      hilog.info(DOMAIN, TAG, `[FileValidator] fd=%{public}d fileSize=%{public}d`, fdValue, fileSize);
      const avPlayer: media.AVPlayer = await media.createAVPlayer();
      const duration: number = await new Promise<number>((resolve: (value: number) => void) => {
        avPlayer.on('stateChange', (state: string) => {
          hilog.info(DOMAIN, TAG, `[FileValidator] AVPlayer stateChange: %{public}s`, state);
          if (state === 'initialized') {
            hilog.info(DOMAIN, TAG, `[FileValidator] AVPlayer initialized, calling prepare()`);
            avPlayer.prepare().catch((err: BusinessError) => {
              hilog.error(DOMAIN, TAG, `[FileValidator] AVPlayer prepare failed: %{public}s`, err.message ?? 'unknown');
              avPlayer.release();
              resolve(0);
            });
          }
          if (state === 'prepared') {
            const dur: number = avPlayer.duration;
            hilog.info(DOMAIN, TAG, `[FileValidator] AVPlayer prepared, duration=%{public}d`, dur);
            avPlayer.release();
            resolve(dur / 1000);
          }
          if (state === 'error') {
            hilog.error(DOMAIN, TAG, `[FileValidator] AVPlayer error state`);
            avPlayer.release();
            resolve(0);
          }
        });
        avPlayer.fdSrc = { fd: fdValue, offset: 0, length: fileSize } as media.AVFileDescriptor;
      });
      if (file !== undefined) {
        fs.closeSync(file);
        file = undefined;
      }
      hilog.info(DOMAIN, TAG, `[FileValidator] getVideoDuration result=%{public}f`, duration);
      return duration;
    } catch (e) {
      const ve: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `[FileValidator] getVideoDuration exception: %{public}s`, ve.message ?? 'unknown');
      if (file !== undefined) {
        fs.closeSync(file);
      }
      return 0;
    }
  }

  static async getVideoDimensions(videoUri: string): Promise<ImageDimensions> {
    hilog.info(DOMAIN, TAG, `[FileValidator] getVideoDimensions uri=%{public}s`, videoUri);
    const dims: ImageDimensions = new ImageDimensions();
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(videoUri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const fdValue: number = file.fd;
      const fileSize: number = stat.size;
      hilog.info(DOMAIN, TAG, `[FileValidator] getVideoDimensions fd=%{public}d fileSize=%{public}d`, fdValue, fileSize);
      const avPlayer: media.AVPlayer = await media.createAVPlayer();
      await new Promise<void>((resolve: () => void) => {
        avPlayer.on('stateChange', (state: string) => {
          hilog.info(DOMAIN, TAG, `[FileValidator] AVPlayer dims stateChange: %{public}s`, state);
          if (state === 'initialized') {
            hilog.info(DOMAIN, TAG, `[FileValidator] AVPlayer dims initialized, calling prepare()`);
            avPlayer.prepare().catch((err: BusinessError) => {
              hilog.error(DOMAIN, TAG, `[FileValidator] AVPlayer dims prepare failed: %{public}s`, err.message ?? 'unknown');
              avPlayer.release();
              resolve();
            });
          }
          if (state === 'prepared') {
            dims.width = avPlayer.width;
            dims.height = avPlayer.height;
            hilog.info(DOMAIN, TAG, `[FileValidator] AVPlayer dims: %{public}dx%{public}d`, dims.width, dims.height);
            avPlayer.release();
            resolve();
          }
          if (state === 'error') {
            hilog.error(DOMAIN, TAG, `[FileValidator] AVPlayer dims error state`);
            avPlayer.release();
            resolve();
          }
        });
        avPlayer.fdSrc = { fd: fdValue, offset: 0, length: fileSize } as media.AVFileDescriptor;
      });
      if (file !== undefined) {
        fs.closeSync(file);
        file = undefined;
      }
      return dims;
    } catch (e) {
      const de: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `[FileValidator] getVideoDimensions exception: %{public}s`, de.message ?? 'unknown');
      if (file !== undefined) {
        fs.closeSync(file);
      }
      return dims;
    }
  }
}

export class ImageDimensions {
  width: number = 0;
  height: number = 0;
}
