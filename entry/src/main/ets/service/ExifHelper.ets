import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SandboxHelper } from './SandboxHelper';

const TAG: string = 'LingYing';
const DOMAIN: number = 0xFF00;

export class ExifHelper {
  static async readDateTimeOriginal(jpgSandboxUri: string, originalSourceUri?: string): Promise<string> {
    let file: fs.File | undefined = undefined;
    try {
      const realPath: string = SandboxHelper.sandboxUriToPath(jpgSandboxUri);
      file = fs.openSync(realPath, fs.OpenMode.READ_ONLY);
      const source: image.ImageSource = image.createImageSource(file.fd);
      const options: image.ImagePropertyOptions = { index: 0, defaultValue: '' };
      let dateTimeOriginal: string = '';
      try {
        dateTimeOriginal = await source.getImageProperty(image.PropertyKey.DATE_TIME_ORIGINAL, options);
      } catch (e) {
        hilog.warn(DOMAIN, TAG, `[ExifHelper] DATE_TIME_ORIGINAL not found, trying DATE_TIME`);
        try {
          dateTimeOriginal = await source.getImageProperty(image.PropertyKey.DATE_TIME, options);
        } catch (e2) {
          hilog.warn(DOMAIN, TAG, `[ExifHelper] DATE_TIME also not found`);
        }
      }
      source.release();
      fs.closeSync(file);
      file = undefined;
      if (dateTimeOriginal.length > 0) {
        hilog.info(DOMAIN, TAG, `[ExifHelper] readDateTimeOriginal: %{public}s`, dateTimeOriginal);
        return dateTimeOriginal;
      }
      hilog.info(DOMAIN, TAG, `[ExifHelper] no EXIF date, falling back to original file mtime`);
      if (originalSourceUri !== undefined && originalSourceUri.length > 0) {
        return ExifHelper.readMtimeAsExifDateFromUri(originalSourceUri);
      }
      return ExifHelper.readMtimeAsExifDate(realPath);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `[ExifHelper] readDateTimeOriginal failed`);
      if (file !== undefined) {
        fs.closeSync(file);
      }
      return '';
    }
  }

  static readMtimeAsExifDate(filePath: string): string {
    try {
      const stat: fs.Stat = fs.statSync(filePath);
      const date: Date = new Date(stat.mtime * 1000);
      const year: number = date.getFullYear();
      const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
      const day: string = date.getDate().toString().padStart(2, '0');
      const hour: string = date.getHours().toString().padStart(2, '0');
      const minute: string = date.getMinutes().toString().padStart(2, '0');
      const second: string = date.getSeconds().toString().padStart(2, '0');
      const exifDate: string = `${year}:${month}:${day} ${hour}:${minute}:${second}`;
      hilog.info(DOMAIN, TAG, `[ExifHelper] mtime-based date: %{public}s`, exifDate);
      return exifDate;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `[ExifHelper] readMtimeAsExifDate failed`);
      return '';
    }
  }

  static readMtimeAsExifDateFromUri(uri: string): string {
    try {
      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      fs.closeSync(file);
      const date: Date = new Date(stat.mtime * 1000);
      const year: number = date.getFullYear();
      const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
      const day: string = date.getDate().toString().padStart(2, '0');
      const hour: string = date.getHours().toString().padStart(2, '0');
      const minute: string = date.getMinutes().toString().padStart(2, '0');
      const second: string = date.getSeconds().toString().padStart(2, '0');
      const exifDate: string = `${year}:${month}:${day} ${hour}:${minute}:${second}`;
      hilog.info(DOMAIN, TAG, `[ExifHelper] mtime-based date from original: %{public}s`, exifDate);
      return exifDate;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `[ExifHelper] readMtimeAsExifDateFromUri failed`);
      return '';
    }
  }

  static async writeDateTimeToOutput(outputFilePath: string, dateTimeOriginal: string): Promise<void> {
    if (dateTimeOriginal.length === 0) {
      hilog.info(DOMAIN, TAG, `[ExifHelper] no dateTimeOriginal to write, skip`);
      return;
    }
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(outputFilePath, fs.OpenMode.READ_WRITE);
      const source: image.ImageSource = image.createImageSource(file.fd);
      try {
        await source.modifyImageProperty(image.PropertyKey.DATE_TIME_ORIGINAL, dateTimeOriginal);
        hilog.info(DOMAIN, TAG, `[ExifHelper] wrote DATE_TIME_ORIGINAL: %{public}s`, dateTimeOriginal);
      } catch (e) {
        hilog.warn(DOMAIN, TAG, `[ExifHelper] failed to write DATE_TIME_ORIGINAL`);
      }
      try {
        await source.modifyImageProperty(image.PropertyKey.DATE_TIME, dateTimeOriginal);
        hilog.info(DOMAIN, TAG, `[ExifHelper] wrote DATE_TIME: %{public}s`, dateTimeOriginal);
      } catch (e) {
        hilog.warn(DOMAIN, TAG, `[ExifHelper] failed to write DATE_TIME`);
      }
      source.release();
      fs.closeSync(file);
      file = undefined;
    } catch (e) {
      hilog.error(DOMAIN, TAG, `[ExifHelper] writeDateTimeToOutput failed`);
      if (file !== undefined) {
        fs.closeSync(file);
      }
    }
  }

  static async transferDateTime(jpgSandboxUri: string, outputFilePath: string, originalSourceUri?: string): Promise<void> {
    const dateTimeOriginal: string = await ExifHelper.readDateTimeOriginal(jpgSandboxUri, originalSourceUri);
    if (dateTimeOriginal.length > 0) {
      await ExifHelper.writeDateTimeToOutput(outputFilePath, dateTimeOriginal);
    }
  }
}
