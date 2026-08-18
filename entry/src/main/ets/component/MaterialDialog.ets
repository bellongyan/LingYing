@Component
export struct MaterialDialog {
  @Prop visible: boolean = false;
  onDeleteOriginals: () => void = () => {};
  onKeepOriginals: () => void = () => {};

  show(): void {
    this.getUIContext().showAlertDialog({
      title: '原始素材处理',
      message: '合成动态照片后，是否删除原始图片和视频文件？\n\n选择「保留」：原始文件不做任何变动\n选择「删除」：合成成功后将原文件移入系统回收站（可恢复）',
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '保留原始素材',
        action: () => {
          this.onKeepOriginals();
        }
      },
      secondaryButton: {
        value: '删除原始素材',
        action: () => {
          this.onDeleteOriginals();
        }
      }
    });
  }

  build() {
  }
}
