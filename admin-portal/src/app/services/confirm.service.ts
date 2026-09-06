import { Injectable, signal } from '@angular/core';

export interface ConfirmOptions {
  /** The confirmation message shown in the modal. */
  message: string;
  /** Optional title; defaults to "Are you sure?". */
  title?: string;
  /** Optional accent for the confirm button, e.g. 'danger' | 'primary'. */
  kind?: 'danger' | 'primary';
  /** Label for the destructive/confirm button; defaults to "Confirm". */
  confirmLabel?: string;
  /** Label for the cancel button; defaults to "Cancel". */
  cancelLabel?: string;
}

export interface PendingConfirm extends ConfirmOptions {
  id: number;
}

/**
 * Replaces the browser's native `confirm()` dialog with the app's own modal
 * window. Because it is driven by a signal and rendered by
 * ConfirmDialogComponent (hosted once in the admin layout), every delete in
 * the portal gets the same styled, theme-consistent confirmation instead of a
 * jarring OS alert.
 *
 * Usage from a component's (async) handler:
 *   if (!(await this.confirm.confirm('Delete this record?'))) return;
 */
@Injectable({ providedIn: 'root' })
export class ConfirmService {
  readonly pending = signal<PendingConfirm | null>(null);

  private nextId = 1;
  private resolver: ((value: boolean) => void) | null = null;

  /** Opens the confirmation modal and resolves with the user's choice. */
  confirm(messageOrOptions: string | ConfirmOptions): Promise<boolean> {
    const options: ConfirmOptions =
      typeof messageOrOptions === 'string' ? { message: messageOrOptions } : messageOrOptions;
    return new Promise<boolean>((resolve) => {
      this.resolver = resolve;
      this.pending.set({ id: this.nextId++, ...options });
    });
  }

  ok() {
    const resolve = this.resolver;
    this.pending.set(null);
    this.resolver = null;
    if (resolve) resolve(true);
  }

  cancel() {
    const resolve = this.resolver;
    this.pending.set(null);
    this.resolver = null;
    if (resolve) resolve(false);
  }
}