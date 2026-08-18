import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SandboxHelper } from './SandboxHelper';
import { ExifHelper } from './ExifHelper';

const TAG: string = 'LingYing';
const DOMAIN: number = 0xFF00;

export class HeifService {
  private static heifSupported: boolean | undefined = undefined;

  static isHeifSupported(): boolean {
    if (HeifService.heifSupported !== undefined) {
      return HeifService.heifSupported;
    }

    try {
      const packer: image.ImagePacker = image.createImagePacker();
      const supportedFormats: Array<string> = packer.supportedFormats;
      HeifService.heifSupported = supportedFormats.indexOf('image/heic') >= 0;
      packer.release();
    } catch (e) {
      HeifService.heifSupported = false;
    }

    return HeifService.heifSupported;
  }

  static async convertToHeif(
    context: common.UIAbilityContext,
    imagePath: string,
    outputHeifPath: string,
    originalSourceUri?: string
  ): Promise<string> {
    hilog.info(DOMAIN, TAG, `[HeifService] convertToHeif imagePath=%{public}s output=%{public}s`, imagePath, outputHeifPath);
    const realPath: string = SandboxHelper.sandboxUriToPath(imagePath);
    hilog.info(DOMAIN, TAG, `[HeifService] realPath=%{public}s`, realPath);
    let srcFile: fs.File | undefined = undefined;
    try {
      srcFile = fs.openSync(realPath, fs.OpenMode.READ_ONLY);
      hilog.info(DOMAIN, TAG, `[HeifService] opened src file, fd=%{public}d`, srcFile.fd);
      const imageSource: image.ImageSource = image.createImageSource(srcFile.fd);
      const imagePacker: image.ImagePacker = image.createImagePacker();

      const packOpts: image.PackingOption = {
        format: 'image/heic',
        quality: 95,
        needsPackProperties: true,
      };

      const destFile = fs.openSync(outputHeifPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      hilog.info(DOMAIN, TAG, `[HeifService] opened dest file, fd=%{public}d, packing...`, destFile.fd);
      await imagePacker.packToFile(imageSource, destFile.fd, packOpts);
      fs.closeSync(destFile);

      imageSource.release();
      imagePacker.release();
      hilog.info(DOMAIN, TAG, `[HeifService] HEIF conversion success`);
    } catch (e) {
      const he: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `[HeifService] convertToHeif failed: code=%{public}d message=%{public}s`, he.code ?? 0, he.message ?? 'unknown');
      throw new Error(`HEIF conversion failed: ${he.message ?? 'unknown'}`);
    } finally {
      if (srcFile !== undefined) {
        fs.closeSync(srcFile);
      }
    }

    hilog.info(DOMAIN, TAG, `[HeifService] transferring EXIF date to HEIF output`);
    await ExifHelper.transferDateTime(imagePath, outputHeifPath, originalSourceUri);

    return `file://${outputHeifPath}`;
  }
}
