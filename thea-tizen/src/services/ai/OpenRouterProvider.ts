/**
 * OpenRouter Provider Implementation
 * OpenRouter provides unified access to multiple AI models
 */

import { BaseAIProvider, ProviderCapability, ProviderError } from './AIProvider';
import type { ChatMessage, ChatOptions, StreamChunk, AIModel } from '../../types/chat';
import { API_URLS, STREAM_CONFIG, APP_INFO } from '../../config/constants';

/**
 * OpenRouter provider - unified API for multiple AI models
 */
export class OpenRouterProvider extends BaseAIProvider {
  readonly id = 'openrouter';
  readonly name = 'OpenRouter';

  readonly capabilities = new Set<ProviderCapability>([
    'chat',
    'streaming',
    'vision',
    'functionCalling',
  ]);

  readonly supportedModels: AIModel[] = [
    // Anthropic models via OpenRouter
    {
      id: 'anthropic/claude-sonnet-4',
      name: 'Claude Sonnet 4',
      provider: 'openrouter',
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
      id: 'anthropic/claude-opus-4',
      name: 'Claude Opus 4',
      provider: 'openrouter',
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
      id: 'anthropic/claude-3.5-haiku',
      name: 'Claude 3.5 Haiku',
      provider: 'openrouter',
      contextWindow: 200000,
      maxOutputTokens: 8192,
      capabilities: ['chat', 'streaming', 'vision', 'function_calling', 'code'],
      inputCostPer1K: 0.0008,
      outputCostPer1K: 0.004,
      supportsStreaming: true,
      supportsVision: true,
      supportsFunctionCalling: true,
    },
    // OpenAI models via OpenRouter
    {
      id: 'openai/gpt-4o',
      name: 'GPT-4o',
      provider: 'openrouter',
      contextWindow: 128000,
      maxOutputTokens: 16384,
      capabilities: ['chat', 'streaming', 'vision', 'function_calling', 'code'],
      inputCostPer1K: 0.005,
      outputCostPer1K: 0.015,
      supportsStreaming: true,
      supportsVision: true,
      supportsFunctionCalling: true,
    },
    {
      id: 'openai/gpt-4o-mini',
      name: 'GPT-4o Mini',
      provider: 'openrouter',
      contextWindow: 128000,
      maxOutputTokens: 16384,
      capabilities: ['chat', 'streaming', 'vision', 'function_calling', 'code'],
      inputCostPer1K: 0.00015,
      outputCostPer1K: 0.0006,
      supportsStreaming: true,
      supportsVision: true,
      supportsFunctionCalling: true,
    },
    // Google models via OpenRouter
    {
      id: 'google/gemini-2.0-flash',
      name: 'Gemini 2.0 Flash',
      provider: 'openrouter',
      contextWindow: 1000000,
      maxOutputTokens: 8192,
      capabilities: ['chat', 'streaming', 'vision', 'function_calling', 'code'],
      inputCostPer1K: 0.0001,
      outputCostPer1K: 0.0004,
      supportsStreaming: true,
      supportsVision: true,
      supportsFunctionCalling: true,
    },
    // DeepSeek models
    {
      id: 'deepseek/deepseek-r1',
      name: 'DeepSeek R1',
      provider: 'openrouter',
      contextWindow: 64000,
      maxOutputTokens: 8192,
      capabilities: ['chat', 'streaming', 'reasoning', 'code'],
      inputCostPer1K: 0.00055,
      outputCostPer1K: 0.00219,
      supportsStreaming: true,
      supportsVision: false,
      supportsFunctionCalling: false,
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
          'OpenRouter API key not configured',
          'NOT_CONFIGURED',
          this.id
        ),
      };
      return;
    }

    // Convert messages to OpenAI format (OpenRouter uses OpenAI-compatible API)
    const formattedMessages = messages.map(m => ({
      role: m.role,
      content: m.content,
    }));

    // Add system prompt as first message if provided
    if (options.systemPrompt) {
      formattedMessages.unshift({
        role: 'system',
        content: options.systemPrompt,
      });
    }

    const body: Record<string, unknown> = {
      model,
      messages: formattedMessages,
      stream: options.stream !== false,
    };

    // Add optional parameters
    if (options.maxTokens !== undefined) {
      body.max_tokens = options.maxTokens;
    }
    if (options.temperature !== undefined) {
      body.temperature = options.temperature;
    }
    if (options.topP !== undefined) {
      body.top_p = options.topP;
    }

    try {
      const response = await fetch(`${API_URLS.OPENROUTER}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.apiKey}`,
          'HTTP-Referer': 'https://thea.app',
          'X-Title': `${APP_INFO.NAME} ${APP_INFO.VERSION} (${APP_INFO.PLATFORM})`,
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
        yield* this.parseSSEStream(response, this.parseOpenAIEvent.bind(this));
      } else {
        // Non-streaming response
        const data = await response.json();
        const content = data.choices?.[0]?.message?.content || '';

        yield { type: 'content', content };
        yield {
          type: 'done',
          finishReason: data.choices?.[0]?.finish_reason,
          usage: data.usage
            ? {
                promptTokens: data.usage.prompt_tokens || 0,
                completionTokens: data.usage.completion_tokens || 0,
                totalTokens: data.usage.total_tokens || 0,
              }
            : undefined,
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
   * Parse OpenAI-format SSE event
   */
  private parseOpenAIEvent(data: string): StreamChunk | null {
    const event = JSON.parse(data);

    // Check for content delta
    const delta = event.choices?.[0]?.delta;
    if (delta?.content) {
      return { type: 'content', content: delta.content };
    }

    // Check for finish
    const finishReason = event.choices?.[0]?.finish_reason;
    if (finishReason) {
      return {
        type: 'done',
        finishReason,
        usage: event.usage
          ? {
              promptTokens: event.usage.prompt_tokens || 0,
              completionTokens: event.usage.completion_tokens || 0,
              totalTokens: event.usage.total_tokens || 0,
            }
          : undefined,
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
