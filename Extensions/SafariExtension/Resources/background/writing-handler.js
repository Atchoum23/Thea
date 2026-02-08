// Thea Safari Extension - Writing Assistant Handler
// Emily-inspired writing assistant that learns from user style
// Uses native bridge for AI-powered rewriting and style analysis

var STYLE_PROFILE_KEY = 'thea_writing_style';
var SUGGESTION_FEEDBACK_KEY = 'thea_writing_feedback';

/**
 * Load the user's writing style profile from storage.
 * @returns {Object} The style profile
 */
async function loadStyleProfile() {
    try {
        var result = await browser.storage.local.get(STYLE_PROFILE_KEY);
        return result[STYLE_PROFILE_KEY] || createDefaultProfile();
    } catch (err) {
        console.error('[Thea Writing] Failed to load style profile:', err);
        return createDefaultProfile();
    }
}

/**
 * Create a default empty style profile.
 */
function createDefaultProfile() {
    return {
        vocabulary: [],
        commonPhrases: [],
        avgSentenceLength: 0,
        tonePreference: 'neutral',       // neutral, formal, casual, academic, creative
        formalityLevel: 0.5,             // 0 = very casual, 1 = very formal
        sampleCount: 0,
        lastUpdated: null,
        preferences: {
            oxfordComma: true,
            contractions: true,
            activeVoice: true,
            paragraphLength: 'medium'    // short, medium, long
        }
    };
}

/**
 * Save the writing style profile to storage.
 * @param {Object} profile - The style profile to save
 */
async function saveStyleProfile(profile) {
    try {
        var data = {};
        data[STYLE_PROFILE_KEY] = profile;
        await browser.storage.local.set(data);
    } catch (err) {
        console.error('[Thea Writing] Failed to save style profile:', err);
    }
}

/**
 * Load suggestion feedback history.
 */
async function loadFeedbackHistory() {
    try {
        var result = await browser.storage.local.get(SUGGESTION_FEEDBACK_KEY);
        return result[SUGGESTION_FEEDBACK_KEY] || [];
    } catch (err) {
        return [];
    }
}

/**
 * Save suggestion feedback history.
 */
async function saveFeedbackHistory(history) {
    try {
        var data = {};
        data[SUGGESTION_FEEDBACK_KEY] = history;
        await browser.storage.local.set(data);
    } catch (err) {
        console.error('[Thea Writing] Failed to save feedback:', err);
    }
}

/**
 * Handle a rewrite request from the content script.
 * Sends text to the native bridge for AI-powered rewriting.
 * @param {Object} data - { text, style, tone, context }
 * @returns {Object} { success, suggestion, original }
 */
async function handleRewriteRequest(data) {
    if (!data.text || data.text.trim().length === 0) {
        return { success: false, error: 'No text provided' };
    }

    var style = data.style || 'default';
    var tone = data.tone || 'neutral';

    // Load the user's style profile to inform rewriting
    var profile = await loadStyleProfile();

    // If style is 'user', use the learned profile
    if (style === 'user' && profile.sampleCount > 0) {
        tone = profile.tonePreference;
    }

    try {
        var response = await rewriteTextNative(data.text, style, tone);

        if (response.error) {
            return { success: false, error: response.error };
        }

        return {
            success: true,
            original: data.text,
            suggestion: response.rewritten || response.text || data.text,
            style: style,
            tone: tone,
            confidence: response.confidence || 0.8
        };
    } catch (err) {
        console.error('[Thea Writing] Rewrite failed:', err);
        return { success: false, error: 'Rewrite service unavailable' };
    }
}

/**
 * Analyze text samples to build/update the user's style profile.
 * @param {Object} data - { text, source }
 * @returns {Object} Updated profile summary
 */
async function handleAnalyzeStyle(data) {
    if (!data.text || data.text.trim().length < 50) {
        return { success: false, error: 'Text too short for analysis (minimum 50 characters)' };
    }

    var profile = await loadStyleProfile();

    // Local analysis: sentence length, vocabulary
    var sentences = data.text.split(/[.!?]+/).filter(function (s) { return s.trim().length > 0; });
    var words = data.text.split(/\s+/).filter(function (w) { return w.length > 0; });

    // Update average sentence length
    var newAvgLength = words.length / Math.max(sentences.length, 1);
    if (profile.sampleCount > 0) {
        profile.avgSentenceLength = (profile.avgSentenceLength * profile.sampleCount + newAvgLength) /
            (profile.sampleCount + 1);
    } else {
        profile.avgSentenceLength = newAvgLength;
    }

    // Extract distinctive vocabulary (words > 5 chars, used more than once)
    var wordFreq = {};
    for (var i = 0; i < words.length; i++) {
        var word = words[i].toLowerCase().replace(/[^a-z'-]/g, '');
        if (word.length > 5) {
            wordFreq[word] = (wordFreq[word] || 0) + 1;
        }
    }

    var frequentWords = Object.keys(wordFreq).filter(function (w) { return wordFreq[w] > 1; });
    var existingVocab = new Set(profile.vocabulary);
    for (var j = 0; j < frequentWords.length; j++) {
        existingVocab.add(frequentWords[j]);
    }
    profile.vocabulary = Array.from(existingVocab).slice(0, 200); // cap at 200 words

    // Detect formality level
    var formalIndicators = ['therefore', 'however', 'furthermore', 'consequently', 'nevertheless',
        'regarding', 'pursuant', 'accordingly', 'moreover', 'notwithstanding'];
    var casualIndicators = ["don't", "can't", "won't", "i'm", "it's", "that's",
        'kinda', 'gonna', 'wanna', 'cool', 'awesome', 'yeah'];

    var formalCount = 0;
    var casualCount = 0;
    var textLower = data.text.toLowerCase();

    for (var fi = 0; fi < formalIndicators.length; fi++) {
        if (textLower.indexOf(formalIndicators[fi]) !== -1) formalCount++;
    }
    for (var ci = 0; ci < casualIndicators.length; ci++) {
        if (textLower.indexOf(casualIndicators[ci]) !== -1) casualCount++;
    }

    var newFormality = 0.5;
    if (formalCount > casualCount) newFormality = 0.7;
    else if (casualCount > formalCount) newFormality = 0.3;

    if (profile.sampleCount > 0) {
        profile.formalityLevel = (profile.formalityLevel * profile.sampleCount + newFormality) /
            (profile.sampleCount + 1);
    } else {
        profile.formalityLevel = newFormality;
    }

    // Determine tone from formality
    if (profile.formalityLevel > 0.7) profile.tonePreference = 'formal';
    else if (profile.formalityLevel > 0.55) profile.tonePreference = 'neutral';
    else profile.tonePreference = 'casual';

    // Also try native analysis for richer results
    try {
        var nativeResult = await analyzeWritingStyleNative(data.text);
        if (nativeResult && !nativeResult.error) {
            // Merge native insights if available
            if (nativeResult.commonPhrases) {
                var existingPhrases = new Set(profile.commonPhrases);
                for (var p = 0; p < nativeResult.commonPhrases.length; p++) {
                    existingPhrases.add(nativeResult.commonPhrases[p]);
                }
                profile.commonPhrases = Array.from(existingPhrases).slice(0, 50);
            }
        }
    } catch (err) {
        // Native analysis is optional; continue with local results
        console.warn('[Thea Writing] Native analysis unavailable:', err.message);
    }

    profile.sampleCount++;
    profile.lastUpdated = Date.now();

    await saveStyleProfile(profile);

    return {
        success: true,
        profile: {
            avgSentenceLength: Math.round(profile.avgSentenceLength * 10) / 10,
            tonePreference: profile.tonePreference,
            formalityLevel: Math.round(profile.formalityLevel * 100) / 100,
            vocabularySize: profile.vocabulary.length,
            sampleCount: profile.sampleCount,
            lastUpdated: profile.lastUpdated
        }
    };
}

/**
 * Get the current style profile.
 */
async function handleGetStyleProfile() {
    var profile = await loadStyleProfile();
    return { success: true, profile: profile };
}

/**
 * Record feedback on a writing suggestion (accepted or rejected).
 * Used to learn and improve future suggestions.
 * @param {Object} data - { original, suggestion, accepted, style, tone }
 */
async function handleSaveSuggestionFeedback(data) {
    var feedback = {
        original: data.original || '',
        suggestion: data.suggestion || '',
        accepted: data.accepted === true,
        style: data.style || 'default',
        tone: data.tone || 'neutral',
        timestamp: Date.now()
    };

    var history = await loadFeedbackHistory();
    history.unshift(feedback);

    // Keep only last 100 feedback entries
    if (history.length > 100) {
        history = history.slice(0, 100);
    }

    await saveFeedbackHistory(history);

    return { success: true };
}
