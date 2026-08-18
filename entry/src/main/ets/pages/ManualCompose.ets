import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FileCard } from '../component/FileCard';
import { FileValidator } from '../service/FileValidator';
import { MovingPhotoService } from '../service/MovingPhotoService';
import { SandboxHelper } from '../service/SandboxHelper';
import { ProcessResult } from '../model/FilePair';
import { ErrorCode } from '../constants/ErrorCode';
import { ResultDataHolder } from '../model/RouteParams';

const TAG: string = 'LingYing';
const DOMAIN: number = 0xFF00;

@Entry
@Component
struct ManualCompose {
  @State imageUri: string = '';
  @State videoUri: string = '';
  @State imageFileName: string = '';
  @State videoFileName: string = '';
  @State imageSize: string = '';
  @State videoSize: string = '';
  @State videoDuration: string = '';
  @State sameNameHint: string = '';
  @State errorMessage: string = '';
  @State isComposing: boolean = false;
  @State movingPhotoUri: string = '';
  @State showSaveButton: boolean = false;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  build() {
    Column() {
      Row() {
        Text('返回')
          .fontSize(16)
          .fontColor('#2196F3')
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })

        Text('手动合成')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('  ')
          .fontSize(16)
          .width(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 16 }) {
          FileCard({
            fileLabel: '选择图片 (JPG/JPEG)',
            fileName: this.imageFileName,
            fileSize: this.imageSize,
            fileDuration: '',
            isSelected: this.imageUri.length > 0,
            sameNameHint: this.sameNameHint,
            onFileClick: () => {
              this.pickImage();
            }
          })

          FileCard({
            fileLabel: '选择视频 (MP4)',
            fileName: this.videoFileName,
            fileSize: this.videoSize,
            fileDuration: this.videoDuration,
            isSelected: this.videoUri.length > 0,
            sameNameHint: '',
            onFileClick: () => {
              this.pickVideo();
            }
          })

          Column() {
            Text('温馨提示：由于系统权限限制，合成后需在相册中手动删除原始 JPG 和 MP4 素材')
              .fontSize(12)
              .fontColor('#999999')
          }
          .width('100%')
          .padding(12)
          .borderRadius(8)
          .backgroundColor('#FFF8E1')

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor('#F44336')
              .width('100%')
              .padding(12)
              .borderRadius(8)
              .backgroundColor('#FFEBEE')
          }

          if (this.isComposing) {
            Row() {
              LoadingProgress()
                .width(24)
                .height(24)
                .color('#4CAF50')
              Text('合成中...')
                .fontSize(14)
                .fontColor('#666666')
                .margin({ left: 8 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding(16)
          }

          if (this.movingPhotoUri.length > 0) {
            Column() {
              Text('合成成功!')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#4CAF50')
                .margin({ bottom: 12 })
              Text('动态照片已保存到系统相册，可在相册中长按播放')
                .fontSize(14)
                .fontColor('#666666')
            }
            .width('100%')
            .padding(16)
            .borderRadius(8)
            .backgroundColor('#E8F5E9')
            .alignItems(HorizontalAlign.Center)
          }

          if (this.showSaveButton && this.movingPhotoUri.length === 0 && !this.isComposing) {
            Column({ space: 12 }) {
              Text('点击下方按钮保存动态照片到相册')
                .fontSize(14)
                .fontColor('#666666')
                .width('100%')
                .textAlign(TextAlign.Center)

              SaveButton({
                icon: SaveIconStyle.LINES,
                text: SaveDescription.SAVE_TO_GALLERY,
                buttonType: ButtonType.Capsule
              })
                .onClick((event: ClickEvent, result: SaveButtonOnClickResult, error?: BusinessError<void>) => {
                  if (result === SaveButtonOnClickResult.SUCCESS) {
                    this.executeCompose();
                  } else {
                    this.errorMessage = '保存授权失败，请重试';
                  }
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }

          if (!this.showSaveButton && this.movingPhotoUri.length === 0 && !this.isComposing) {
            Button('合成动态照片')
              .width('100%')
              .height(48)
              .fontSize(16)
              .backgroundColor('#4CAF50')
              .fontColor(Color.White)
              .enabled(this.imageUri.length > 0 && this.videoUri.length > 0)
              .onClick(() => {
                this.validateAndCompose();
              })
          }
        }
        .padding({ left: 20, right: 20, top: 8, bottom: 20 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  private async pickImage(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(options);
      if (result.photoUris.length > 0) {
        this.imageUri = result.photoUris[0];
        this.imageFileName = SandboxHelper.extractFileName(this.imageUri);
        try {
          const size: number = SandboxHelper.getFileSize(this.imageUri);
          this.imageSize = this.formatFileSize(size);
        } catch (e) {
          this.imageSize = '';
        }
        this.checkSameName();
        this.errorMessage = '';
        this.showSaveButton = false;
        this.movingPhotoUri = '';
      }
    } catch (e) {
      this.errorMessage = '选择图片失败';
    }
  }

  private async pickVideo(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE;
      options.maxSelectNumber = 1;
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(options);
      if (result.photoUris.length > 0) {
        this.videoUri = result.photoUris[0];
        this.videoFileName = SandboxHelper.extractFileName(this.videoUri);
        try {
          const size: number = SandboxHelper.getFileSize(this.videoUri);
          this.videoSize = this.formatFileSize(size);
          const duration: number = await FileValidator.getVideoDuration(this.videoUri);
          this.videoDuration = `${duration.toFixed(1)}秒`;
        } catch (e) {
          this.videoSize = '';
          this.videoDuration = '';
        }
        this.checkSameName();
        this.errorMessage = '';
        this.showSaveButton = false;
        this.movingPhotoUri = '';
      }
    } catch (e) {
      this.errorMessage = '选择视频失败';
    }
  }

  private checkSameName(): void {
    if (this.imageUri.length > 0 && this.videoUri.length > 0) {
      const imgBase: string = SandboxHelper.extractBaseName(this.imageUri);
      const vidBase: string = SandboxHelper.extractBaseName(this.videoUri);
      if (imgBase.toLowerCase() === vidBase.toLowerCase()) {
        this.sameNameHint = '已匹配到同名对';
      } else {
        this.sameNameHint = '文件名不一致，仍可合成';
      }
    }
  }

  private async validateAndCompose(): Promise<void> {
    this.errorMessage = '';

    try {
      const imageError: number = await FileValidator.validateImage(this.context, this.imageUri);
      if (imageError !== 0) {
        this.errorMessage = ErrorCode.getMessage(imageError);
        return;
      }

      const videoError: number = await FileValidator.validateVideo(this.context, this.videoUri);
      if (videoError !== 0) {
        this.errorMessage = ErrorCode.getMessage(videoError);
        return;
      }

      const ratioError: number = await FileValidator.validateAspectRatio(this.imageUri, this.videoUri);
      if (ratioError !== 0) {
        this.errorMessage = ErrorCode.getMessage(ratioError);
      }
    } catch (e) {
      this.errorMessage = '文件校验失败，请重新选择文件';
      return;
    }

    this.showSaveButton = true;
  }

  private async executeCompose(): Promise<void> {
    this.isComposing = true;
    this.showSaveButton = false;
    this.errorMessage = '';
    hilog.info(DOMAIN, TAG, `[ManualCompose] executeCompose start, imageUri=%{public}s videoUri=%{public}s`, this.imageUri, this.videoUri);

    try {
      hilog.info(DOMAIN, TAG, `[ManualCompose] copying JPG to sandbox...`);
      const jpgSandboxUri: string = await SandboxHelper.copyToSandbox(this.context, this.imageUri);
      hilog.info(DOMAIN, TAG, `[ManualCompose] copying MP4 to sandbox...`);
      const mp4SandboxUri: string = await SandboxHelper.copyToSandbox(this.context, this.videoUri);
      hilog.info(DOMAIN, TAG, `[ManualCompose] sandbox copy done, jpgUri=%{public}s mp4Uri=%{public}s`, jpgSandboxUri, mp4SandboxUri);

      hilog.info(DOMAIN, TAG, `[ManualCompose] calling composeMovingPhoto...`);
      const result: ProcessResult = await MovingPhotoService.composeMovingPhoto(
        this.context,
        jpgSandboxUri,
        mp4SandboxUri,
        this.imageUri,
        this.videoUri
      );
      hilog.info(DOMAIN, TAG, `[ManualCompose] composeMovingPhoto done, success=%{public}s`, `${result.success}`);

      if (result.success) {
        this.movingPhotoUri = result.movingPhotoUri;
        this.errorMessage = '';
        hilog.info(DOMAIN, TAG, `[ManualCompose] movingPhotoUri=%{public}s`, result.movingPhotoUri);
      } else {
        if (result.errorRecord !== undefined) {
          this.errorMessage = result.errorRecord.errorMessage;
          hilog.error(DOMAIN, TAG, `[ManualCompose] error: %{public}s`, result.errorRecord.errorMessage);
        } else {
          this.errorMessage = '合成失败';
        }
      }

      hilog.info(DOMAIN, TAG, `[ManualCompose] setting ResultDataHolder and navigating to ResultPage`);
      ResultDataHolder.set([result], false);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ResultPage' });
    } catch (e) {
      const err = e as BusinessError;
      const errMsg: string = err.message ?? '未知错误';
      hilog.error(DOMAIN, TAG, `[ManualCompose] executeCompose exception: %{public}s`, errMsg);
      this.errorMessage = `合成失败: ${errMsg}`;
    } finally {
      this.isComposing = false;
      SandboxHelper.cleanSandbox(this.context);
    }
  }

  private formatFileSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes}B`;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)}KB`;
    }
    return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
  }
}
