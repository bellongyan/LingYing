import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ErrorCode } from '../constants/ErrorCode';
import { AppConstants } from '../constants/AppConstants';
import { ProcessResult, ProcessErrorRecord } from '../model/FilePair';
import { HeifService } from './HeifService';
import { SandboxHelper } from './SandboxHelper';
import { ExifHelper } from './ExifHelper';

const TAG: string = 'LingYing';
const DOMAIN: number = 0xFF00;

export class LivePhotoService {
  static async composeLivePhoto(
    context: common.UIAbilityContext,
    jpgSandboxUri: string,
    mp4SandboxUri: string,
    originalJpgUri: string,
    originalMp4Uri: string
  ): Promise<ProcessResult> {
    hilog.info(DOMAIN, TAG, `[LivePhoto] composeLivePhoto start, jpgUri=%{public}s mp4Uri=%{public}s`, jpgSandboxUri, mp4SandboxUri);
    const originalFileName: string = SandboxHelper.extractFileName(originalJpgUri);
    const originalBaseName: string = SandboxHelper.extractBaseName(originalJpgUri);
    const pairedVideo: string = SandboxHelper.extractBaseName(originalMp4Uri) + '.mp4';

    hilog.info(DOMAIN, TAG, `[LivePhoto] trying L0...`);
    const l0Result: ProcessResult = await LivePhotoService.tryL0(
      context, jpgSandboxUri, mp4SandboxUri,
      originalBaseName, originalFileName, pairedVideo, originalJpgUri
    );
    if (l0Result.success) {
      hilog.info(DOMAIN, TAG, `[LivePhoto] L0 success`);
      return l0Result;
    }
    hilog.warn(DOMAIN, TAG, `[LivePhoto] L0 failed, trying L1...`);

    const l1Result: ProcessResult = await LivePhotoService.tryL1(
      context, jpgSandboxUri, mp4SandboxUri,
      originalBaseName, originalFileName, pairedVideo
    );
    if (l1Result.success) {
      hilog.info(DOMAIN, TAG, `[LivePhoto] L1 success`);
      return l1Result;
    }
    hilog.warn(DOMAIN, TAG, `[LivePhoto] L1 failed, trying L2...`);

    const l2Result: ProcessResult = await LivePhotoService.tryL2(
      context, jpgSandboxUri, mp4SandboxUri, originalFileName, pairedVideo, originalJpgUri
    );
    if (l2Result.success) {
      hilog.info(DOMAIN, TAG, `[LivePhoto] L2 success`);
    } else {
      hilog.error(DOMAIN, TAG, `[LivePhoto] L2 also failed, all levels exhausted`);
    }
    return l2Result;
  }

  static async tryL0(
    context: common.UIAbilityContext,
    jpgSandboxUri: string,
    mp4SandboxUri: string,
    originalBaseName: string,
    originalFileName: string,
    pairedVideo: string,
    originalJpgUri: string
  ): Promise<ProcessResult> {
    if (!HeifService.isHeifSupported()) {
      hilog.warn(DOMAIN, TAG, `[LivePhoto] L0: HEIF not supported, skip`);
      return LivePhotoService.createFailureResult(originalFileName, pairedVideo, ErrorCode.HEIF_CONVERSION_FAILED, false);
    }

    let heifSandboxUri: string = '';
    try {
      const heifPath: string = `${context.filesDir}/${AppConstants.SANDBOX_DIR}/${originalBaseName}_${Date.now()}.heic`;
      hilog.info(DOMAIN, TAG, `[LivePhoto] L0: converting JPG to HEIF, output=%{public}s`, heifPath);
      heifSandboxUri = await HeifService.convertJpgToHeif(context, jpgSandboxUri, heifPath, originalJpgUri);
      hilog.info(DOMAIN, TAG, `[LivePhoto] L0: HEIF conversion success, uri=%{public}s`, heifSandboxUri);
    } catch (e) {
      const heifErr: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `[LivePhoto] L0: HEIF conversion failed: %{public}s`, heifErr.message ?? 'unknown');
      return LivePhotoService.createFailureResult(originalFileName, pairedVideo, ErrorCode.HEIF_CONVERSION_FAILED, false);
    }

    const apiResult: ProcessResult = await LivePhotoService.callOfficialApi(
      context, heifSandboxUri, mp4SandboxUri, originalBaseName, 'heic', originalFileName, pairedVideo
    );

    if (!apiResult.success) {
      return apiResult;
    }

    return ProcessResult.createSuccess(
      originalFileName,
      pairedVideo,
      AppConstants.OUTPUT_TYPE_L0,
      apiResult.livePhotoUri,
      false
    );
  }

  static async tryL1(
    context: common.UIAbilityContext,
    jpgSandboxUri: string,
    mp4SandboxUri: string,
    originalBaseName: string,
    originalFileName: string,
    pairedVideo: string
  ): Promise<ProcessResult> {
    const apiResult: ProcessResult = await LivePhotoService.callOfficialApi(
      context, jpgSandboxUri, mp4SandboxUri, originalBaseName, 'jpg', originalFileName, pairedVideo
    );

    if (!apiResult.success) {
      return apiResult;
    }

    return ProcessResult.createSuccess(
      originalFileName,
      pairedVideo,
      AppConstants.OUTPUT_TYPE_L1,
      apiResult.livePhotoUri,
      true
    );
  }

  static async tryL2(
    context: common.UIAbilityContext,
    jpgSandboxUri: string,
    mp4SandboxUri: string,
    fileName: string,
    pairedVideo: string,
    originalJpgUri: string
  ): Promise<ProcessResult> {
    hilog.info(DOMAIN, TAG, `[LivePhoto] tryL2 start (binary splice fallback)`);
    try {
      const jpgPath: string = SandboxHelper.sandboxUriToPath(jpgSandboxUri);
      const mp4Path: string = SandboxHelper.sandboxUriToPath(mp4SandboxUri);
      hilog.info(DOMAIN, TAG, `[LivePhoto] L2: jpgPath=%{public}s mp4Path=%{public}s`, jpgPath, mp4Path);

      const jpgStat = fs.statSync(jpgPath);
      const mp4Stat = fs.statSync(mp4Path);
      hilog.info(DOMAIN, TAG, `[LivePhoto] L2: jpgSize=%{public}d mp4Size=%{public}d`, jpgStat.size, mp4Stat.size);

      const outputBaseName: string = SandboxHelper.extractBaseName(jpgSandboxUri);
      const outputPath: string = `${context.filesDir}/${AppConstants.SANDBOX_DIR}/${outputBaseName}_${Date.now()}.jpg`;
      const outputFile = fs.openSync(outputPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);

      const jpgFile = fs.openSync(jpgPath, fs.OpenMode.READ_ONLY);
      const jpgBuffer = new ArrayBuffer(jpgStat.size);
      fs.readSync(jpgFile.fd, jpgBuffer);
      fs.closeSync(jpgFile);
      fs.writeSync(outputFile.fd, jpgBuffer);

      const xmpStr: string = LivePhotoService.buildXmpMetadata(jpgStat.size, mp4Stat.size);
      const xmpBuffer: ArrayBuffer = LivePhotoService.stringToArrayBuffer(xmpStr);
      fs.writeSync(outputFile.fd, xmpBuffer);

      const mp4File = fs.openSync(mp4Path, fs.OpenMode.READ_ONLY);
      const mp4Buffer = new ArrayBuffer(mp4Stat.size);
      fs.readSync(mp4File.fd, mp4Buffer);
      fs.closeSync(mp4File);
      fs.writeSync(outputFile.fd, mp4Buffer);

      fs.closeSync(outputFile);

      hilog.info(DOMAIN, TAG, `[LivePhoto] L2: transferring EXIF date to output`);
      await ExifHelper.transferDateTime(jpgSandboxUri, outputPath, originalJpgUri);

      return ProcessResult.createSuccess(
        fileName,
        pairedVideo,
        AppConstants.OUTPUT_TYPE_L2,
        `file://${outputPath}`,
        true
      );
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      const errMsg: string = err.message ?? 'unknown';
      hilog.error(DOMAIN, TAG, `[LivePhoto] L2 failed: %{public}s`, errMsg);
      return ProcessResult.createFailure(
        fileName,
        pairedVideo,
        ProcessErrorRecord.create(
          fileName,
          pairedVideo,
          ErrorCode.BINARY_SPLICE_FAILED,
          `${ErrorCode.getMessage(ErrorCode.BINARY_SPLICE_FAILED)}: ${errMsg}`,
          false
        )
      );
    }
  }

  static async callOfficialApi(
    context: common.UIAbilityContext,
    imageSandboxUri: string,
    mp4SandboxUri: string,
    assetBaseName: string,
    assetExtension: string,
    fileName: string,
    pairedVideo: string
  ): Promise<ProcessResult> {
    hilog.info(DOMAIN, TAG, `[LivePhoto] callOfficialApi start, imageUri=%{public}s mp4Uri=%{public}s title=%{public}s ext=%{public}s`, imageSandboxUri, mp4SandboxUri, assetBaseName, assetExtension);
    try {
      const phAccessHelper: photoAccessHelper.PhotoAccessHelper =
        photoAccessHelper.getPhotoAccessHelper(context);

      const createOptions: photoAccessHelper.CreateOptions = {
        title: assetBaseName,
        subtype: photoAccessHelper.PhotoSubtype.MOVING_PHOTO,
      };

      hilog.info(DOMAIN, TAG, `[LivePhoto] creating asset request (IMAGE/%{public}s/MOVING_PHOTO)...`, assetExtension);
      const assetChangeRequest: photoAccessHelper.MediaAssetChangeRequest =
        photoAccessHelper.MediaAssetChangeRequest.createAssetRequest(
          context,
          photoAccessHelper.PhotoType.IMAGE,
          assetExtension,
          createOptions
        );

      hilog.info(DOMAIN, TAG, `[LivePhoto] adding IMAGE_RESOURCE uri=%{public}s`, imageSandboxUri);
      assetChangeRequest.addResource(
        photoAccessHelper.ResourceType.IMAGE_RESOURCE,
        imageSandboxUri
      );

      hilog.info(DOMAIN, TAG, `[LivePhoto] adding VIDEO_RESOURCE uri=%{public}s`, mp4SandboxUri);
      assetChangeRequest.addResource(
        photoAccessHelper.ResourceType.VIDEO_RESOURCE,
        mp4SandboxUri
      );

      hilog.info(DOMAIN, TAG, `[LivePhoto] applying changes...`);
      await phAccessHelper.applyChanges(assetChangeRequest);

      const uri: string = assetChangeRequest.getAsset().uri;
      hilog.info(DOMAIN, TAG, `[LivePhoto] applyChanges success, asset uri=%{public}s`, uri);

      return ProcessResult.createSuccess(
        fileName,
        pairedVideo,
        '',
        uri,
        false
      );
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      const errMsg: string = err.message ?? 'unknown';
      const errCode: number = err.code ?? 0;
      hilog.error(DOMAIN, TAG, `[LivePhoto] callOfficialApi failed: code=%{public}d message=%{public}s`, errCode, errMsg);
      return ProcessResult.createFailure(
        fileName,
        pairedVideo,
        ProcessErrorRecord.create(
          fileName,
          pairedVideo,
          ErrorCode.OFFICIAL_API_FAILED,
          `${ErrorCode.getMessage(ErrorCode.OFFICIAL_API_FAILED)}: ${errMsg}`,
          ErrorCode.isRetryable(ErrorCode.OFFICIAL_API_FAILED)
        )
      );
    }
  }

  static buildXmpMetadata(jpgSize: number, mp4Size: number): string {
    return `<?xpacket begin='' id='W5M0MpCehiHzreSzNTczkc9d'?>
<x:xmpmeta xmlns:x='adobe:ns:meta/'>
  <rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
    <rdf:Description
      xmlns:GCamera='http://ns.google.com/photos/1.0/camera/'
      GCamera:MicroVideo='1'
      GCamera:MicroVideoVersion='1'
      GCamera:MicroVideoOffset='${mp4Size}'
      GCamera:MicroVideoPresentationTimestampUs='0'>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>
<?xpacket end='w'?>`;
  }

  static stringToArrayBuffer(str: string): ArrayBuffer {
    const length: number = str.length;
    const buffer: ArrayBuffer = new ArrayBuffer(length);
    const view: Uint8Array = new Uint8Array(buffer);
    for (let i = 0; i < length; i++) {
      view[i] = str.charCodeAt(i);
    }
    return buffer;
  }

  private static createFailureResult(
    fileName: string,
    pairedVideo: string,
    errorCode: number,
    retryable: boolean
  ): ProcessResult {
    return ProcessResult.createFailure(
      fileName,
      pairedVideo,
      ProcessErrorRecord.create(
        fileName,
        pairedVideo,
        errorCode,
        ErrorCode.getMessage(errorCode),
        retryable
      )
    );
  }
}
