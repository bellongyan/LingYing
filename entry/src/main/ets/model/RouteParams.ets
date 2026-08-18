import { ProcessResult } from './FilePair';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'LingYing';
const DOMAIN: number = 0xFF00;

export class ResultDataHolder {
  private static results: ProcessResult[] = [];
  private static isBatchMode: boolean = false;

  static set(data: ProcessResult[], batchMode: boolean): void {
    ResultDataHolder.results = data;
    ResultDataHolder.isBatchMode = batchMode;
    hilog.info(DOMAIN, TAG, `[ResultDataHolder] set: results.length=%{public}d isBatchMode=%{public}s`, data.length, `${batchMode}`);
    for (let i = 0; i < data.length; i++) {
      hilog.info(DOMAIN, TAG, `[ResultDataHolder] results[%{public}d]: success=%{public}s outputType=%{public}s errorRecord=%{public}s`, i, `${data[i].success}`, data[i].outputType, `${data[i].errorRecord !== undefined}`);
    }
  }

  static getResults(): ProcessResult[] {
    hilog.info(DOMAIN, TAG, `[ResultDataHolder] getResults: length=%{public}d`, ResultDataHolder.results.length);
    return ResultDataHolder.results;
  }

  static getIsBatchMode(): boolean {
    return ResultDataHolder.isBatchMode;
  }

  static clear(): void {
    ResultDataHolder.results = [];
    ResultDataHolder.isBatchMode = false;
  }
}
