/**
 * Message Bubble Component
 * Displays chat messages with TV-optimized styling
 */

import type { Message } from '../../types/chat';

export interface MessageBubbleProps {
  message: Message;
  isStreaming?: boolean;
  streamingText?: string;
}

export function MessageBubble({
  message,
  isStreaming = false,
  streamingText,
}: MessageBubbleProps) {
  const isUser = message.role === 'user';
  const isAssistant = message.role === 'assistant';
  const isSystem = message.role === 'system';

  const content = isStreaming && streamingText !== undefined
    ? streamingText
    : message.content;

  // Format timestamp
  const timeString = new Date(message.timestamp).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  });

  if (isSystem) {
    return (
      <div className="flex justify-center my-4">
        <div className="bg-gray-800/50 text-gray-400 px-6 py-2 rounded-full text-lg">
          {content}
        </div>
      </div>
    );
  }

  return (
    <div
      className={`
        flex flex-col gap-2
        ${isUser ? 'items-end' : 'items-start'}
      `}
    >
      {/* Sender label */}
      <div
        className={`
          flex items-center gap-2 text-base
          ${isUser ? 'text-blue-400' : 'text-purple-400'}
        `}
      >
        <span className="font-semibold">
          {isUser ? 'You' : 'THEA'}
        </span>
        <span className="text-gray-500">{timeString}</span>
        {message.model && (
          <span className="text-gray-600 text-sm">
            ({message.model.split('/').pop()})
          </span>
        )}
      </div>

      {/* Message bubble */}
      <div
        className={`
          max-w-[80%] px-6 py-4 rounded-2xl
          text-xl leading-relaxed
          ${
            isUser
              ? 'bg-blue-600 text-white rounded-br-md'
              : 'bg-gray-800 text-gray-100 rounded-bl-md'
          }
        `}
      >
        {/* Content */}
        <div className="whitespace-pre-wrap break-words">
          {content}
          {isStreaming && (
            <span className="inline-block w-2 h-5 ml-1 bg-current animate-pulse" />
          )}
        </div>
      </div>

      {/* Token count if available */}
      {message.tokenCount && !isStreaming && (
        <div className="text-sm text-gray-600">
          {message.tokenCount} tokens
        </div>
      )}
    </div>
  );
}

/**
 * Typing indicator for when THEA is thinking
 */
export function TypingIndicator() {
  return (
    <div className="flex items-start gap-2">
      <div className="text-purple-400 font-semibold text-base">THEA</div>
      <div className="bg-gray-800 px-6 py-4 rounded-2xl rounded-bl-md">
        <div className="flex gap-2">
          <span className="w-3 h-3 bg-gray-500 rounded-full animate-bounce" />
          <span
            className="w-3 h-3 bg-gray-500 rounded-full animate-bounce"
            style={{ animationDelay: '0.1s' }}
          />
          <span
            className="w-3 h-3 bg-gray-500 rounded-full animate-bounce"
            style={{ animationDelay: '0.2s' }}
          />
        </div>
      </div>
    </div>
  );
}

/**
 * Empty state for new conversations
 */
export function EmptyConversation() {
  return (
    <div className="flex flex-col items-center justify-center h-full text-center px-8">
      <div className="text-6xl mb-6">
        <span className="text-purple-500">T</span>
        <span className="text-blue-500">H</span>
        <span className="text-cyan-500">E</span>
        <span className="text-green-500">A</span>
      </div>
      <h2 className="text-3xl font-bold text-white mb-4">
        Welcome to THEA
      </h2>
      <p className="text-xl text-gray-400 max-w-2xl">
        Your AI-powered assistant. Ask me anything, get help with tasks,
        or just have a conversation.
      </p>
      <div className="mt-8 text-lg text-gray-500">
        Press <span className="text-blue-400 font-medium">BLUE</span> for voice input
        or start typing with the on-screen keyboard
      </div>
    </div>
  );
}
