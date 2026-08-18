@Component
export struct ProgressPanel {
  @Prop total: number = 0;
  @Prop completed: number = 0;
  @Prop succeeded: number = 0;
  @Prop failed: number = 0;

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('处理进度')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
      }
      .width('100%')

      Progress({ value: this.completed, total: this.total, type: ProgressType.Linear })
        .width('100%')
        .color('#4CAF50')
        .backgroundColor('#E0E0E0')

      Row() {
        Text(`已完成: ${this.completed}/${this.total}`)
          .fontSize(14)
          .fontColor('#666666')
          .layoutWeight(1)

        Text(`成功: ${this.succeeded}`)
          .fontSize(14)
          .fontColor('#4CAF50')
          .margin({ right: 16 })

        Text(`失败: ${this.failed}`)
          .fontSize(14)
          .fontColor('#F44336')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 2, color: '#1A000000', offsetY: 1 })
  }
}
