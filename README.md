# 灵影 (LingYing)

将 JPG 图片与同名 MP4 视频合成为 HarmonyOS 动态照片（Live Photo）的本地工具应用。

## 功能

- **手动合成**：选择单组 JPG + MP4，一键生成动态照片
- **批量合成**：多选图片和视频，自动按文件名配对，批量输出
- **三级降级策略**：L0（HEIF 封面 + 官方 API）→ L1（JPG 封面 + 官方 API）→ L2（二进制拼接），最大化合成成功率
- **EXIF 日期保留**：自动读取原始 JPG 的拍摄日期（`DateTimeOriginal`）并写入输出文件，确保相册按原始拍摄时间排序
- **文件名保留**：输出文件沿用原始 JPG 的基础文件名
- **安全控件保存**：通过 `SaveButton` 安全控件获取临时授权写入媒体库，无需申请写入权限

## 技术规格

| 项目 | 说明 |
|---|---|
| 开发语言 | ArkTS |
| 目标 SDK | HarmonyOS SDK 26.0.0 (API 14) |
| 最低兼容 | HarmonyOS 5.0+ |
| 应用包名 | `com.longyan.lingying` |
| 声明权限 | `ohos.permission.READ_IMAGEVIDEO`（读取媒体库） |

## 项目结构

```
entry/src/main/ets/
├── model/
│   ├── FilePair.ets          # 文件配对模型 & 合成结果
│   ├── ComposeState.ets      # 合成状态枚举
│   └── RouteParams.ets       # 页面间传参 & ResultDataHolder
├── service/
│   ├── SandboxHelper.ets     # 沙箱文件操作（拷贝、URI 转换、清理）
│   ├── FileValidator.ets     # 文件校验（格式、大小、时长、分辨率）
│   ├── ExifHelper.ets        # EXIF 日期读取/写入/迁移
│   ├── HeifService.ets       # JPG → HEIF 转换
│   ├── LivePhotoService.ets  # 核心合成逻辑（L0/L1/L2 降级）
│   └── FilePairScanner.ets   # 文件夹扫描 & 自动配对
├── component/
│   ├── MaterialDialog.ets    # 素材信息对话框
│   ├── FileCard.ets          # 文件卡片组件
│   ├── ProgressPanel.ets     # 批量进度面板
│   └── ResultItem.ets        # 结果条目组件
├── constants/
│   ├── ErrorCode.ets         # 错误码定义
│   └── AppConstants.ets      # 应用常量
└── pages/
    ├── Index.ets             # 首页（功能入口）
    ├── ManualCompose.ets     # 手动合成页
    ├── BatchCompose.ets      # 批量合成页
    └── ResultPage.ets        # 结果展示页
```

## 合成策略

| 级别 | 方案 | 说明 |
|---|---|---|
| L0 | HEIF 封面 + `addResource` 官方 API | 将 JPG 转换为 HEIF 格式作为封面，调用 `photoAccessHelper.createAsset` 创建 `MOVING_PHOTO` 子类型资源 |
| L1 | JPG 封面 + `addResource` 官方 API | HEIF 不支持时降级，直接使用 JPG 作为封面调用官方 API |
| L2 | 二进制拼接 | 官方 API 不可用时，将 JPG 字节 + XMP 元数据（Google MicroVideo 标准）+ MP4 字节拼接为单文件 |

## 关于无法删除原始素材

### 问题描述

合成动态照片后，**应用无法自动删除原始的 JPG 和 MP4 文件**。用户需在系统相册中手动删除。

### 根本原因

HarmonyOS 对媒体文件的删除操作受到严格的权限管控，存在以下两条路径均不可用：

#### 1. `MediaAssetChangeRequest.deleteAssets` — 需要 `WRITE_IMAGEVIDEO` 权限

这是 `photoAccessHelper` 提供的媒体资产删除 API，但调用它必须声明 `ohos.permission.WRITE_IMAGEVIDEO` 权限。

**该权限为受限开放权限（Restricted Permission）**，普通第三方应用无法获得：

- 权限级别：`system_basic`
- 授权方式：`user_grant`（用户授权）
- **仅特定场景的应用可通过 AGC 审批后使用**（如数据克隆备份、相册整理等）
- 灵影作为本地合成工具，不符合可申请该权限的特殊场景

官方文档对该权限的说明：

> **无需权限的建议方案**：使用安全控件或授权弹窗的方式，将用户指定的媒体资源保存到图库中。

也就是说，官方推荐普通应用通过 `SaveButton` 安全控件写入媒体库（灵影已采用），但删除操作没有对应的安全控件方案。

#### 2. `fileManagerService.deleteToTrash` — 仅支持文档 URI

`@kit.FileManagerServiceKit` 提供的 `deleteToTrash` API 可将文件移入回收站，但**仅支持文档类 URI**（`file://docs/...`），不支持媒体类 URI（`file://media/Photo/...`）。通过 PhotoViewPicker 选择的文件返回的是媒体 URI，因此无法使用此 API。

### 解决方案与申请路径

如果您确实需要自动删除原始素材的功能，且您的应用符合特殊场景，可以尝试申请 `WRITE_IMAGEVIDEO` 受限权限：

1. 登录 [AppGallery Connect (AGC)](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html#/)
2. 进入应用管理 → 选择应用 → **申请权限**
3. 在「受限 ACL 权限」中勾选 `ohos.permission.WRITE_IMAGEVIDEO`
4. 填写申请理由（需符合克隆备份、相册整理等特殊场景）
5. 提交后等待审核

详细申请流程参见：
- [受限开放权限 - HarmonyOS 文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/photoaccesshelper-preparation)
- [申请使用受限权限 - HarmonyOS 文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/restricted-permissions)

> **注意**：受限权限审核与上架审核绑定。如应用使用场景不符合要求，上架申请将被驳回。审核时长约 3 个工作日。

### 当前应用的处理方式

灵影在合成页面显示提示信息：

> 由于系统权限限制，合成后需在相册中手动删除原始 JPG 和 MP4 素材

## 构建 & 运行

1. 使用 DevEco Studio 5.0+ 打开项目
2. 连接 HarmonyOS 5.0+ 真机或模拟器
3. 配置签名（调试或发布）
4. Build & Run

## 许可证

MIT
