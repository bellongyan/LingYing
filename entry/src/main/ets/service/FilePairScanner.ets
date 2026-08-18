import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { FilePair } from '../model/FilePair';
import { AppConstants } from '../constants/AppConstants';

export class FilePairScanner {
  static async scanAndPair(context: common.UIAbilityContext, folderUri: string): Promise<FilePair[]> {
    const files: ScannedFile[] = await FilePairScanner.listFilesInFolder(context, folderUri);
    const pairs: FilePair[] = FilePairScanner.pairFiles(files);
    return pairs;
  }

  static async listFilesInFolder(context: common.UIAbilityContext, folderUri: string): Promise<ScannedFile[]> {
    const result: ScannedFile[] = [];

    try {
      const dirPath: string = folderUri;
      const fileNames: string[] = fs.listFileSync(dirPath);

      for (let i = 0; i < fileNames.length; i++) {
        const name: string = fileNames[i];
        const ext: string = FilePairScanner.getExtension(name).toLowerCase();
        const isImage: boolean = AppConstants.IMAGE_EXTENSIONS.indexOf(ext) >= 0;
        const isVideo: boolean = AppConstants.VIDEO_EXTENSIONS.indexOf(ext) >= 0;

        if (isImage || isVideo) {
          const fullPath: string = `${dirPath}/${name}`;
          const stat = fs.statSync(fullPath);
          const scanned: ScannedFile = new ScannedFile();
          scanned.name = name;
          scanned.baseName = FilePairScanner.getBaseName(name);
          scanned.extension = ext;
          scanned.uri = `file://${fullPath}`;
          scanned.size = stat.size;
          scanned.isImage = isImage;
          scanned.isVideo = isVideo;
          result.push(scanned);
        }
      }
    } catch (e) {
      return result;
    }

    return result;
  }

  static pairFiles(files: ScannedFile[]): FilePair[] {
    const imageMap: Record<string, ScannedFile> = {};
    const videoMap: Record<string, ScannedFile[]> = {};
    const pairs: FilePair[] = [];

    for (let i = 0; i < files.length; i++) {
      const file: ScannedFile = files[i];
      const key: string = file.baseName.toLowerCase();

      if (file.isImage) {
        imageMap[key] = file;
      } else if (file.isVideo) {
        if (videoMap[key] === undefined) {
          videoMap[key] = [];
        }
        videoMap[key].push(file);
      }
    }

    const imageKeys: string[] = Object.keys(imageMap);
    for (let i = 0; i < imageKeys.length; i++) {
      const key: string = imageKeys[i];
      const imageFile: ScannedFile = imageMap[key];
      const videoFiles: ScannedFile[] = videoMap[key] ?? [];

      if (videoFiles.length === 0) {
        continue;
      }

      if (videoFiles.length === 1) {
        const videoFile: ScannedFile = videoFiles[0];
        const pair: FilePair = FilePair.create(
          imageFile.baseName,
          imageFile.uri,
          videoFile.uri,
          imageFile.size,
          videoFile.size,
          0,
          0,
          0,
          0,
          0,
          imageFile.extension,
          videoFile.extension
        );
        pairs.push(pair);
      } else {
        const pair: FilePair = FilePair.create(
          imageFile.baseName,
          imageFile.uri,
          videoFiles[0].uri,
          imageFile.size,
          videoFiles[0].size,
          0,
          0,
          0,
          0,
          0,
          imageFile.extension,
          videoFiles[0].extension
        );
        pairs.push(pair);
      }
    }

    return pairs;
  }

  static getUnpairedFiles(files: ScannedFile[], pairs: FilePair[]): ScannedFile[] {
    const pairedUris: Record<string, boolean> = {};
    for (let i = 0; i < pairs.length; i++) {
      pairedUris[pairs[i].imageUri] = true;
      pairedUris[pairs[i].videoUri] = true;
    }

    const unpaired: ScannedFile[] = [];
    for (let i = 0; i < files.length; i++) {
      if (pairedUris[files[i].uri] !== true) {
        unpaired.push(files[i]);
      }
    }
    return unpaired;
  }

  static getBaseName(fileName: string): string {
    const dotIdx: number = fileName.lastIndexOf('.');
    if (dotIdx > 0) {
      return fileName.substring(0, dotIdx);
    }
    return fileName;
  }

  static getExtension(fileName: string): string {
    const dotIdx: number = fileName.lastIndexOf('.');
    if (dotIdx > 0) {
      return fileName.substring(dotIdx + 1);
    }
    return '';
  }
}

export class ScannedFile {
  name: string = '';
  baseName: string = '';
  extension: string = '';
  uri: string = '';
  size: number = 0;
  isImage: boolean = false;
  isVideo: boolean = false;
}
