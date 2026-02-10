// FocusModeTemplates.swift
// THEA - Localized message templates for Focus Mode
// Extracted from FocusModeIntelligence.swift

import Foundation

// MARK: - Message Templates

/// Localized message templates for all supported languages
public struct LocalizedMessageTemplates: Codable, Sendable {
    public var autoReply: [String: AutoReplyTemplate]
    public var callerNotification: [String: CallerNotificationTemplate]
    public var urgentResponse: [String: UrgentResponseTemplate]

    public struct AutoReplyTemplate: Codable, Sendable {
        public let language: String
        public let languageName: String
        public let initialMessage: String
        public let urgentQuestion: String
        public let urgentConfirmed: String
        public let callInstructions: String
        public let focusModeExplanation: String

        public static func defaultTemplates() -> [String: AutoReplyTemplate] {
            [
                "en": AutoReplyTemplate(
                    language: "en",
                    languageName: "English",
                    initialMessage: "Hi! I'm currently in Focus Mode and may not see your message right away. Is this urgent?",
                    urgentQuestion: "Reply YES if this is urgent, or I'll get back to you when I'm available.",
                    urgentConfirmed: "Got it, this is urgent! To reach me immediately, please call me twice within 3 minutes. My phone is set to ring on the second call from the same number.",
                    callInstructions: "📞 To reach me urgently: Call twice within 3 minutes.",
                    focusModeExplanation: "Focus Mode helps me concentrate without interruptions. Urgent calls will still come through if you call twice within 3 minutes."
                ),
                "fr": AutoReplyTemplate(
                    language: "fr",
                    languageName: "Français",
                    initialMessage: "Bonjour ! Je suis en mode Concentration et ne verrai peut-être pas votre message tout de suite. Est-ce urgent ?",
                    urgentQuestion: "Répondez OUI si c'est urgent, sinon je vous répondrai dès que possible.",
                    urgentConfirmed: "Compris, c'est urgent ! Pour me joindre immédiatement, appelez-moi deux fois en moins de 3 minutes. Mon téléphone sonnera au deuxième appel.",
                    callInstructions: "📞 Pour me joindre en urgence : Appelez deux fois en moins de 3 minutes.",
                    focusModeExplanation: "Le mode Concentration m'aide à me concentrer sans interruptions. Les appels urgents passeront si vous appelez deux fois en moins de 3 minutes."
                ),
                "de": AutoReplyTemplate(
                    language: "de",
                    languageName: "Deutsch",
                    initialMessage: "Hallo! Ich bin gerade im Fokus-Modus und sehe Ihre Nachricht möglicherweise nicht sofort. Ist es dringend?",
                    urgentQuestion: "Antworten Sie JA, wenn es dringend ist, andernfalls melde ich mich, sobald ich verfügbar bin.",
                    urgentConfirmed: "Verstanden, es ist dringend! Um mich sofort zu erreichen, rufen Sie mich bitte zweimal innerhalb von 3 Minuten an. Mein Telefon klingelt beim zweiten Anruf.",
                    callInstructions: "📞 Für dringende Anliegen: Rufen Sie zweimal innerhalb von 3 Minuten an.",
                    focusModeExplanation: "Der Fokus-Modus hilft mir, mich ohne Unterbrechungen zu konzentrieren. Dringende Anrufe kommen durch, wenn Sie zweimal innerhalb von 3 Minuten anrufen."
                ),
                "it": AutoReplyTemplate(
                    language: "it",
                    languageName: "Italiano",
                    initialMessage: "Ciao! Sono in modalità Focus e potrei non vedere subito il tuo messaggio. È urgente?",
                    urgentQuestion: "Rispondi SÌ se è urgente, altrimenti ti risponderò appena possibile.",
                    urgentConfirmed: "Capito, è urgente! Per raggiungermi subito, chiamami due volte entro 3 minuti. Il mio telefono squillerà alla seconda chiamata.",
                    callInstructions: "📞 Per urgenze: Chiama due volte entro 3 minuti.",
                    focusModeExplanation: "La modalità Focus mi aiuta a concentrarmi senza interruzioni. Le chiamate urgenti passano se chiami due volte entro 3 minuti."
                ),
                "es": AutoReplyTemplate(
                    language: "es",
                    languageName: "Español",
                    initialMessage: "¡Hola! Estoy en modo Concentración y puede que no vea tu mensaje de inmediato. ¿Es urgente?",
                    urgentQuestion: "Responde SÍ si es urgente, de lo contrario te contestaré cuando esté disponible.",
                    urgentConfirmed: "Entendido, ¡es urgente! Para contactarme inmediatamente, llámame dos veces en menos de 3 minutos. Mi teléfono sonará en la segunda llamada.",
                    callInstructions: "📞 Para urgencias: Llama dos veces en menos de 3 minutos.",
                    focusModeExplanation: "El modo Concentración me ayuda a enfocarme sin interrupciones. Las llamadas urgentes pasarán si llamas dos veces en menos de 3 minutos."
                ),
                "pt": AutoReplyTemplate(
                    language: "pt",
                    languageName: "Português",
                    initialMessage: "Olá! Estou em modo Foco e posso não ver a sua mensagem imediatamente. É urgente?",
                    urgentQuestion: "Responda SIM se for urgente, caso contrário responderei quando estiver disponível.",
                    urgentConfirmed: "Entendi, é urgente! Para me contactar imediatamente, ligue-me duas vezes em menos de 3 minutos. O meu telefone tocará na segunda chamada.",
                    callInstructions: "📞 Para urgências: Ligue duas vezes em menos de 3 minutos.",
                    focusModeExplanation: "O modo Foco ajuda-me a concentrar sem interrupções. Chamadas urgentes passarão se ligar duas vezes em menos de 3 minutos."
                ),
                "nl": AutoReplyTemplate(
                    language: "nl",
                    languageName: "Nederlands",
                    initialMessage: "Hallo! Ik ben in Focus-modus en zie je bericht misschien niet direct. Is het dringend?",
                    urgentQuestion: "Antwoord JA als het dringend is, anders reageer ik zodra ik beschikbaar ben.",
                    urgentConfirmed: "Begrepen, het is dringend! Bel me twee keer binnen 3 minuten om me direct te bereiken. Mijn telefoon gaat over bij het tweede gesprek.",
                    callInstructions: "📞 Voor dringende zaken: Bel twee keer binnen 3 minuten.",
                    focusModeExplanation: "Focus-modus helpt me te concentreren zonder onderbrekingen. Dringende oproepen komen door als je twee keer belt binnen 3 minuten."
                ),
                "ja": AutoReplyTemplate(
                    language: "ja",
                    languageName: "日本語",
                    initialMessage: "こんにちは！集中モード中のため、メッセージをすぐに確認できない場合があります。緊急ですか？",
                    urgentQuestion: "緊急の場合は「はい」と返信してください。そうでなければ、都合がつき次第返信します。",
                    urgentConfirmed: "了解しました、緊急ですね！すぐに連絡を取るには、3分以内に2回電話してください。2回目の電話で着信音が鳴ります。",
                    callInstructions: "📞 緊急の場合：3分以内に2回電話してください。",
                    focusModeExplanation: "集中モードは中断なく集中するのに役立ちます。3分以内に2回電話すると、緊急の電話は通じます。"
                ),
                "zh": AutoReplyTemplate(
                    language: "zh",
                    languageName: "中文",
                    initialMessage: "你好！我目前处于专注模式，可能无法立即看到你的消息。这是紧急情况吗？",
                    urgentQuestion: "如果紧急，请回复「是」，否则我会在方便时回复你。",
                    urgentConfirmed: "收到，这是紧急情况！要立即联系我，请在3分钟内给我打两次电话。我的手机会在第二次来电时响铃。",
                    callInstructions: "📞 紧急情况：请在3分钟内打两次电话。",
                    focusModeExplanation: "专注模式帮助我集中注意力不被打扰。如果你在3分钟内打两次电话，紧急来电会接通。"
                ),
                "ko": AutoReplyTemplate(
                    language: "ko",
                    languageName: "한국어",
                    initialMessage: "안녕하세요! 현재 집중 모드 중이라 메시지를 바로 확인하지 못할 수 있습니다. 급한 일인가요?",
                    urgentQuestion: "급하시면 '예'라고 답장해 주세요. 아니면 시간이 되면 연락드리겠습니다.",
                    urgentConfirmed: "알겠습니다, 급한 일이군요! 바로 연락하려면 3분 이내에 두 번 전화해 주세요. 두 번째 전화에 벨이 울립니다.",
                    callInstructions: "📞 긴급 연락: 3분 이내에 두 번 전화해 주세요.",
                    focusModeExplanation: "집중 모드는 방해 없이 집중하는 데 도움이 됩니다. 3분 이내에 두 번 전화하면 긴급 전화가 연결됩니다."
                ),
                "ru": AutoReplyTemplate(
                    language: "ru",
                    languageName: "Русский",
                    initialMessage: "Привет! Я в режиме фокусировки и могу не сразу увидеть ваше сообщение. Это срочно?",
                    urgentQuestion: "Ответьте ДА, если срочно, иначе я отвечу, когда буду свободен.",
                    urgentConfirmed: "Понял, это срочно! Чтобы связаться со мной немедленно, позвоните мне дважды в течение 3 минут. Мой телефон зазвонит на второй звонок.",
                    callInstructions: "📞 Для срочной связи: Позвоните дважды в течение 3 минут.",
                    focusModeExplanation: "Режим фокусировки помогает мне сосредоточиться без отвлечений. Срочные звонки пройдут, если вы позвоните дважды в течение 3 минут."
                ),
                "ar": AutoReplyTemplate(
                    language: "ar",
                    languageName: "العربية",
                    initialMessage: "مرحباً! أنا في وضع التركيز وقد لا أرى رسالتك فوراً. هل هذا أمر عاجل؟",
                    urgentQuestion: "أجب بـ 'نعم' إذا كان الأمر عاجلاً، وإلا سأرد عندما أكون متاحاً.",
                    urgentConfirmed: "فهمت، هذا عاجل! للتواصل معي فوراً، اتصل بي مرتين خلال 3 دقائق. هاتفي سيرن في الاتصال الثاني.",
                    callInstructions: "📞 للطوارئ: اتصل مرتين خلال 3 دقائق.",
                    focusModeExplanation: "وضع التركيز يساعدني على التركيز دون انقطاع. المكالمات العاجلة ستصل إذا اتصلت مرتين خلال 3 دقائق."
                )
            ]
        }
    }

    public struct CallerNotificationTemplate: Codable, Sendable {
        public let language: String
        public let missedCallSMS: String
        public let voiceGreeting: String

        public static func defaultTemplates() -> [String: CallerNotificationTemplate] {
            [
                "en": CallerNotificationTemplate(
                    language: "en",
                    missedCallSMS: "Hi, I missed your call because I'm in Focus Mode. If it's urgent, please call again within 3 minutes - my phone will ring on the second call. Otherwise, I'll call you back soon.",
                    voiceGreeting: "Hello. The person you're calling has Focus Mode enabled. If this is urgent, please hang up and call again within three minutes. Your second call will ring through. Otherwise, please leave a message and they'll return your call. Thank you."
                ),
                "fr": CallerNotificationTemplate(
                    language: "fr",
                    missedCallSMS: "Bonjour, j'ai manqué votre appel car je suis en mode Concentration. Si c'est urgent, rappelez dans les 3 minutes - mon téléphone sonnera au deuxième appel. Sinon, je vous rappellerai bientôt.",
                    voiceGreeting: "Bonjour. La personne que vous appelez a activé le mode Concentration. Si c'est urgent, raccrochez et rappelez dans les trois minutes. Votre deuxième appel passera. Sinon, veuillez laisser un message et on vous rappellera. Merci."
                ),
                "de": CallerNotificationTemplate(
                    language: "de",
                    missedCallSMS: "Hallo, ich habe Ihren Anruf verpasst, da ich im Fokus-Modus bin. Bei Dringlichkeit rufen Sie bitte innerhalb von 3 Minuten erneut an - mein Telefon klingelt beim zweiten Anruf. Andernfalls rufe ich Sie bald zurück.",
                    voiceGreeting: "Hallo. Die Person, die Sie anrufen, hat den Fokus-Modus aktiviert. Wenn es dringend ist, legen Sie auf und rufen Sie innerhalb von drei Minuten erneut an. Ihr zweiter Anruf wird durchgestellt. Andernfalls hinterlassen Sie bitte eine Nachricht. Danke."
                ),
                "it": CallerNotificationTemplate(
                    language: "it",
                    missedCallSMS: "Ciao, ho perso la tua chiamata perché sono in modalità Focus. Se è urgente, richiama entro 3 minuti - il mio telefono squillerà alla seconda chiamata. Altrimenti, ti richiamerò presto.",
                    voiceGreeting: "Ciao. La persona che stai chiamando ha attivato la modalità Focus. Se è urgente, riaggancia e richiama entro tre minuti. La seconda chiamata squillerà. Altrimenti, lascia un messaggio e ti richiamerà. Grazie."
                ),
                "es": CallerNotificationTemplate(
                    language: "es",
                    missedCallSMS: "Hola, perdí tu llamada porque estoy en modo Concentración. Si es urgente, vuelve a llamar en 3 minutos - mi teléfono sonará en la segunda llamada. Si no, te llamaré pronto.",
                    voiceGreeting: "Hola. La persona a la que llamas tiene el modo Concentración activado. Si es urgente, cuelga y vuelve a llamar en tres minutos. Tu segunda llamada sonará. Si no, deja un mensaje y te devolverán la llamada. Gracias."
                )
            ]
        }
    }

    public struct UrgentResponseTemplate: Codable, Sendable {
        public let language: String
        public let yesKeywords: [String]
        public let noKeywords: [String]
        public let emergencyKeywords: [String]
    }

    public init() {
        self.autoReply = AutoReplyTemplate.defaultTemplates()
        self.callerNotification = CallerNotificationTemplate.defaultTemplates()
        self.urgentResponse = [
            "en": UrgentResponseTemplate(language: "en", yesKeywords: ["yes", "urgent", "emergency", "asap", "help", "important", "critical", "911"], noKeywords: ["no", "not urgent", "later", "whenever", "no rush"], emergencyKeywords: ["911", "emergency", "ambulance", "police", "fire", "hospital", "dying", "accident"]),
            "fr": UrgentResponseTemplate(language: "fr", yesKeywords: ["oui", "urgent", "urgence", "aide", "important", "critique", "secours"], noKeywords: ["non", "pas urgent", "plus tard", "quand tu peux"], emergencyKeywords: ["urgence", "ambulance", "police", "pompiers", "hôpital", "accident"]),
            "de": UrgentResponseTemplate(language: "de", yesKeywords: ["ja", "dringend", "notfall", "hilfe", "wichtig", "kritisch", "sofort"], noKeywords: ["nein", "nicht dringend", "später", "keine eile"], emergencyKeywords: ["notfall", "krankenwagen", "polizei", "feuerwehr", "krankenhaus", "unfall"]),
            "it": UrgentResponseTemplate(language: "it", yesKeywords: ["sì", "urgente", "emergenza", "aiuto", "importante", "critico", "subito"], noKeywords: ["no", "non urgente", "dopo", "con calma"], emergencyKeywords: ["emergenza", "ambulanza", "polizia", "pompieri", "ospedale", "incidente"]),
            "es": UrgentResponseTemplate(language: "es", yesKeywords: ["sí", "urgente", "emergencia", "ayuda", "importante", "crítico", "inmediatamente"], noKeywords: ["no", "no urgente", "luego", "sin prisa"], emergencyKeywords: ["emergencia", "ambulancia", "policía", "bomberos", "hospital", "accidente"])
        ]
    }
}
