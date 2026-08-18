import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConstants } from '../constants/AppConstants';

const TAG: string = 'LingYing';
const DOMAIN: number = 0xFF00;

export class SandboxHelper {
  static async copyToSandbox(context: common.UIAbilityContext, sourceUri: string): Promise<string> {
    hilog.info(DOMAIN, TAG, `[SandboxHelper] copyToSandbox sourceUri=%{public}s`, sourceUri);
    const sandboxDir: string = `${context.filesDir}/${AppConstants.SANDBOX_DIR}`;
    if (!fs.accessSync(sandboxDir)) {
      fs.mkdirSync(sandboxDir);
    }

    const srcFile = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
    const srcStat = fs.statSync(srcFile.fd);
    const buffer = new ArrayBuffer(srcStat.size);
    fs.readSync(srcFile.fd, buffer);
    fs.closeSync(srcFile);
    hilog.info(DOMAIN, TAG, `[SandboxHelper] read source done, size=%{public}d`, srcStat.size);

    const baseName: string = SandboxHelper.extractBaseName(sourceUri);
    const ext: string = SandboxHelper.extractExtension(sourceUri);
    const destName: string = ext.length > 0 ? `${baseName}_${Date.now()}.${ext}` : `${baseName}_${Date.now()}`;
    const destPath: string = `${sandboxDir}/${destName}`;
    hilog.info(DOMAIN, TAG, `[SandboxHelper] destPath=%{public}s`, destPath);

    const destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    fs.writeSync(destFile.fd, buffer);
    fs.closeSync(destFile);

    const resultUri: string = SandboxHelper.convertToSandboxUri(context, destPath);
    hilog.info(DOMAIN, TAG, `[SandboxHelper] resultUri=%{public}s`, resultUri);
    return resultUri;
  }

  static convertToSandboxUri(context: common.UIAbilityContext, absolutePath: string): string {
    const bundleName: string = context.abilityInfo.bundleName;
    const prefix: string = `file://${bundleName}`;
    const el2Base: string = '/data/storage/el2/base';
    const hapsEntry: string = '/haps/entry/files';
    const filesDir: string = context.filesDir;
    hilog.info(DOMAIN, TAG, `[SandboxHelper] convertToSandboxUri absolutePath=%{public}s bundleName=%{public}s filesDir=%{public}s`, absolutePath, bundleName, filesDir);
    if (absolutePath.startsWith(filesDir)) {
      const relative: string = absolutePath.substring(filesDir.length);
      const result: string = `${prefix}${el2Base}${hapsEntry}${relative}`;
      hilog.info(DOMAIN, TAG, `[SandboxHelper] converted sandboxUri=%{public}s`, result);
      return result;
    }
    hilog.warn(DOMAIN, TAG, `[SandboxHelper] path does not start with filesDir, fallback`);
    return `file://${absolutePath}`;
  }

  static sandboxUriToPath(uri: string): string {
    hilog.info(DOMAIN, TAG, `[SandboxHelper] sandboxUriToPath uri=%{public}s`, uri);
    if (uri.startsWith('file:///')) {
      return uri.substring('file://'.length);
    }
    const matchIdx: number = uri.indexOf('/data/storage/');
    if (matchIdx > 0) {
      const afterData: string = uri.substring(matchIdx);
      const hapsEntryIdx: number = afterData.indexOf('/haps/entry/files');
      if (hapsEntryIdx >= 0) {
        const relative: string = afterData.substring(hapsEntryIdx + '/haps/entry/files'.length);
        const result: string = `/data/storage/el2/base/haps/entry/files${relative}`;
        hilog.info(DOMAIN, TAG, `[SandboxHelper] resolved path=%{public}s`, result);
        return result;
      }
      hilog.warn(DOMAIN, TAG, `[SandboxHelper] no haps/entry/files segment, fallback to afterData`);
      return afterData;
    }
    hilog.warn(DOMAIN, TAG, `[SandboxHelper] cannot parse uri, returning as-is`);
    return uri;
  }

  static getFileSize(uri: string): number {
    const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const stat = fs.statSync(file.fd);
    const size: number = stat.size;
    fs.closeSync(file);
    return size;
  }

  static cleanSandbox(context: common.UIAbilityContext): void {
    const sandboxDir: string = `${context.filesDir}/${AppConstants.SANDBOX_DIR}`;
    if (fs.accessSync(sandboxDir)) {
      const files: string[] = fs.listFileSync(sandboxDir);
      for (let i = 0; i < files.length; i++) {
        fs.unlinkSync(`${sandboxDir}/${files[i]}`);
      }
      fs.rmdirSync(sandboxDir);
    }
  }

  static extractFileName(uri: string): string {
    const segments: string[] = uri.split('/');
    const full: string = segments.length > 0 ? segments[segments.length - 1] : 'unknown';
    const dotIdx: number = full.lastIndexOf('.');
    if (dotIdx > 0) {
      return full;
    }
    return full;
  }

  static extractBaseName(uri: string): string {
    const fileName: string = SandboxHelper.extractFileName(uri);
    const dotIdx: number = fileName.lastIndexOf('.');
    if (dotIdx > 0) {
      return fileName.substring(0, dotIdx);
    }
    return fileName;
  }

  static extractExtension(uri: string): string {
    const fileName: string = SandboxHelper.extractFileName(uri);
    const dotIdx: number = fileName.lastIndexOf('.');
    if (dotIdx > 0) {
      return fileName.substring(dotIdx + 1).toLowerCase();
    }
    return '';
  }
}
