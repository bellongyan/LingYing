export enum TaskStatus {
  IDLE = 'idle',
  VALIDATING = 'validating',
  WAITING_CONFIRM = 'waiting_confirm',
  COMPOSING = 'composing',
  COMPLETED = 'completed',
  FAILED = 'failed'
}

export class ComposeTaskState {
  status: TaskStatus = TaskStatus.IDLE;
  currentIndex: number = 0;
  totalCount: number = 0;
  successCount: number = 0;
  failCount: number = 0;
  skipCount: number = 0;
  isPaused: boolean = false;
  deleteOriginals: boolean = false;

  reset(): void {
    this.status = TaskStatus.IDLE;
    this.currentIndex = 0;
    this.totalCount = 0;
    this.successCount = 0;
    this.failCount = 0;
    this.skipCount = 0;
    this.isPaused = false;
    this.deleteOriginals = false;
  }
}
