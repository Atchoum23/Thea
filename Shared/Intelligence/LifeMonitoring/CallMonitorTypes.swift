// CallMonitorTypes.swift
// THEA - Types for Voice Call Transcription & Intelligence
//
// Extracted from CallMonitor.swift

import Foundation
import AVFoundation
#if canImport(Speech)
import Speech
#endif

// MARK: - Audio Buffer Wrapper

// @unchecked Sendable: AVAudioPCMBuffer is not Sendable; used for real-time audio processing
// where copying would be too slow; caller must ensure the buffer is not used after the transfer
/// Wrapper to make AVAudioPCMBuffer sendable across actor boundaries
/// Safety: The buffer should only be accessed while it's still valid
/// This is used for real-time audio processing where copying would be too slow
struct SendableAudioBuffer: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}

// MARK: - Call Types

/// Source of the call
public enum CallSource: String, Sendable, CaseIterable {
    case phone              // Regular phone calls
    case facetime           // FaceTime audio/video
    case zoom               // Zoom
    case teams              // Microsoft Teams
    case slack              // Slack huddles/calls
    case discord            // Discord
    case whatsapp           // WhatsApp calls
    case telegram           // Telegram calls
    case signal             // Signal calls
    case skype              // Skype
    case meet               // Google Meet
    case webex              // Webex
    case other              // Unknown source
}

/// Type of call
public enum CallType: String, Sendable {
    case incoming
    case outgoing
    case conference
}

/// Call status
public enum CallStatus: String, Sendable {
    case ringing
    case active
    case onHold = "on_hold"
    case ended
    case missed
}

// MARK: - Call Record

/// A recorded/transcribed call
public struct CallRecord: Identifiable, Sendable {
    public let id: UUID
    public let source: CallSource
    public let type: CallType
    public let startTime: Date
    public var endTime: Date?
    public var duration: TimeInterval { (endTime ?? Date()).timeIntervalSince(startTime) }
    public var status: CallStatus
    public let participants: [CallParticipant]
    public var transcript: CallTranscript
    public var analysis: CallAnalysis?
    public var audioRecordingPath: String?
    public let metadata: CallMetadata

    public struct CallMetadata: Sendable {
        public let callerID: String?
        public let phoneNumber: String?
        public let contactName: String?
        public let isBusinessCall: Bool
        public let appBundleID: String?
    }

    public init(
        id: UUID = UUID(),
        source: CallSource,
        type: CallType,
        startTime: Date = Date(),
        participants: [CallParticipant],
        metadata: CallMetadata
    ) {
        self.id = id
        self.source = source
        self.type = type
        self.startTime = startTime
        self.endTime = nil
        self.status = .ringing
        self.participants = participants
        self.transcript = CallTranscript(segments: [])
        self.analysis = nil
        self.audioRecordingPath = nil
        self.metadata = metadata
    }
}

/// A participant in the call
public struct CallParticipant: Identifiable, Sendable {
    public let id: UUID
    public let name: String?
    public let identifier: String // Phone number, email, etc.
    public let isLocalUser: Bool
    public var speakingDuration: TimeInterval = 0
    public var wordCount: Int = 0

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        identifier: String,
        isLocalUser: Bool = false
    ) {
        self.id = id
        self.name = name
        self.identifier = identifier
        self.isLocalUser = isLocalUser
    }
}

// MARK: - Transcript

/// Full call transcript
public struct CallTranscript: Sendable {
    public var segments: [CallTranscriptSegment]
    public var fullText: String {
        segments.map { "[\($0.speaker)]: \($0.text)" }.joined(separator: "\n")
    }
    public var wordCount: Int {
        segments.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }
    public var durationCovered: TimeInterval {
        guard let first = segments.first, let last = segments.last else { return 0 }
        return last.endTime.timeIntervalSince(first.startTime)
    }

    public init(segments: [CallTranscriptSegment] = []) {
        self.segments = segments
    }
}

/// A segment of transcribed speech
public struct CallTranscriptSegment: Identifiable, Sendable {
    public let id: UUID
    public let speaker: String
    public let text: String
    public let startTime: Date
    public let endTime: Date
    public let confidence: Double
    public let isInterim: Bool // Still being transcribed

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public init(
        id: UUID = UUID(),
        speaker: String,
        text: String,
        startTime: Date,
        endTime: Date = Date(),
        confidence: Double = 0.9,
        isInterim: Bool = false
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.isInterim = isInterim
    }
}

// MARK: - Call Analysis

/// Analysis extracted from call content
public struct CallAnalysis: Sendable {
    public let callId: UUID
    public let analyzedAt: Date
    public let summary: String
    public let keyPoints: [String]
    public let actionItems: [ActionItem]
    public let commitments: [Commitment]
    public let followUps: [FollowUp]
    public let deadlinesMentioned: [MentionedDeadline]
    public let sentiment: CallSentiment
    public let topics: [Topic]
    public let decisions: [Decision]
    public let questions: [Question]

    public struct ActionItem: Sendable {
        public let description: String
        public let assignee: String?
        public let dueDate: Date?
        public let priority: Priority
        public let extractedFrom: String // Quote from transcript

        public enum Priority: String, Sendable {
            case low, medium, high, urgent
        }
    }

    public struct Commitment: Sendable {
        public let description: String
        public let madeBy: String
        public let madeAt: Date
        public let deadline: Date?
        public let extractedFrom: String
    }

    public struct FollowUp: Sendable {
        public let description: String
        public let scheduledFor: Date?
        public let participants: [String]
        public let type: FollowUpType

        public enum FollowUpType: String, Sendable {
            case call, meeting, email, task, other
        }
    }

    public struct MentionedDeadline: Sendable {
        public let description: String
        public let date: Date
        public let context: String
    }

    public struct Topic: Sendable {
        public let name: String
        public let duration: TimeInterval
        public let keywords: [String]
    }

    public struct Decision: Sendable {
        public let description: String
        public let madeBy: String?
        public let alternatives: [String]
    }

    public struct Question: Sendable {
        public let text: String
        public let askedBy: String
        public let wasAnswered: Bool
        public let answer: String?
    }

    public struct CallSentiment: Sendable {
        public let overall: SentimentLevel
        public let byParticipant: [String: SentimentLevel]
        public let trend: [SentimentPoint]

        public enum SentimentLevel: String, Sendable {
            case veryNegative = "very_negative"
            case negative
            case neutral
            case positive
            case veryPositive = "very_positive"
        }

        public struct SentimentPoint: Sendable {
            public let timestamp: Date
            public let level: SentimentLevel
        }
    }

    public init(
        callId: UUID,
        summary: String,
        keyPoints: [String] = [],
        actionItems: [ActionItem] = [],
        commitments: [Commitment] = [],
        followUps: [FollowUp] = [],
        deadlinesMentioned: [MentionedDeadline] = [],
        sentiment: CallSentiment,
        topics: [Topic] = [],
        decisions: [Decision] = [],
        questions: [Question] = []
    ) {
        self.callId = callId
        self.analyzedAt = Date()
        self.summary = summary
        self.keyPoints = keyPoints
        self.actionItems = actionItems
        self.commitments = commitments
        self.followUps = followUps
        self.deadlinesMentioned = deadlinesMentioned
        self.sentiment = sentiment
        self.topics = topics
        self.decisions = decisions
        self.questions = questions
    }
}
