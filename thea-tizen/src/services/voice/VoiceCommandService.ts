/**
 * Voice Command Service
 *
 * Handles voice commands on Samsung TV using:
 * - Tizen Speech Recognition API
 * - Samsung Bixby integration (where available)
 * - Wake word detection ("Hey Thea")
 * - Natural language intent parsing
 *
 * Commands:
 * - "What's new today?" - Show new episodes
 * - "Play [title]" - Search and play content
 * - "Add [title] to my list" - Add to watchlist
 * - "Search for [query]" - Search content
 * - "Download [title]" - Trigger download
 * - "Dim the lights" - Control Home Assistant
 *
 * @see https://developer.samsung.com/smarttv/develop/api-references/samsung-product-api-references/asr-api.html
 */

// ============================================================
// TYPES
// ============================================================

export interface VoiceCommandConfig {
  enabled: boolean;
  wakeWord: string;
  language: string;
  confirmActions: boolean;
  speakResponses: boolean;
  continuousListening: boolean;
}

export interface VoiceCommand {
  intent: CommandIntent;
  entities: Record<string, string>;
  confidence: number;
  rawText: string;
}

export type CommandIntent =
  | 'play'
  | 'search'
  | 'add_to_list'
  | 'remove_from_list'
  | 'download'
  | 'what_new'
  | 'what_watching'
  | 'recommendations'
  | 'continue_watching'
  | 'dim_lights'
  | 'lights_on'
  | 'lights_off'
  | 'movie_mode'
  | 'pause'
  | 'resume'
  | 'stop'
  | 'navigate_home'
  | 'navigate_settings'
  | 'unknown';

export interface IntentPattern {
  intent: CommandIntent;
  patterns: RegExp[];
  entities?: string[];
  examples: string[];
}

type VoiceCommandHandler = (command: VoiceCommand) => Promise<string>;
type RecognitionListener = (result: { text: string; isFinal: boolean }) => void;

// ============================================================
// CONSTANTS
// ============================================================

const CONFIG_KEY = 'thea_voice_config';

const DEFAULT_CONFIG: VoiceCommandConfig = {
  enabled: true,
  wakeWord: 'hey thea',
  language: 'en-US',
  confirmActions: true,
  speakResponses: true,
  continuousListening: false,
};

// Intent patterns for natural language understanding
const INTENT_PATTERNS: IntentPattern[] = [
  {
    intent: 'play',
    patterns: [
      /^play\s+(.+)$/i,
      /^watch\s+(.+)$/i,
      /^start\s+(.+)$/i,
      /^put on\s+(.+)$/i,
    ],
    entities: ['title'],
    examples: ['Play Breaking Bad', 'Watch The Office'],
  },
  {
    intent: 'search',
    patterns: [
      /^search\s+(?:for\s+)?(.+)$/i,
      /^find\s+(.+)$/i,
      /^look\s+(?:for\s+)?(.+)$/i,
    ],
    entities: ['query'],
    examples: ['Search for action movies', 'Find sci-fi shows'],
  },
  {
    intent: 'add_to_list',
    patterns: [
      /^add\s+(.+?)\s+to\s+(?:my\s+)?(?:list|watchlist|queue)$/i,
      /^save\s+(.+)$/i,
      /^bookmark\s+(.+)$/i,
    ],
    entities: ['title'],
    examples: ['Add Dune to my list', 'Save this movie'],
  },
  {
    intent: 'download',
    patterns: [
      /^download\s+(.+)$/i,
      /^get\s+(.+)$/i,
      /^grab\s+(.+)$/i,
    ],
    entities: ['title'],
    examples: ['Download the latest episode', 'Get Breaking Bad S5E16'],
  },
  {
    intent: 'what_new',
    patterns: [
      /^what(?:'s| is) new(?:\s+today)?$/i,
      /^new episodes?$/i,
      /^any(?:thing)? new$/i,
      /^show new(?:\s+(?:episodes?|releases?))?$/i,
    ],
    examples: ["What's new today?", 'New episodes', 'Anything new?'],
  },
  {
    intent: 'what_watching',
    patterns: [
      /^what(?:'s| am I) (?:I )?watching$/i,
      /^currently watching$/i,
      /^now playing$/i,
    ],
    examples: ["What am I watching?", 'Currently watching'],
  },
  {
    intent: 'recommendations',
    patterns: [
      /^(?:show me )?recommendations?$/i,
      /^suggest(?:ions)?$/i,
      /^what should I watch$/i,
    ],
    examples: ['Show me recommendations', 'What should I watch?'],
  },
  {
    intent: 'continue_watching',
    patterns: [
      /^continue(?:\s+watching)?$/i,
      /^resume(?:\s+watching)?$/i,
      /^pick up where I left off$/i,
    ],
    examples: ['Continue watching', 'Resume'],
  },
  {
    intent: 'dim_lights',
    patterns: [
      /^dim(?:\s+the)?\s+lights?$/i,
      /^lower(?:\s+the)?\s+lights?$/i,
      /^lights?\s+dim$/i,
    ],
    examples: ['Dim the lights', 'Lower lights'],
  },
  {
    intent: 'lights_on',
    patterns: [
      /^(?:turn\s+)?lights?\s+on$/i,
      /^lights?\s+up$/i,
      /^bright(?:en)?(?:\s+(?:the\s+)?lights?)?$/i,
    ],
    examples: ['Lights on', 'Turn lights on'],
  },
  {
    intent: 'lights_off',
    patterns: [
      /^(?:turn\s+)?lights?\s+off$/i,
      /^lights?\s+out$/i,
    ],
    examples: ['Lights off', 'Turn lights off'],
  },
  {
    intent: 'movie_mode',
    patterns: [
      /^movie\s+mode$/i,
      /^theater\s+mode$/i,
      /^cinema\s+mode$/i,
    ],
    examples: ['Movie mode', 'Theater mode'],
  },
  {
    intent: 'pause',
    patterns: [
      /^pause$/i,
      /^stop(?:\s+playing)?$/i,
      /^hold(?:\s+on)?$/i,
    ],
    examples: ['Pause', 'Stop'],
  },
  {
    intent: 'resume',
    patterns: [
      /^resume$/i,
      /^(?:un)?pause$/i,
      /^continue$/i,
      /^keep\s+(?:going|playing)$/i,
    ],
    examples: ['Resume', 'Unpause', 'Keep playing'],
  },
  {
    intent: 'navigate_home',
    patterns: [
      /^(?:go\s+)?home$/i,
      /^main\s+(?:menu|screen)$/i,
      /^back\s+to\s+(?:home|start)$/i,
    ],
    examples: ['Go home', 'Main menu'],
  },
  {
    intent: 'navigate_settings',
    patterns: [
      /^(?:open\s+)?settings$/i,
      /^preferences$/i,
      /^configuration$/i,
    ],
    examples: ['Settings', 'Open settings'],
  },
];

// ============================================================
// SERVICE
// ============================================================

class VoiceCommandService {
  private static instance: VoiceCommandService;

  private config: VoiceCommandConfig;
  private handlers: Map<CommandIntent, VoiceCommandHandler> = new Map();
  private recognitionListeners: Set<RecognitionListener> = new Set();
  private isListening = false;
  private recognition: any = null; // SpeechRecognition instance
  private synthesis: any = null; // SpeechSynthesis instance

  private constructor() {
    this.config = this.loadConfig();
    this.initializeSpeechAPIs();
    this.registerDefaultHandlers();
  }

  static getInstance(): VoiceCommandService {
    if (!VoiceCommandService.instance) {
      VoiceCommandService.instance = new VoiceCommandService();
    }
    return VoiceCommandService.instance;
  }

  // ============================================================
  // CONFIGURATION
  // ============================================================

  private loadConfig(): VoiceCommandConfig {
    try {
      const saved = localStorage.getItem(CONFIG_KEY);
      if (saved) {
        return { ...DEFAULT_CONFIG, ...JSON.parse(saved) };
      }
    } catch { /* ignore */ }
    return { ...DEFAULT_CONFIG };
  }

  saveConfig(config: Partial<VoiceCommandConfig>): void {
    this.config = { ...this.config, ...config };
    localStorage.setItem(CONFIG_KEY, JSON.stringify(this.config));
  }

  getConfig(): VoiceCommandConfig {
    return { ...this.config };
  }

  // ============================================================
  // SPEECH RECOGNITION
  // ============================================================

  private initializeSpeechAPIs(): void {
    // Check for Tizen Speech API
    if (typeof (window as any).webapis?.speech !== 'undefined') {
      console.log('VoiceCommand: Tizen Speech API available');
      // Use Tizen API
    } else if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
      console.log('VoiceCommand: Web Speech API available');
      const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
      this.recognition = new SpeechRecognition();
      this.recognition.continuous = this.config.continuousListening;
      this.recognition.interimResults = true;
      this.recognition.lang = this.config.language;

      this.recognition.onresult = (event: any) => {
        const result = event.results[event.results.length - 1];
        const text = result[0].transcript;
        const isFinal = result.isFinal;

        this.notifyRecognitionListeners({ text, isFinal });

        if (isFinal) {
          this.processVoiceInput(text);
        }
      };

      this.recognition.onerror = (event: any) => {
        console.error('VoiceCommand: Recognition error', event.error);
      };

      this.recognition.onend = () => {
        this.isListening = false;
        if (this.config.continuousListening && this.config.enabled) {
          // Restart listening
          setTimeout(() => this.startListening(), 1000);
        }
      };
    } else {
      console.warn('VoiceCommand: No speech recognition available');
    }

    // Text-to-speech
    if ('speechSynthesis' in window) {
      this.synthesis = window.speechSynthesis;
    }
  }

  /**
   * Start listening for voice commands
   */
  startListening(): boolean {
    if (!this.config.enabled || !this.recognition) {
      return false;
    }

    if (this.isListening) {
      return true;
    }

    try {
      this.recognition.start();
      this.isListening = true;
      console.log('VoiceCommand: Listening started');
      return true;
    } catch (error) {
      console.error('VoiceCommand: Failed to start listening', error);
      return false;
    }
  }

  /**
   * Stop listening
   */
  stopListening(): void {
    if (this.recognition && this.isListening) {
      this.recognition.stop();
      this.isListening = false;
      console.log('VoiceCommand: Listening stopped');
    }
  }

  /**
   * Check if currently listening
   */
  isCurrentlyListening(): boolean {
    return this.isListening;
  }

  // ============================================================
  // NATURAL LANGUAGE PROCESSING
  // ============================================================

  /**
   * Process raw voice input
   */
  async processVoiceInput(text: string): Promise<void> {
    console.log(`VoiceCommand: Processing "${text}"`);

    // Check for wake word if not in continuous mode
    const lowerText = text.toLowerCase().trim();
    if (this.config.wakeWord) {
      if (!lowerText.startsWith(this.config.wakeWord)) {
        // Not a command for us
        return;
      }
      // Remove wake word
      text = text.substring(this.config.wakeWord.length).trim();
    }

    // Parse command
    const command = this.parseCommand(text);
    console.log(`VoiceCommand: Parsed intent: ${command.intent}`, command);

    // Execute handler
    await this.executeCommand(command);
  }

  /**
   * Parse text into a command
   */
  parseCommand(text: string): VoiceCommand {
    const normalized = text.toLowerCase().trim();

    for (const pattern of INTENT_PATTERNS) {
      for (const regex of pattern.patterns) {
        const match = normalized.match(regex);
        if (match) {
          const entities: Record<string, string> = {};

          // Extract entities from capture groups
          if (pattern.entities) {
            for (let i = 0; i < pattern.entities.length; i++) {
              if (match[i + 1]) {
                entities[pattern.entities[i]] = match[i + 1].trim();
              }
            }
          }

          return {
            intent: pattern.intent,
            entities,
            confidence: 0.9,
            rawText: text,
          };
        }
      }
    }

    // Unknown intent
    return {
      intent: 'unknown',
      entities: { query: text },
      confidence: 0.5,
      rawText: text,
    };
  }

  /**
   * Execute a parsed command
   */
  async executeCommand(command: VoiceCommand): Promise<void> {
    const handler = this.handlers.get(command.intent);

    if (handler) {
      try {
        const response = await handler(command);
        if (this.config.speakResponses && response) {
          this.speak(response);
        }
      } catch (error) {
        console.error(`VoiceCommand: Handler error for ${command.intent}`, error);
        this.speak("Sorry, I couldn't do that.");
      }
    } else if (command.intent === 'unknown') {
      // Try to interpret as a search
      const searchHandler = this.handlers.get('search');
      if (searchHandler) {
        await searchHandler({
          ...command,
          intent: 'search',
          entities: { query: command.rawText },
        });
      } else {
        this.speak("I didn't understand that command.");
      }
    }
  }

  // ============================================================
  // TEXT-TO-SPEECH
  // ============================================================

  /**
   * Speak text aloud
   */
  speak(text: string): void {
    if (!this.synthesis || !this.config.speakResponses) {
      console.log(`VoiceCommand: Would speak: "${text}"`);
      return;
    }

    // Cancel any ongoing speech
    this.synthesis.cancel();

    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = this.config.language;
    utterance.rate = 1.0;
    utterance.pitch = 1.0;

    this.synthesis.speak(utterance);
  }

  // ============================================================
  // COMMAND HANDLERS
  // ============================================================

  /**
   * Register a command handler
   */
  registerHandler(intent: CommandIntent, handler: VoiceCommandHandler): void {
    this.handlers.set(intent, handler);
  }

  /**
   * Register default handlers (can be overridden by app)
   */
  private registerDefaultHandlers(): void {
    // These are placeholder handlers - the app should register proper ones
    this.registerHandler('what_new', async () => {
      return "Let me show you what's new today.";
    });

    this.registerHandler('recommendations', async () => {
      return 'Here are some recommendations for you.';
    });

    this.registerHandler('continue_watching', async () => {
      return 'Continuing from where you left off.';
    });

    this.registerHandler('navigate_home', async () => {
      return 'Going to the home screen.';
    });

    this.registerHandler('navigate_settings', async () => {
      return 'Opening settings.';
    });

    this.registerHandler('pause', async () => {
      return 'Paused.';
    });

    this.registerHandler('resume', async () => {
      return 'Resuming playback.';
    });

    this.registerHandler('unknown', async (command) => {
      return `I'm not sure what you meant by "${command.rawText}".`;
    });
  }

  // ============================================================
  // LISTENERS
  // ============================================================

  onRecognition(listener: RecognitionListener): () => void {
    this.recognitionListeners.add(listener);
    return () => this.recognitionListeners.delete(listener);
  }

  private notifyRecognitionListeners(result: { text: string; isFinal: boolean }): void {
    for (const listener of this.recognitionListeners) {
      try {
        listener(result);
      } catch (error) {
        console.error('VoiceCommand: Listener error', error);
      }
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /**
   * Get all available commands with examples
   */
  getAvailableCommands(): Array<{ intent: CommandIntent; examples: string[] }> {
    return INTENT_PATTERNS.map(p => ({
      intent: p.intent,
      examples: p.examples,
    }));
  }

  /**
   * Check if speech recognition is available
   */
  isAvailable(): boolean {
    return this.recognition !== null || typeof (window as any).webapis?.speech !== 'undefined';
  }
}

export const voiceCommandService = VoiceCommandService.getInstance();
