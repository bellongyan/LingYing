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
    imageSandboxUri: string,
    videoSandboxUri: string,
    originalImageUri: string,
    originalVideoUri: string,
    imageExt: string,
    videoExt: string
  ): Promise<ProcessResult> {
    hilog.info(DOMAIN, TAG, `[LivePhoto] composeLivePhoto start, imageUri=%{public}s videoUri=%{public}s imageExt=%{public}s videoExt=%{public}s`, imageSandboxUri, videoSandboxUri, imageExt, videoExt);
    const originalFileName: string = SandboxHelper.extractFileName(originalImageUri);
    const originalBaseName: string = SandboxHelper.extractBaseName(originalImageUri);
    const pairedVideo: string = SandboxHelper.extractFileName(originalVideoUri);

    hilog.info(DOMAIN, TAG, `[LivePhoto] trying L0...`);
    const l0Result: ProcessResult = await LivePhotoService.tryL0(
      context, imageSandboxUri, videoSandboxUri,
      originalBaseName, originalFileName, pairedVideo, originalImageUri, imageExt, videoExt
    );
    if (l0Result.success) {
      hilog.info(DOMAIN, TAG, `[LivePhoto] L0 success`);
      return l0Result;
    }
    hilog.warn(DOMAIN, TAG, `[LivePhoto] L0 failed, trying L1...`);

    const l1Result: ProcessResult = await LivePhotoService.tryL1(
      context, imageSandboxUri, videoSandboxUri,
      originalBaseName, originalFileName, pairedVideo, imageExt, videoExt
    );
    if (l1Result.success) {
      hilog.info(DOMAIN, TAG, `[LivePhoto] L1 success`);
      return l1Result;
    }
    hilog.warn(DOMAIN, TAG, `[LivePhoto] L1 failed, trying L2...`);

    const l2Result: ProcessResult = await LivePhotoService.tryL2(
      context, imageSandboxUri, videoSandboxUri, originalFileName, pairedVideo, originalImageUri
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
    imageSandboxUri: string,
    videoSandboxUri: string,
    originalBaseName: string,
    originalFileName: string,
    pairedVideo: string,
    originalImageUri: string,
    imageExt: string,
    videoExt: string
  ): Promise<ProcessResult> {
    if (!HeifService.isHeifSupported()) {
      hilog.warn(DOMAIN, TAG, `[LivePhoto] L0: HEIF not supported, skip`);
      return LivePhotoService.createFailureResult(originalFileName, pairedVideo, ErrorCode.HEIF_CONVERSION_FAILED, false);
    }

    let heifSandboxUri: string = '';
    try {
      const heifPath: string = `${context.filesDir}/${AppConstants.SANDBOX_DIR}/${originalBaseName}_${Date.now()}.heic`;
      hilog.info(DOMAIN, TAG, `[LivePhoto] L0: converting image to HEIF, output=%{public}s`, heifPath);
      heifSandboxUri = await HeifService.convertToHeif(context, imageSandboxUri, heifPath, originalImageUri);
      hilog.info(DOMAIN, TAG, `[LivePhoto] L0: HEIF conversion success, uri=%{public}s`, heifSandboxUri);
    } catch (e) {
      const heifErr: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `[LivePhoto] L0: HEIF conversion failed: %{public}s`, heifErr.message ?? 'unknown');
      return LivePhotoService.createFailureResult(originalFileName, pairedVideo, ErrorCode.HEIF_CONVERSION_FAILED, false);
    }

    const assetExt: string = LivePhotoService.getAssetExtension(imageExt, videoExt, 'heic');
    const apiResult: ProcessResult = await LivePhotoService.callOfficialApi(
      context, heifSandboxUri, videoSandboxUri, originalBaseName, assetExt, originalFileName, pairedVideo
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
    imageSandboxUri: string,
    videoSandboxUri: string,
    originalBaseName: string,
    originalFileName: string,
    pairedVideo: string,
    imageExt: string,
    videoExt: string
  ): Promise<ProcessResult> {
    const assetExt: string = LivePhotoService.getAssetExtension(imageExt, videoExt, imageExt);
    const apiResult: ProcessResult = await LivePhotoService.callOfficialApi(
      context, imageSandboxUri, videoSandboxUri, originalBaseName, assetExt, originalFileName, pairedVideo
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
    imageSandboxUri: string,
    videoSandboxUri: string,
    fileName: string,
    pairedVideo: string,
    originalImageUri: string
  ): Promise<ProcessResult> {
    hilog.info(DOMAIN, TAG, `[LivePhoto] tryL2 start (binary splice fallback)`);
    try {
      const imagePath: string = SandboxHelper.sandboxUriToPath(imageSandboxUri);
      const videoPath: string = SandboxHelper.sandboxUriToPath(videoSandboxUri);
      hilog.info(DOMAIN, TAG, `[LivePhoto] L2: imagePath=%{public}s videoPath=%{public}s`, imagePath, videoPath);

      const imageStat = fs.statSync(imagePath);
      const videoStat = fs.statSync(videoPath);
      hilog.info(DOMAIN, TAG, `[LivePhoto] L2: imageSize=%{public}d videoSize=%{public}d`, imageStat.size, videoStat.size);

      const outputBaseName: string = SandboxHelper.extractBaseName(imageSandboxUri);
      const outputPath: string = `${context.filesDir}/${AppConstants.SANDBOX_DIR}/${outputBaseName}_${Date.now()}.jpg`;
      const outputFile = fs.openSync(outputPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);

      const imageFile = fs.openSync(imagePath, fs.OpenMode.READ_ONLY);
      const imageBuffer = new ArrayBuffer(imageStat.size);
      fs.readSync(imageFile.fd, imageBuffer);
      fs.closeSync(imageFile);
      fs.writeSync(outputFile.fd, imageBuffer);

      const xmpStr: string = LivePhotoService.buildXmpMetadata(imageStat.size, videoStat.size);
      const xmpBuffer: ArrayBuffer = LivePhotoService.stringToArrayBuffer(xmpStr);
      fs.writeSync(outputFile.fd, xmpBuffer);

      const videoFile = fs.openSync(videoPath, fs.OpenMode.READ_ONLY);
      const videoBuffer = new ArrayBuffer(videoStat.size);
      fs.readSync(videoFile.fd, videoBuffer);
      fs.closeSync(videoFile);
      fs.writeSync(outputFile.fd, videoBuffer);

      fs.closeSync(outputFile);

      hilog.info(DOMAIN, TAG, `[LivePhoto] L2: transferring EXIF date to output`);
      await ExifHelper.transferDateTime(imageSandboxUri, outputPath, originalImageUri);

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

  static getAssetExtension(imageExt: string, videoExt: string, fallbackImageExt: string): string {
    if (videoExt === 'mov' || videoExt === 'mp4' || videoExt === '3gp') {
      return fallbackImageExt;
    }
    return fallbackImageExt;
  }

  static async callOfficialApi(
    context: common.UIAbilityContext,
    imageSandboxUri: string,
    videoSandboxUri: string,
    assetBaseName: string,
    assetExtension: string,
    fileName: string,
    pairedVideo: string
  ): Promise<ProcessResult> {
    hilog.info(DOMAIN, TAG, `[LivePhoto] callOfficialApi start, imageUri=%{public}s videoUri=%{public}s title=%{public}s ext=%{public}s`, imageSandboxUri, videoSandboxUri, assetBaseName, assetExtension);
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

      hilog.info(DOMAIN, TAG, `[LivePhoto] adding VIDEO_RESOURCE uri=%{public}s`, videoSandboxUri);
      assetChangeRequest.addResource(
        photoAccessHelper.ResourceType.VIDEO_RESOURCE,
        videoSandboxUri
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

  static buildXmpMetadata(imageSize: number, videoSize: number): string {
    return `<?xpacket begin='' id='W5M0MpCehiHzreSzNTczkc9d'?>
<x:xmpmeta xmlns:x='adobe:ns:meta/'>
  <rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
    <rdf:Description
      xmlns:GCamera='http://ns.google.com/photos/1.0/camera/'
      GCamera:MicroVideo='1'
      GCamera:MicroVideoVersion='1'
      GCamera:MicroVideoOffset='${videoSize}'
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
