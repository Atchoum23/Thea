/**
 * Chat types - mirrors Swift models from Thea
 * See: Shared/Core/Models/Message.swift, Shared/Providers/Protocol/AIProvider.swift
 */

// Message roles
export type MessageRole = 'user' | 'assistant' | 'system';

// Chat message (API format)
export interface ChatMessage {
  role: MessageRole;
  content: string;
}

// Stored message (persistent format)
export interface Message {
  id: string;
  conversationId: string;
  role: MessageRole;
  content: string;
  timestamp: number;
  model?: string;
  tokenCount?: number;
  metadata?: MessageMetadata;
  orderIndex: number;
  // Branching support
  parentMessageId?: string;
  branchIndex?: number;
  isEdited?: boolean;
}

export interface MessageMetadata {
  finishReason?: string;
  systemFingerprint?: string;
  cachedTokens?: number;
  reasoningTokens?: number;
  confidence?: number;
  generationDuration?: number;
}

// Conversation
export interface Conversation {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  isPinned: boolean;
  projectId?: string;
  metadata?: ConversationMetadata;
}

export interface ConversationMetadata {
  totalTokens?: number;
  totalCost?: number;
  preferredModel?: string;
  tags?: string[];
}

// Chat options
export interface ChatOptions {
  temperature?: number;
  maxTokens?: number;
  topP?: number;
  stream?: boolean;
  systemPrompt?: string;
  // Advanced options
  tools?: ToolDefinition[];
  responseFormat?: ResponseFormat;
}

export interface ToolDefinition {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
}

export interface ResponseFormat {
  type: 'text' | 'json_object' | 'json_schema';
  jsonSchema?: Record<string, unknown>;
}

// Stream chunk types
export type StreamChunk =
  | { type: 'content'; content: string }
  | { type: 'done'; finishReason?: string; usage?: TokenUsage }
  | { type: 'error'; error: Error };

export interface TokenUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
  cachedTokens?: number;
}

// Provider types
export interface AIModel {
  id: string;
  name: string;
  provider: string;
  contextWindow: number;
  maxOutputTokens: number;
  capabilities: ModelCapability[];
  inputCostPer1K?: number;
  outputCostPer1K?: number;
  supportsStreaming: boolean;
  supportsVision: boolean;
  supportsFunctionCalling: boolean;
}

export type ModelCapability =
  | 'chat'
  | 'streaming'
  | 'vision'
  | 'function_calling'
  | 'reasoning'
  | 'code'
  | 'embedding';

export interface ProviderHealth {
  isHealthy: boolean;
  latency?: number;
  error?: string;
  lastChecked: number;
}

// Chat state
export interface ChatState {
  conversations: Conversation[];
  activeConversationId: string | null;
  messages: Record<string, Message[]>; // conversationId -> messages
  isStreaming: boolean;
  streamingText: string;
  error: string | null;
}
