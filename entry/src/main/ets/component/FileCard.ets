@Component
export struct FileCard {
  @Prop fileLabel: string = '';
  @Prop fileName: string = '';
  @Prop fileSize: string = '';
  @Prop fileDuration: string = '';
  @Prop isSelected: boolean = false;
  @Prop sameNameHint: string = '';
  onFileClick: () => void = () => {};

  build() {
    Column() {
      Text(this.fileLabel)
        .fontSize(14)
        .fontColor('#999999')
        .margin({ bottom: 8 })

      if (this.isSelected) {
        Column() {
          Row() {
            Text(this.fileName)
              .fontSize(14)
              .fontColor('#333333')
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.fileSize)
              .fontSize(12)
              .fontColor('#999999')
          }
          .width('100%')

          if (this.fileDuration.length > 0) {
            Text(`时长: ${this.fileDuration}`)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ top: 4 })
          }

          if (this.sameNameHint.length > 0) {
            Row() {
              Text(this.sameNameHint)
                .fontSize(12)
                .fontColor('#4CAF50')
            }
            .margin({ top: 4 })
          }
        }
        .width('100%')
        .padding(12)
        .borderRadius(8)
        .backgroundColor('#F5F5F5')
      } else {
        Row() {
          Text('点击选择')
            .fontSize(14)
            .fontColor('#CCCCCC')
        }
        .width('100%')
        .height(48)
        .justifyContent(FlexAlign.Center)
        .borderRadius(8)
        .border({ width: 1, color: '#E0E0E0', style: BorderStyle.Dashed })
      }
    }
    .width('100%')
    .onClick(() => {
      this.onFileClick();
    })
  }
}
