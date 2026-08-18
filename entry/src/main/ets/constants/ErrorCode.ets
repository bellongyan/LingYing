export class ErrorCode {
  static readonly INVALID_IMAGE_FORMAT: number = 1001;
  static readonly INVALID_VIDEO_FORMAT: number = 1002;
  static readonly VIDEO_TOO_LONG: number = 1003;
  static readonly FILE_TOO_LARGE: number = 1004;
  static readonly ASPECT_RATIO_MISMATCH: number = 1005;
  static readonly SANDBOX_COPY_FAILED: number = 1006;
  static readonly OFFICIAL_API_FAILED: number = 1007;
  static readonly HEIF_CONVERSION_FAILED: number = 1008;
  static readonly BINARY_SPLICE_FAILED: number = 1009;
  static readonly DELETE_ORIGINAL_FAILED: number = 1010;
  static readonly NO_PAIR_FOUND: number = 1011;
  static readonly MULTIPLE_VIDEO_CONFLICT: number = 1012;

  static getMessage(code: number): string {
    if (code === ErrorCode.INVALID_IMAGE_FORMAT) {
      return '请选择 JPG/JPEG/HEIC/HEIF/PNG/WebP/BMP 格式图片';
    }
    if (code === ErrorCode.INVALID_VIDEO_FORMAT) {
      return '请选择 MP4/MOV/3GP/MKV/AVI 格式视频';
    }
    if (code === ErrorCode.VIDEO_TOO_LONG) {
      return '视频时长需 ≤ 10 秒';
    }
    if (code === ErrorCode.FILE_TOO_LARGE) {
      return '文件过大';
    }
    if (code === ErrorCode.ASPECT_RATIO_MISMATCH) {
      return '图片与视频宽高比不一致，可能合成失败';
    }
    if (code === ErrorCode.SANDBOX_COPY_FAILED) {
      return '文件复制到沙箱失败';
    }
    if (code === ErrorCode.OFFICIAL_API_FAILED) {
      return '官方 API 合成动态照片失败';
    }
    if (code === ErrorCode.HEIF_CONVERSION_FAILED) {
      return 'HEIF 转码失败，已降级为 JPG';
    }
    if (code === ErrorCode.BINARY_SPLICE_FAILED) {
      return '二进制拼接合成失败';
    }
    if (code === ErrorCode.DELETE_ORIGINAL_FAILED) {
      return '删除原始素材失败';
    }
    if (code === ErrorCode.NO_PAIR_FOUND) {
      return '未找到配对文件';
    }
    if (code === ErrorCode.MULTIPLE_VIDEO_CONFLICT) {
      return '同名存在多个视频文件，无法确定配对';
    }
    return '未知错误';
  }

  static isRetryable(code: number): boolean {
    return code === ErrorCode.SANDBOX_COPY_FAILED ||
      code === ErrorCode.OFFICIAL_API_FAILED ||
      code === ErrorCode.DELETE_ORIGINAL_FAILED;
  }
}
