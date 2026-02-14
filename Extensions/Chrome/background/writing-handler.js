// Thea Chrome Extension - Writing Assistant Handler
// Emily-inspired writing feedback and style learning
// ES module format (Chrome background uses type: "module")

const STYLE_PROFILE_KEY = 'thea_writing_style';

let styleProfile = {
  vocabulary: [],
  commonPhrases: [],
  avgSentenceLength: 15,
  tonePreference: 'neutral', // formal, casual, technical, neutral
  formalityLevel: 0.5,       // 0 = very casual, 1 = very formal
  totalSamples: 0,
  acceptedSuggestions: 0,
  rejectedSuggestions: 0,
  lastUpdated: null
};

// ── Storage ─────────────────────────────────────────────────────────

async function loadStyleProfile() {
  try {
    const result = await chrome.storage.local.get(STYLE_PROFILE_KEY);
    if (result[STYLE_PROFILE_KEY]) {
      styleProfile = { ...styleProfile, ...result[STYLE_PROFILE_KEY] };
    }
  } catch (e) {
    console.error('Thea WritingHandler: Failed to load style profile:', e);
  }
}

async function saveStyleProfile() {
  try {
    styleProfile.lastUpdated = Date.now();
    await chrome.storage.local.set({ [STYLE_PROFILE_KEY]: styleProfile });
  } catch (e) {
    console.error('Thea WritingHandler: Failed to save style profile:', e);
  }
}

// ── Rewrite Request Handler ─────────────────────────────────────────

export async function handleRewriteRequest(data) {
  try {
    const { text, fullText, domain, fieldType } = data;

    // Determine context from domain
    const isEmail = domain.includes('gmail') || domain.includes('outlook') || domain.includes('mail');
    const isSocial = domain.includes('twitter') || domain.includes('linkedin') || domain.includes('facebook');
    const isCode = fieldType === 'textarea' && (domain.includes('github') || domain.includes('stackoverflow'));

    // Generate suggestion based on context and style profile
    const suggestion = await generateSuggestion(text, {
      isEmail,
      isSocial,
      isCode,
      tone: styleProfile.tonePreference,
      formality: styleProfile.formalityLevel
    });

    if (suggestion) {
      return { success: true, data: { suggestion } };
    }
    return { success: false };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// ── Suggestion Generation ───────────────────────────────────────────

async function generateSuggestion(text, context) {
  // Try native messaging to Thea app first
  try {
    const response = await chrome.runtime.sendNativeMessage('com.thea.app', {
      type: 'rewriteText',
      text,
      context: {
        tone: context.tone,
        formality: context.formality,
        isEmail: context.isEmail,
        isSocial: context.isSocial
      }
    });

    if (response?.suggestion) {
      return {
        text: response.suggestion,
        reason: response.reason || 'AI suggestion',
        replacement: response.replacement,
        append: response.append,
        confidence: response.confidence || 0.7
      };
    }
  } catch (e) {
    // Native messaging not available - fall back to local analysis
  }

  // Fallback: basic grammar/style suggestions
  return generateBasicSuggestion(text, context);
}

// ── Local Fallback Suggestions ──────────────────────────────────────

function generateBasicSuggestion(text, context) {
  const lastSentence = text.split(/[.!?]\s+/).pop() || '';

  // Check for overly long sentences without commas
  if (lastSentence.length > 50 && !lastSentence.includes(',')) {
    return {
      text: 'Consider breaking this into shorter sentences for clarity.',
      reason: 'Long sentence detected',
      confidence: 0.5
    };
  }

  // Check for passive voice patterns
  const passivePattern = /\b(is|are|was|were|be|been|being)\s+(being\s+)?\w+ed\b/i;
  if (passivePattern.test(lastSentence)) {
    return {
      text: 'Consider using active voice for more direct communication.',
      reason: 'Passive voice detected',
      confidence: 0.4
    };
  }

  // Check for excessive filler words
  const fillerPattern = /\b(very|really|just|actually|basically|literally|honestly)\b/gi;
  const fillers = lastSentence.match(fillerPattern);
  if (fillers && fillers.length >= 2) {
    return {
      text: `Consider removing filler words like "${fillers[0]}" for more concise writing.`,
      reason: 'Filler words detected',
      confidence: 0.5
    };
  }

  // Check for repeated words
  const words = lastSentence.toLowerCase().split(/\s+/);
  const wordCounts = {};
  for (const word of words) {
    if (word.length > 3) {
      wordCounts[word] = (wordCounts[word] || 0) + 1;
      if (wordCounts[word] >= 3) {
        return {
          text: `The word "${word}" appears ${wordCounts[word]} times. Consider using synonyms for variety.`,
          reason: 'Word repetition detected',
          confidence: 0.4
        };
      }
    }
  }

  // Email-specific: check for missing greeting or sign-off
  if (context.isEmail && text.length > 100) {
    const hasGreeting = /^(hi|hello|hey|dear|good\s+(morning|afternoon|evening))/i.test(text.trim());
    if (!hasGreeting) {
      return {
        text: 'Consider adding a greeting at the beginning of your email.',
        reason: 'Email etiquette',
        confidence: 0.3
      };
    }
  }

  return null; // No suggestion needed
}

// ── Style Analysis Handler ──────────────────────────────────────────

export async function handleAnalyzeStyle(data) {
  try {
    const { text } = data;

    // Analyze text patterns
    const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 0);
    const words = text.split(/\s+/).filter(w => w.length > 0);

    if (sentences.length > 0) {
      // Update average sentence length (running average)
      const avgLen = words.length / sentences.length;
      styleProfile.avgSentenceLength =
        (styleProfile.avgSentenceLength * styleProfile.totalSamples + avgLen) /
        (styleProfile.totalSamples + 1);

      // Detect formality level from word complexity
      const formalWords = words.filter(w => w.length > 8).length;
      const formalityScore = formalWords / words.length;
      styleProfile.formalityLevel =
        (styleProfile.formalityLevel * styleProfile.totalSamples + formalityScore) /
        (styleProfile.totalSamples + 1);

      // Detect tone from punctuation and word choice
      const exclamations = (text.match(/!/g) || []).length;
      const questions = (text.match(/\?/g) || []).length;
      if (exclamations > sentences.length * 0.3) {
        styleProfile.tonePreference = 'casual';
      } else if (formalityScore > 0.15) {
        styleProfile.tonePreference = 'formal';
      }

      styleProfile.totalSamples++;
      await saveStyleProfile();
    }

    return { success: true, data: styleProfile };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// ── Style Profile Query ─────────────────────────────────────────────

export async function handleGetStyleProfile() {
  return { success: true, data: styleProfile };
}

// ── Suggestion Feedback Handler ─────────────────────────────────────

export async function handleSaveSuggestionFeedback(data) {
  try {
    if (data.accepted) {
      styleProfile.acceptedSuggestions++;
    } else {
      styleProfile.rejectedSuggestions++;
    }
    await saveStyleProfile();
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// ── Initialize ──────────────────────────────────────────────────────

loadStyleProfile();

export default {
  handleRewriteRequest,
  handleAnalyzeStyle,
  handleGetStyleProfile,
  handleSaveSuggestionFeedback
};
