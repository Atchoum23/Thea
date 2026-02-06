/**
 * Anthropic Provider Implementation
 * Mirrors: Shared/Providers/Anthropic/AnthropicProvider.swift
 */

import { BaseAIProvider, ProviderCapability, ProviderError } from './AIProvider';
import type { ChatMessage, ChatOptions, StreamChunk, AIModel } from '../../types/chat';
import { API_URLS, API_VERSIONS, STREAM_CONFIG } from '../../config/constants';

/**
 * Anthropic Claude provider
 */
export class AnthropicProvider extends BaseAIProvider {
  readonly id = 'anthropic';
  readonly name = 'Anthropic';

  readonly capabilities = new Set<ProviderCapability>([
    'chat',
    'streaming',
    'vision',
    'functionCalling',
    'reasoning',
  ]);

  readonly supportedModels: AIModel[] = [
    {
      id: 'claude-sonnet-4-20250514',
      name: 'Claude Sonnet 4',
      provider: 'anthropic',
      contextWindow: 200000,
      maxOutputTokens: 64000,
      capabilities: ['chat', 'streaming', 'vision', 'function_calling', 'reasoning', 'code'],
      inputCostPer1K: 0.003,
      outputCostPer1K: 0.015,
      supportsStreaming: true,
      supportsVision: true,
      supportsFunctionCalling: true,
    },
    {
      id: 'claude-opus-4-20250514',
      name: 'Claude Opus 4',
      provider: 'anthropic',
      contextWindow: 200000,
      maxOutputTokens: 32000,
      capabilities: ['chat', 'streaming', 'vision', 'function_calling', 'reasoning', 'code'],
      inputCostPer1K: 0.015,
      outputCostPer1K: 0.075,
      supportsStreaming: true,
      supportsVision: true,
      supportsFunctionCalling: true,
    },
    {
      id: 'claude-3-5-haiku-20241022',
      name: 'Claude 3.5 Haiku',
      provider: 'anthropic',
      contextWindow: 200000,
      maxOutputTokens: 8192,
      capabilities: ['chat', 'streaming', 'vision', 'function_calling', 'code'],
      inputCostPer1K: 0.0008,
      outputCostPer1K: 0.004,
      supportsStreaming: true,
      supportsVision: true,
      supportsFunctionCalling: true,
    },
  ];

  async *chat(
    messages: ChatMessage[],
    model: string,
    options: ChatOptions
  ): AsyncGenerator<StreamChunk, void, unknown> {
    if (!this.isConfigured) {
      yield {
        type: 'error',
        error: new ProviderError(
          'Anthropic API key not configured',
          'NOT_CONFIGURED',
          this.id
        ),
      };
      return;
    }

    // Extract system message
    const systemMessage = messages.find(m => m.role === 'system');
    const chatMessages = messages.filter(m => m.role !== 'system');

    // Build request body
    const body: Record<string, unknown> = {
      model,
      max_tokens: options.maxTokens || 4096,
      messages: chatMessages.map(m => ({
        role: m.role,
        content: m.content,
      })),
      stream: options.stream !== false,
    };

    // Add system prompt
    if (options.systemPrompt) {
      body.system = options.systemPrompt;
    } else if (systemMessage) {
      body.system = systemMessage.content;
    }

    // Add optional parameters
    if (options.temperature !== undefined) {
      body.temperature = options.temperature;
    }
    if (options.topP !== undefined) {
      body.top_p = options.topP;
    }

    try {
      const response = await fetch(`${API_URLS.ANTHROPIC}/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.apiKey,
          'anthropic-version': API_VERSIONS.ANTHROPIC,
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(STREAM_CONFIG.TIMEOUT),
      });

      if (!response.ok) {
        const errorText = await response.text();
        let errorMessage = `API error: ${response.status}`;

        try {
          const errorJson = JSON.parse(errorText);
          errorMessage = errorJson.error?.message || errorMessage;
        } catch {
          // Use default message
        }

        yield {
          type: 'error',
          error: new ProviderError(
            errorMessage,
            this.mapStatusToErrorCode(response.status),
            this.id,
            response.status
          ),
        };
        return;
      }

      // Handle streaming response
      if (options.stream !== false) {
        yield* this.parseSSEStream(response, this.parseAnthropicEvent.bind(this));
      } else {
        // Non-streaming response
        const data = await response.json();
        const content = data.content?.[0]?.text || '';

        yield { type: 'content', content };
        yield {
          type: 'done',
          finishReason: data.stop_reason,
          usage: {
            promptTokens: data.usage?.input_tokens || 0,
            completionTokens: data.usage?.output_tokens || 0,
            totalTokens:
              (data.usage?.input_tokens || 0) + (data.usage?.output_tokens || 0),
            cachedTokens: data.usage?.cache_read_input_tokens,
          },
        };
      }
    } catch (error) {
      if (error instanceof ProviderError) {
        yield { type: 'error', error };
      } else if (error instanceof Error) {
        yield {
          type: 'error',
          error: new ProviderError(error.message, 'NETWORK_ERROR', this.id),
        };
      }
    }
  }

  /**
   * Parse Anthropic SSE event
   */
  private parseAnthropicEvent(data: string): StreamChunk | null {
    const event = JSON.parse(data);

    switch (event.type) {
      case 'content_block_delta':
        if (event.delta?.type === 'text_delta') {
          return { type: 'content', content: event.delta.text };
        }
        break;

      case 'message_delta':
        return {
          type: 'done',
          finishReason: event.delta?.stop_reason,
          usage: event.usage
            ? {
                promptTokens: event.usage.input_tokens || 0,
                completionTokens: event.usage.output_tokens || 0,
                totalTokens:
                  (event.usage.input_tokens || 0) +
                  (event.usage.output_tokens || 0),
              }
            : undefined,
        };

      case 'message_stop':
        return { type: 'done' };

      case 'error':
        return {
          type: 'error',
          error: new ProviderError(
            event.error?.message || 'Unknown error',
            'SERVER_ERROR',
            this.id
          ),
        };
    }

    return null;
  }

  /**
   * Map HTTP status to error code
   */
  private mapStatusToErrorCode(status: number): ProviderError['code'] {
    switch (status) {
      case 401:
        return 'INVALID_API_KEY';
      case 429:
        return 'RATE_LIMITED';
      case 400:
        return 'INVALID_RESPONSE';
      case 404:
        return 'MODEL_NOT_FOUND';
      default:
        return status >= 500 ? 'SERVER_ERROR' : 'NETWORK_ERROR';
    }
  }
}
