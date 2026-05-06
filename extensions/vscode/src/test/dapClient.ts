import { ChildProcessWithoutNullStreams } from 'child_process';

type DapRequest = {
  seq: number;
  type: 'request';
  command: string;
  arguments?: any;
};

type DapResponse = {
  seq: number;
  type: 'response';
  request_seq: number;
  success: boolean;
  command: string;
  message?: string;
  body?: any;
};

type DapEvent = {
  seq: number;
  type: 'event';
  event: string;
  body?: any;
};

type DapMessage = DapResponse | DapEvent;

type TranscriptEntry = {
  timestampMs: number;
  direction: 'send' | 'recv';
  kind: 'request' | 'response' | 'event';
  commandOrEvent: string;
  success?: boolean;
  message?: string;
};

export type TimestampedEvent = {
  timestampMs: number;
  event: string;
  body?: any;
};

export class DapClient {
  private proc: ChildProcessWithoutNullStreams;
  private seq = 0;
  private stdoutBuffer: Buffer = Buffer.alloc(0);
  private pending = new Map<number, { resolve: (r: DapResponse) => void; reject: (e: Error) => void }>();
  private events: DapEvent[] = [];
  private eventLog: TimestampedEvent[] = [];
  private transcript: TranscriptEntry[] = [];
  private readonly maxTranscriptEntries = 200;

  constructor(proc: ChildProcessWithoutNullStreams) {
    this.proc = proc;

    this.proc.stdout.on('data', (chunk: Buffer) => {
      this.stdoutBuffer = Buffer.concat([this.stdoutBuffer, chunk]);
      this.consumeMessages();
    });

    this.proc.on('exit', () => {
      const err = new Error('Debug adapter exited');
      for (const pending of this.pending.values()) {
        pending.reject(err);
      }
      this.pending.clear();
    });
  }

  async request(command: string, args?: any, timeoutMs = 10_000): Promise<DapResponse> {
    this.seq += 1;
    const requestSeq = this.seq;
    const message: DapRequest = { seq: requestSeq, type: 'request', command, arguments: args };
    const payload = Buffer.from(JSON.stringify(message), 'utf8');
    const header = Buffer.from(`Content-Length: ${payload.length}\r\n\r\n`, 'utf8');

    const responsePromise = new Promise<DapResponse>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(requestSeq);
        reject(
          new Error(
            `Timed out waiting for DAP response to ${command}\n\nRecent DAP transcript:\n${this.formatRecentTranscript()}`,
          ),
        );
      }, timeoutMs);

      this.pending.set(requestSeq, {
        resolve: (r) => {
          clearTimeout(timer);
          resolve(r);
        },
        reject: (e) => {
          clearTimeout(timer);
          reject(e);
        }
      });
    });

    this.proc.stdin.write(Buffer.concat([header, payload]));
    this.recordTranscript({
      timestampMs: Date.now(),
      direction: 'send',
      kind: 'request',
      commandOrEvent: command,
    });
    const response = await responsePromise;
    return response;
  }

  async waitForEvent(
    event: string,
    predicate: (e: DapEvent) => boolean = () => true,
    timeoutMs = 10_000
  ): Promise<DapEvent> {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const index = this.events.findIndex((e) => e.event === event && predicate(e));
      if (index >= 0) {
        const [matched] = this.events.splice(index, 1);
        return matched;
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }

    throw new Error(
      `Timed out waiting for DAP event: ${event}\n\nRecent DAP transcript:\n${this.formatRecentTranscript()}`,
    );
  }

  async waitForAnyEvent(
    events: string[],
    predicate: (e: DapEvent) => boolean = () => true,
    timeoutMs = 10_000
  ): Promise<DapEvent> {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const index = this.events.findIndex((e) => events.includes(e.event) && predicate(e));
      if (index >= 0) {
        const [matched] = this.events.splice(index, 1);
        return matched;
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }

    throw new Error(
      `Timed out waiting for DAP event(s): ${events.join(', ')}\n\nRecent DAP transcript:\n${this.formatRecentTranscript()}`,
    );
  }

  /** Returns a copy of all events received, with millisecond timestamps. */
  getEventLog(): TimestampedEvent[] {
    return this.eventLog.slice();
  }

  formatRecentTranscript(limit = 30): string {
    const recent = this.transcript.slice(Math.max(0, this.transcript.length - limit));
    if (recent.length === 0) {
      return '(no DAP messages captured)';
    }

    return recent
      .map((entry) => {
        const time = new Date(entry.timestampMs).toISOString();
        const base = `[${time}] ${entry.direction.toUpperCase()} ${entry.kind.toUpperCase()} ${entry.commandOrEvent}`;
        const parts: string[] = [];
        if (typeof entry.success === 'boolean') {
          parts.push(`success=${entry.success}`);
        }
        if (entry.message) {
          parts.push(`message=${entry.message}`);
        }
        return parts.length > 0 ? `${base} (${parts.join(', ')})` : base;
      })
      .join('\n');
  }

  dispose(): void {
    this.proc.kill();
  }

  private consumeMessages(): void {
    while (true) {
      const headerEnd = this.stdoutBuffer.indexOf('\r\n\r\n');
      if (headerEnd === -1) {
        return;
      }

      const header = this.stdoutBuffer.slice(0, headerEnd).toString('utf8');
      const match = header.match(/Content-Length:\s*(\d+)/i);
      if (!match) {
        // Corrupt framing; drop until after header delimiter.
        this.stdoutBuffer = this.stdoutBuffer.slice(headerEnd + 4);
        continue;
      }

      const length = Number(match[1]);
      const messageStart = headerEnd + 4;
      const messageEnd = messageStart + length;
      if (this.stdoutBuffer.length < messageEnd) {
        return;
      }

      const payload = this.stdoutBuffer.slice(messageStart, messageEnd).toString('utf8');
      this.stdoutBuffer = this.stdoutBuffer.slice(messageEnd);

      let parsed: DapMessage;
      try {
        parsed = JSON.parse(payload) as DapMessage;
      } catch {
        continue;
      }

      this.handleMessage(parsed);
    }
  }

  private handleMessage(message: DapMessage): void {
    if (message.type === 'event') {
      this.events.push(message);
      this.eventLog.push({ timestampMs: Date.now(), event: message.event, body: message.body });
      this.recordTranscript({
        timestampMs: Date.now(),
        direction: 'recv',
        kind: 'event',
        commandOrEvent: message.event,
      });
      return;
    }

    this.recordTranscript({
      timestampMs: Date.now(),
      direction: 'recv',
      kind: 'response',
      commandOrEvent: message.command,
      success: message.success,
      message: message.message,
    });

    const pending = this.pending.get(message.request_seq);
    if (!pending) {
      return;
    }

    this.pending.delete(message.request_seq);
    pending.resolve(message);
  }

  private recordTranscript(entry: TranscriptEntry): void {
    this.transcript.push(entry);
    if (this.transcript.length > this.maxTranscriptEntries) {
      this.transcript.splice(0, this.transcript.length - this.maxTranscriptEntries);
    }
  }
}
