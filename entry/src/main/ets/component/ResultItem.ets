import { ProcessResult, ProcessErrorRecord } from '../model/FilePair';
import { ErrorCode } from '../constants/ErrorCode';

@Component
export struct ResultItem {
  @Prop result: ProcessResult = new ProcessResult();
  @Prop isExpanded: boolean = false;
  onRetry: () => void = () => {};
  onToggleExpand: () => void = () => {};

  build() {
    Column() {
      Row() {
        if (this.result.success) {
          Text('✓')
            .fontSize(16)
            .fontColor('#4CAF50')
            .margin({ right: 8 })
        } else if (this.result.outputType === 'skipped') {
          Text('—')
            .fontSize(16)
            .fontColor('#999999')
            .margin({ right: 8 })
        } else {
          Text('✗')
            .fontSize(16)
            .fontColor('#F44336')
            .margin({ right: 8 })
        }

        Column() {
          Text(this.result.fileName)
            .fontSize(14)
            .fontColor('#333333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.result.success && this.result.outputType.length > 0) {
            Row() {
              Text(`输出: ${this.result.outputType}`)
                .fontSize(12)
                .fontColor('#666666')

              if (this.result.heifDegraded) {
                Text(' (封面已降级为JPG)')
                  .fontSize(12)
                  .fontColor('#FF9800')
              }
            }
            .margin({ top: 2 })
          }

          if (!this.result.success && this.result.outputType !== 'skipped' && this.result.errorRecord !== undefined) {
            Text(`错误: ${this.result.errorRecord.errorMessage}`)
              .fontSize(12)
              .fontColor('#F44336')
              .maxLines(this.isExpanded ? 10 : 1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (!this.result.success && this.result.outputType !== 'skipped' && this.result.errorRecord !== undefined) {
          if (this.result.errorRecord.retryable) {
            Button('重试')
              .fontSize(12)
              .height(28)
              .backgroundColor('#4CAF50')
              .fontColor(Color.White)
              .onClick(() => {
                this.onRetry();
              })
          } else {
            Button('不可重试')
              .fontSize(12)
              .height(28)
              .backgroundColor('#E0E0E0')
              .fontColor('#999999')
              .enabled(false)
          }
        }

        if (!this.result.success && this.result.outputType !== 'skipped' && this.result.errorRecord !== undefined) {
          Text(this.isExpanded ? '收起' : '详情')
            .fontSize(12)
            .fontColor('#2196F3')
            .margin({ left: 8 })
            .onClick(() => {
              this.onToggleExpand();
            })
        }
      }
      .width('100%')
      .padding(12)

      if (this.isExpanded && !this.result.success && this.result.errorRecord !== undefined) {
        Column() {
          Row() {
            Text('错误码: ')
              .fontSize(12)
              .fontColor('#999999')
            Text(`${this.result.errorRecord.errorCode}`)
              .fontSize(12)
              .fontColor('#333333')
          }
          .margin({ top: 4 })

          Row() {
            Text('错误原因: ')
              .fontSize(12)
              .fontColor('#999999')
            Text(this.result.errorRecord.errorMessage)
              .fontSize(12)
              .fontColor('#333333')
              .layoutWeight(1)
          }
          .margin({ top: 4 })

          Row() {
            Text('配对视频: ')
              .fontSize(12)
              .fontColor('#999999')
            Text(this.result.errorRecord.pairedVideo)
              .fontSize(12)
              .fontColor('#333333')
          }
          .margin({ top: 4 })
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 12 })
      }
    }
    .width('100%')
    .borderRadius(8)
    .backgroundColor('#FFFFFF')
    .margin({ bottom: 8 })
    .shadow({ radius: 1, color: '#0F000000', offsetY: 1 })
  }
}
