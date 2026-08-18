import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ResultItem } from '../component/ResultItem';
import { ProcessResult } from '../model/FilePair';
import { ResultDataHolder } from '../model/RouteParams';
import { MovingPhotoService } from '../service/MovingPhotoService';
import { SandboxHelper } from '../service/SandboxHelper';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG: string = 'LingYing';
const DOMAIN: number = 0xFF00;

@Entry
@Component
struct ResultPage {
  @State results: ProcessResult[] = [];
  @State isBatchMode: boolean = false;
  @State currentTab: number = 0;
  @State expandedItems: Record<string, boolean> = {};
  @State successCount: number = 0;
  @State failedCount: number = 0;
  @State skippedCount: number = 0;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, `[ResultPage] aboutToAppear start`);
    this.results = ResultDataHolder.getResults();
    this.isBatchMode = ResultDataHolder.getIsBatchMode();
    hilog.info(DOMAIN, TAG, `[ResultPage] results.length=%{public}d isBatchMode=%{public}s`, this.results.length, `${this.isBatchMode}`);
    for (let i = 0; i < this.results.length; i++) {
      hilog.info(DOMAIN, TAG, `[ResultPage] results[%{public}d]: success=%{public}s outputType=%{public}s`, i, `${this.results[i].success}`, this.results[i].outputType);
    }
    this.recalculateCounts();
    hilog.info(DOMAIN, TAG, `[ResultPage] counts: success=%{public}d failed=%{public}d skipped=%{public}d`, this.successCount, this.failedCount, this.skippedCount);
  }

  private recalculateCounts(): void {
    let sCount: number = 0;
    let fCount: number = 0;
    let kCount: number = 0;
    for (let i = 0; i < this.results.length; i++) {
      if (this.results[i].success) {
        sCount++;
      } else if (this.results[i].outputType === 'skipped') {
        kCount++;
      } else {
        fCount++;
      }
    }
    this.successCount = sCount;
    this.failedCount = fCount;
    this.skippedCount = kCount;
  }

  private getFilteredResults(tab: number): ProcessResult[] {
    const list: ProcessResult[] = [];
    for (let i = 0; i < this.results.length; i++) {
      if (tab === 0 && this.results[i].success) {
        list.push(this.results[i]);
      } else if (tab === 1 && !this.results[i].success && this.results[i].outputType !== 'skipped') {
        list.push(this.results[i]);
      } else if (tab === 2 && !this.results[i].success && this.results[i].outputType === 'skipped') {
        list.push(this.results[i]);
      }
    }
    return list;
  }

  build() {
    Column() {
      Row() {
        Text('返回')
          .fontSize(16)
          .fontColor('#2196F3')
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })

        Text('处理结果')
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

      Row() {
        Text(`成功 ${this.successCount}`)
          .fontSize(14)
          .fontColor(this.currentTab === 0 ? '#4CAF50' : '#999999')
          .fontWeight(this.currentTab === 0 ? FontWeight.Medium : FontWeight.Normal)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(20)
          .backgroundColor(this.currentTab === 0 ? '#E8F5E9' : Color.Transparent)
          .onClick(() => {
            this.currentTab = 0;
          })

        Text(`失败 ${this.failedCount}`)
          .fontSize(14)
          .fontColor(this.currentTab === 1 ? '#F44336' : '#999999')
          .fontWeight(this.currentTab === 1 ? FontWeight.Medium : FontWeight.Normal)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(20)
          .backgroundColor(this.currentTab === 1 ? '#FFEBEE' : Color.Transparent)
          .onClick(() => {
            this.currentTab = 1;
          })

        if (this.isBatchMode) {
          Text(`跳过 ${this.skippedCount}`)
            .fontSize(14)
            .fontColor(this.currentTab === 2 ? '#FF9800' : '#999999')
            .fontWeight(this.currentTab === 2 ? FontWeight.Medium : FontWeight.Normal)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .borderRadius(20)
            .backgroundColor(this.currentTab === 2 ? '#FFF3E0' : Color.Transparent)
            .onClick(() => {
              this.currentTab = 2;
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      Scroll() {
        Column({ space: 8 }) {
          if (this.currentTab === 0) {
            if (this.successCount === 0) {
              Column() {
                Text('暂无成功记录')
                  .fontSize(14)
                  .fontColor('#CCCCCC')
              }
              .width('100%')
              .padding(40)
              .alignItems(HorizontalAlign.Center)
            }
            ForEach(this.getFilteredResults(0), (item: ProcessResult, index: number) => {
              ResultItem({
                result: item,
                isExpanded: this.expandedItems[`s_${index}`] ?? false,
                onRetry: () => {},
                onToggleExpand: () => {
                  const key: string = `s_${index}`;
                  if (this.expandedItems[key] === true) {
                    this.expandedItems[key] = false;
                  } else {
                    this.expandedItems[key] = true;
                  }
                }
              })
            }, (item: ProcessResult, index: number) => `success_${index}`)
          }

          if (this.currentTab === 1) {
            if (this.failedCount === 0) {
              Column() {
                Text('暂无失败记录')
                  .fontSize(14)
                  .fontColor('#CCCCCC')
              }
              .width('100%')
              .padding(40)
              .alignItems(HorizontalAlign.Center)
            }
            ForEach(this.getFilteredResults(1), (item: ProcessResult, index: number) => {
              ResultItem({
                result: item,
                isExpanded: this.expandedItems[`f_${index}`] ?? false,
                onRetry: () => {
                  this.retryItem(item);
                },
                onToggleExpand: () => {
                  const key: string = `f_${index}`;
                  if (this.expandedItems[key] === true) {
                    this.expandedItems[key] = false;
                  } else {
                    this.expandedItems[key] = true;
                  }
                }
              })
            }, (item: ProcessResult, index: number) => `failed_${index}`)
          }

          if (this.currentTab === 2 && this.isBatchMode) {
            if (this.skippedCount === 0) {
              Column() {
                Text('暂无跳过记录')
                  .fontSize(14)
                  .fontColor('#CCCCCC')
              }
              .width('100%')
              .padding(40)
              .alignItems(HorizontalAlign.Center)
            }
            ForEach(this.getFilteredResults(2), (item: ProcessResult, index: number) => {
              ResultItem({
                result: item,
                isExpanded: false,
                onRetry: () => {},
                onToggleExpand: () => {}
              })
            }, (item: ProcessResult, index: number) => `skipped_${index}`)
          }
        }
        .padding({ left: 20, right: 20, top: 8, bottom: 20 })
      }
      .layoutWeight(1)

      Button('返回首页')
        .width('90%')
        .height(48)
        .fontSize(16)
        .backgroundColor('#4CAF50')
        .fontColor(Color.White)
        .margin({ bottom: 24 })
        .onClick(() => {
          this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  private async retryItem(item: ProcessResult): Promise<void> {
    if (item.errorRecord === undefined) {
      return;
    }
    if (!item.errorRecord.retryable) {
      return;
    }
    try {
      const jpgSandboxUri: string = await SandboxHelper.copyToSandbox(this.context, item.fileName);
      const mp4SandboxUri: string = await SandboxHelper.copyToSandbox(this.context, item.pairedVideo);

      const result: ProcessResult = await MovingPhotoService.composeMovingPhoto(
        this.context,
        jpgSandboxUri,
        mp4SandboxUri,
        item.fileName,
        item.pairedVideo
      );

      for (let i = 0; i < this.results.length; i++) {
        if (this.results[i].fileName === item.fileName) {
          this.results[i] = result;
          break;
        }
      }
      this.recalculateCounts();

      SandboxHelper.cleanSandbox(this.context);
    } catch (e) {
      const err = e as BusinessError;
    }
  }
}
