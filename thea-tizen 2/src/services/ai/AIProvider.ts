/**
 * AI Provider Interface
 * Mirrors Swift protocol: Shared/Providers/Protocol/AIProvider.swift
 */

import type {
  ChatMessage,
  ChatOptions,
  StreamChunk,
  AIModel,
  ProviderHealth,
} from '../../types/chat';

/**
 * Provider capability flags
 */
export type ProviderCapability =
  | 'chat'
  | 'streaming'
  | 'vision'
  | 'functionCalling'
  | 'reasoning'
  | 'embedding';

/**
 * AIProvider interface - all providers must implement this
 */
export interface AIProvider {
  /** Unique provider identifier */
  readonly id: string;

  /** Human-readable name */
  readonly name: string;

  /** Whether the provider is configured (has API key) */
  readonly isConfigured: boolean;

  /** List of supported models */
  readonly supportedModels: AIModel[];

  /** Set of provider capabilities */
  readonly capabilities: Set<ProviderCapability>;

  /**
   * Send a chat request with streaming response
   * @param messages - Conversation history
   * @param model - Model ID to use
   * @param options - Chat options
   * @returns AsyncGenerator yielding StreamChunks
   */
  chat(
    messages: ChatMessage[],
    model: string,
    options: ChatOptions
  ): AsyncGenerator<StreamChunk, void, unknown>;

  /**
   * Send a chat request and wait for complete response
   * @param messages - Conversation history
   * @param model - Model ID to use
   * @param options - Chat options
   * @returns Complete response text
   */
  chatSync(
    messages: ChatMessage[],
    model: string,
    options: ChatOptions
  ): Promise<string>;

  /**
   * Check provider health/connectivity
   * @returns Health status
   */
  checkHealth(): Promise<ProviderHealth>;
}

/**
 * Base class with common functionality
 */
export abstract class BaseAIProvider implements AIProvider {
  abstract readonly id: string;
  abstract readonly name: string;
  abstract readonly supportedModels: AIModel[];
  abstract readonly capabilities: Set<ProviderCapability>;

  protected apiKey: string = '';

  get isConfigured(): boolean {
    return this.apiKey.length > 0;
  }

  setApiKey(key: string): void {
    this.apiKey = key;
  }

  abstract chat(
    messages: ChatMessage[],
    model: string,
    options: ChatOptions
  ): AsyncGenerator<StreamChunk, void, unknown>;

  /**
   * Default chatSync implementation using streaming
   */
  async chatSync(
    messages: ChatMessage[],
    model: string,
    options: ChatOptions
  ): Promise<string> {
    let result = '';

    for await (const chunk of this.chat(messages, model, {
      ...options,
      stream: true,
    })) {
      if (chunk.type === 'content') {
        result += chunk.content;
      } else if (chunk.type === 'error') {
        throw chunk.error;
      }
    }

    return result;
  }

  async checkHealth(): Promise<ProviderHealth> {
    const start = Date.now();

    if (!this.isConfigured) {
      return {
        isHealthy: false,
        error: 'API key not configured',
        lastChecked: start,
      };
    }

    try {
      // Simple health check with minimal tokens
      await this.chatSync(
        [{ role: 'user', content: 'ping' }],
        this.supportedModels[0]?.id || '',
        { maxTokens: 5 }
      );

      return {
        isHealthy: true,
        latency: Date.now() - start,
        lastChecked: Date.now(),
      };
    } catch (error) {
      return {
        isHealthy: false,
        error: error instanceof Error ? error.message : 'Unknown error',
        lastChecked: Date.now(),
      };
    }
  }

  /**
   * Parse SSE stream from fetch response
   */
  protected async *parseSSEStream(
    response: Response,
    parseEvent: (eventData: string) => StreamChunk | null
  ): AsyncGenerator<StreamChunk, void, unknown> {
    if (!response.body) {
      yield { type: 'error', error: new Error('No response body') };
      return;
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    try {
      while (true) {
        const { done, value } = await reader.read();

        if (done) break;

        buffer += decoder.decode(value, { stream: true });

        // Process complete lines
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          const trimmed = line.trim();

          if (!trimmed || trimmed.startsWith(':')) {
            continue; // Skip empty lines and comments
          }

          if (trimmed.startsWith('data: ')) {
            const data = trimmed.slice(6);

            if (data === '[DONE]') {
              yield { type: 'done' };
              return;
            }

            try {
              const chunk = parseEvent(data);
              if (chunk) {
                yield chunk;
              }
            } catch {
              // Skip malformed JSON
            }
          }
        }
      }

      // Process remaining buffer
      if (buffer.trim()) {
        if (buffer.startsWith('data: ')) {
          const data = buffer.slice(6);
          if (data !== '[DONE]') {
            try {
              const chunk = parseEvent(data);
              if (chunk) {
                yield chunk;
              }
            } catch {
              // Skip malformed JSON
            }
          }
        }
      }

      yield { type: 'done' };
    } catch (error) {
      yield {
        type: 'error',
        error: error instanceof Error ? error : new Error(String(error)),
      };
    } finally {
      reader.releaseLock();
    }
  }
}

/**
 * Provider error types
 */
export class ProviderError extends Error {
  constructor(
    message: string,
    public readonly code: ProviderErrorCode,
    public readonly provider: string,
    public readonly status?: number
  ) {
    super(message);
    this.name = 'ProviderError';
  }
}

export type ProviderErrorCode =
  | 'NOT_CONFIGURED'
  | 'INVALID_API_KEY'
  | 'RATE_LIMITED'
  | 'MODEL_NOT_FOUND'
  | 'CONTEXT_TOO_LONG'
  | 'SAFETY_REFUSAL'
  | 'NETWORK_ERROR'
  | 'INVALID_RESPONSE'
  | 'SERVER_ERROR'
  | 'TIMEOUT'
  | 'CANCELLED';
