export class FilePair {
  baseName: string = '';
  jpgUri: string = '';
  mp4Uri: string = '';
  jpgSize: number = 0;
  mp4Size: number = 0;
  videoDuration: number = 0;
  imageWidth: number = 0;
  imageHeight: number = 0;
  videoWidth: number = 0;
  videoHeight: number = 0;

  static create(
    baseName: string,
    jpgUri: string,
    mp4Uri: string,
    jpgSize: number,
    mp4Size: number,
    videoDuration: number,
    imageWidth: number,
    imageHeight: number,
    videoWidth: number,
    videoHeight: number
  ): FilePair {
    const pair = new FilePair();
    pair.baseName = baseName;
    pair.jpgUri = jpgUri;
    pair.mp4Uri = mp4Uri;
    pair.jpgSize = jpgSize;
    pair.mp4Size = mp4Size;
    pair.videoDuration = videoDuration;
    pair.imageWidth = imageWidth;
    pair.imageHeight = imageHeight;
    pair.videoWidth = videoWidth;
    pair.videoHeight = videoHeight;
    return pair;
  }
}

export class ProcessErrorRecord {
  fileName: string = '';
  pairedVideo: string = '';
  errorCode: number = 0;
  errorMessage: string = '';
  timestamp: number = 0;
  retryable: boolean = false;

  static create(
    fileName: string,
    pairedVideo: string,
    errorCode: number,
    errorMessage: string,
    retryable: boolean
  ): ProcessErrorRecord {
    const record = new ProcessErrorRecord();
    record.fileName = fileName;
    record.pairedVideo = pairedVideo;
    record.errorCode = errorCode;
    record.errorMessage = errorMessage;
    record.timestamp = Date.now();
    record.retryable = retryable;
    return record;
  }
}

export class ProcessResult {
  fileName: string = '';
  pairedVideo: string = '';
  success: boolean = false;
  outputType: string = '';
  errorRecord: ProcessErrorRecord | undefined = undefined;
  livePhotoUri: string = '';
  heifDegraded: boolean = false;

  static createSuccess(
    fileName: string,
    pairedVideo: string,
    outputType: string,
    livePhotoUri: string,
    heifDegraded: boolean
  ): ProcessResult {
    const result = new ProcessResult();
    result.fileName = fileName;
    result.pairedVideo = pairedVideo;
    result.success = true;
    result.outputType = outputType;
    result.livePhotoUri = livePhotoUri;
    result.heifDegraded = heifDegraded;
    return result;
  }

  static createFailure(
    fileName: string,
    pairedVideo: string,
    errorRecord: ProcessErrorRecord
  ): ProcessResult {
    const result = new ProcessResult();
    result.fileName = fileName;
    result.pairedVideo = pairedVideo;
    result.success = false;
    result.errorRecord = errorRecord;
    return result;
  }

  static createSkipped(
    fileName: string,
    reason: string
  ): ProcessResult {
    const result = new ProcessResult();
    result.fileName = fileName;
    result.pairedVideo = '';
    result.success = false;
    result.outputType = 'skipped';
    const errorRecord = new ProcessErrorRecord();
    errorRecord.fileName = fileName;
    errorRecord.errorCode = 0;
    errorRecord.errorMessage = reason;
    errorRecord.timestamp = Date.now();
    errorRecord.retryable = false;
    result.errorRecord = errorRecord;
    return result;
  }
}
