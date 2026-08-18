import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ProgressPanel } from '../component/ProgressPanel';
import { SandboxHelper } from '../service/SandboxHelper';
import { LivePhotoService } from '../service/LivePhotoService';
import { FilePair, ProcessResult, ProcessErrorRecord } from '../model/FilePair';
import { ErrorCode } from '../constants/ErrorCode';
import { ResultDataHolder } from '../model/RouteParams';

@Entry
@Component
struct BatchCompose {
  @State selectedUris: string[] = [];
  @State filePairs: FilePair[] = [];
  @State unpairedCount: number = 0;
  @State isScanning: boolean = false;
  @State isComposing: boolean = false;
  @State showSaveButton: boolean = false;
  @State total: number = 0;
  @State completed: number = 0;
  @State succeeded: number = 0;
  @State failed: number = 0;
  @State results: ProcessResult[] = [];
  @State errorMessage: string = '';
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

        Text('批量合成')
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
          if (this.selectedUris.length === 0 && this.filePairs.length === 0) {
            Column() {
              Text('选择多张图片和视频，自动配对同名文件')
                .fontSize(14)
                .fontColor('#999999')
                .margin({ bottom: 8 })
              Text('提示：请同时选择 JPG 图片和 MP4 视频\n同名文件将自动配对合成')
                .fontSize(12)
                .fontColor('#CCCCCC')
                .margin({ bottom: 16 })
                .textAlign(TextAlign.Center)

              Button('选择图片和视频')
                .width('100%')
                .height(48)
                .fontSize(16)
                .backgroundColor('#2196F3')
                .fontColor(Color.White)
                .onClick(() => {
                  this.pickMediaFiles();
                })
            }
            .width('100%')
            .padding(24)
            .borderRadius(12)
            .backgroundColor('#FFFFFF')
            .alignItems(HorizontalAlign.Center)
          }

          Column() {
            Text('温馨提示：由于系统权限限制，合成后需在相册中手动删除原始 JPG 和 MP4 素材')
              .fontSize(12)
              .fontColor('#999999')
          }
          .width('100%')
          .padding(12)
          .borderRadius(8)
          .backgroundColor('#FFF8E1')

          if (this.isScanning) {
            Row() {
              LoadingProgress()
                .width(24)
                .height(24)
                .color('#4CAF50')
              Text('配对文件中...')
                .fontSize(14)
                .fontColor('#666666')
                .margin({ left: 8 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding(16)
          }

          if (this.filePairs.length > 0 && !this.isComposing) {
            Column() {
              Text(`配对结果：共找到 ${this.filePairs.length} 对同名文件`)
                .fontSize(14)
                .fontColor('#333333')
                .fontWeight(FontWeight.Medium)

              if (this.unpairedCount > 0) {
                Text(`无配对文件：${this.unpairedCount} 个（将跳过）`)
                  .fontSize(12)
                  .fontColor('#FF9800')
                  .margin({ top: 4 })
              }

              ForEach(this.filePairs, (pair: FilePair, index: number) => {
                Row() {
                  Text(`${pair.baseName}.jpg + ${pair.baseName}.mp4`)
                    .fontSize(13)
                    .fontColor('#666666')
                    .layoutWeight(1)
                }
                .width('100%')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              }, (pair: FilePair, index: number) => `${pair.baseName}_${index}`)
            }
            .width('100%')
            .padding(16)
            .borderRadius(12)
            .backgroundColor('#FFFFFF')
          }

          if (this.isComposing) {
            ProgressPanel({
              total: this.total,
              completed: this.completed,
              succeeded: this.succeeded,
              failed: this.failed
            })
          }

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor('#F44336')
              .width('100%')
              .padding(12)
              .borderRadius(8)
              .backgroundColor('#FFEBEE')
          }

          if (this.showSaveButton) {
            SaveButton({ icon: SaveIconStyle.LINES, text: SaveDescription.SAVE_TO_GALLERY, buttonType: ButtonType.Capsule })
              .onClick((event: ClickEvent, result: SaveButtonOnClickResult, error?: BusinessError<void>) => {
                if (result === SaveButtonOnClickResult.SUCCESS) {
                  this.executeBatchCompose();
                } else {
                  this.errorMessage = '保存授权失败，请重试';
                }
              })
          }

          if (this.filePairs.length > 0 && !this.isComposing && !this.showSaveButton && this.results.length === 0) {
            Row({ space: 12 }) {
              Button('重新选择')
                .fontSize(14)
                .height(44)
                .layoutWeight(1)
                .backgroundColor('#E0E0E0')
                .fontColor('#666666')
                .onClick(() => {
                  this.filePairs = [];
                  this.selectedUris = [];
                  this.unpairedCount = 0;
                  this.results = [];
                  this.errorMessage = '';
                })

              Button('开始批量合成')
                .fontSize(14)
                .height(44)
                .layoutWeight(1)
                .backgroundColor('#4CAF50')
                .fontColor(Color.White)
                .onClick(() => {
                  this.showSaveButton = true;
                })
            }
            .width('100%')
          }

          if (this.selectedUris.length > 0 && this.filePairs.length === 0 && !this.isScanning) {
            Column() {
              Text('未找到可配对的同名 JPG+MP4 文件')
                .fontSize(14)
                .fontColor('#999999')
              Text('请确保同时选择了同名的 .jpg 和 .mp4 文件')
                .fontSize(12)
                .fontColor('#CCCCCC')
                .margin({ top: 4 })

              Button('重新选择')
                .fontSize(14)
                .margin({ top: 12 })
                .backgroundColor('#2196F3')
                .fontColor(Color.White)
                .onClick(() => {
                  this.selectedUris = [];
                  this.filePairs = [];
                  this.unpairedCount = 0;
                  this.errorMessage = '';
                  this.pickMediaFiles();
                })
            }
            .width('100%')
            .padding(24)
            .borderRadius(12)
            .backgroundColor('#FFFFFF')
            .alignItems(HorizontalAlign.Center)
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

  private async pickMediaFiles(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE;
      options.maxSelectNumber = 500;
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(options);
      if (result.photoUris.length > 0) {
        this.selectedUris = result.photoUris;
        this.pairSelectedFiles();
      }
    } catch (e) {
      this.errorMessage = '选择文件失败';
    }
  }

  private async pairSelectedFiles(): Promise<void> {
    this.isScanning = true;
    this.filePairs = [];
    this.unpairedCount = 0;
    this.errorMessage = '';

    const imageMap: Record<string, string> = {};
    const videoMap: Record<string, string[]> = {};
    const imageExtensions: string[] = ['jpg', 'jpeg'];
    const videoExtensions: string[] = ['mp4'];

    for (let i = 0; i < this.selectedUris.length; i++) {
      const uri: string = this.selectedUris[i];
      const ext: string = SandboxHelper.extractExtension(uri);
      const baseName: string = SandboxHelper.extractBaseName(uri);

      if (imageExtensions.indexOf(ext) >= 0) {
        imageMap[baseName.toLowerCase()] = uri;
      } else if (videoExtensions.indexOf(ext) >= 0) {
        if (videoMap[baseName.toLowerCase()] === undefined) {
          videoMap[baseName.toLowerCase()] = [];
        }
        videoMap[baseName.toLowerCase()].push(uri);
      }
    }

    const imageKeys: string[] = Object.keys(imageMap);
    const pairedKeys: Record<string, boolean> = {};

    for (let i = 0; i < imageKeys.length; i++) {
      const key: string = imageKeys[i];
      const imageUri: string = imageMap[key];
      const videoUris: string[] = videoMap[key] ?? [];

      if (videoUris.length >= 1) {
        const pair: FilePair = FilePair.create(
          key,
          imageUri,
          videoUris[0],
          SandboxHelper.getFileSize(imageUri),
          SandboxHelper.getFileSize(videoUris[0]),
          0, 0, 0, 0, 0
        );
        this.filePairs.push(pair);
        pairedKeys[key] = true;
      }
    }

    const videoKeys: string[] = Object.keys(videoMap);
    for (let i = 0; i < videoKeys.length; i++) {
      if (pairedKeys[videoKeys[i]] !== true && imageMap[videoKeys[i]] === undefined) {
        this.unpairedCount += videoMap[videoKeys[i]].length;
      }
    }

    this.isScanning = false;
  }

  private async executeBatchCompose(): Promise<void> {
    this.isComposing = true;
    this.showSaveButton = false;
    this.total = this.filePairs.length;
    this.completed = 0;
    this.succeeded = 0;
    this.failed = 0;
    this.results = [];
    this.errorMessage = '';

    for (let i = 0; i < this.filePairs.length; i++) {
      const pair: FilePair = this.filePairs[i];

      try {
        const jpgSandboxUri: string = await SandboxHelper.copyToSandbox(this.context, pair.jpgUri);
        const mp4SandboxUri: string = await SandboxHelper.copyToSandbox(this.context, pair.mp4Uri);

        const result: ProcessResult = await LivePhotoService.composeLivePhoto(
          this.context,
          jpgSandboxUri,
          mp4SandboxUri,
          pair.jpgUri,
          pair.mp4Uri
        );

        this.results.push(result);

        if (result.success) {
          this.succeeded++;
        } else {
          this.failed++;
        }
      } catch (e) {
        const err = e as BusinessError;
        const errMsg: string = err.message ?? '未知错误';
        const failResult: ProcessResult = ProcessResult.createFailure(
          pair.baseName + '.jpg',
          pair.baseName + '.mp4',
          ProcessErrorRecord.create(
            pair.baseName + '.jpg',
            pair.baseName + '.mp4',
            ErrorCode.OFFICIAL_API_FAILED,
            errMsg,
            true
          )
        );
        this.results.push(failResult);
        this.failed++;
      } finally {
        this.completed++;
        SandboxHelper.cleanSandbox(this.context);
      }
    }

    this.isComposing = false;

    ResultDataHolder.set(this.results, true);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/ResultPage' });
  }
}
