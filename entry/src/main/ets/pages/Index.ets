@Entry
@Component
struct Index {
  build() {
    Column() {
      Row() {
        Text('灵影')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Text('本地处理')
          .fontSize(10)
          .fontColor('#4CAF50')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
          .border({ width: 1, color: '#4CAF50' })
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })

      Text('动态照片合成工具')
        .fontSize(14)
        .fontColor('#999999')
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 24 })

      Column({ space: 16 }) {
        Column() {
          Row() {
            Column() {
              Text('📷')
                .fontSize(36)
              Text('手动合成')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')
                .margin({ top: 8 })
              Text('选择一张图片和一个视频\n合成为动态照片')
                .fontSize(12)
                .fontColor('#999999')
                .margin({ top: 4 })
                .textAlign(TextAlign.Center)
            }
            .alignItems(HorizontalAlign.Center)
            .padding(24)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 4, color: '#1A000000', offsetY: 2 })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/ManualCompose' });
        })

        Column() {
          Row() {
            Column() {
              Text('📁')
                .fontSize(36)
              Text('批量合成')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')
                .margin({ top: 8 })
              Text('选择多张图片和视频\n自动配对同名文件批量合成')
                .fontSize(12)
                .fontColor('#999999')
                .margin({ top: 4 })
                .textAlign(TextAlign.Center)
            }
            .alignItems(HorizontalAlign.Center)
            .padding(24)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 4, color: '#1A000000', offsetY: 2 })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/BatchCompose' });
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })

      Blank()

      Text('所有处理均在本地完成，不上传任何数据')
        .fontSize(12)
        .fontColor('#CCCCCC')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
