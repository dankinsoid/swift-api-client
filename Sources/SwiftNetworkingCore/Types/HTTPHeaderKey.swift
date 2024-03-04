import Foundation

public extension HTTPHeader {

	/// Type safe header key wrapper
	struct Key {

		public var rawValue: String

		public init(_ rawValue: String) { self.rawValue = rawValue }

		/// `Authorization`
		public static let authorization: HTTPHeader.Key = "Authorization"
		/// `Accept`
		public static let accept: HTTPHeader.Key = "Accept"
		/// `Accept-Encoding`
		public static let acceptEncoding: HTTPHeader.Key = "Accept-Encoding"
		/// `Accept-Language`
		public static let acceptLanguage: HTTPHeader.Key = "Accept-Language"
		/// `Accept-Charset`
		public static let acceptCharset: HTTPHeader.Key = "Accept-Charset"
		/// `Also-Control`
		public static let alsoControl: HTTPHeader.Key = "Also-Control"
		/// `Alternate-Recipient`
		public static let alternateRecipient: HTTPHeader.Key = "Alternate-Recipient"
		/// `Approved`
		public static let approved: HTTPHeader.Key = "Approved"
		/// `ARC-Authentication-Results`
		public static let aRCAuthenticationResults: HTTPHeader.Key = "ARC-Authentication-Results"
		/// `ARC-Message-Signature`
		public static let aRCMessageSignature: HTTPHeader.Key = "ARC-Message-Signature"
		/// `ARC-Seal`
		public static let aRCSeal: HTTPHeader.Key = "ARC-Seal"
		/// `Archive`
		public static let archive: HTTPHeader.Key = "Archive"
		/// `Archived-At`
		public static let archivedAt: HTTPHeader.Key = "Archived-At"
		/// `Article-Names`
		public static let articleNames: HTTPHeader.Key = "Article-Names"
		/// `Article-Updates`
		public static let articleUpdates: HTTPHeader.Key = "Article-Updates"
		/// `Authentication-Results`
		public static let authenticationResults: HTTPHeader.Key = "Authentication-Results"
		/// `Auto-Submitted`
		public static let autoSubmitted: HTTPHeader.Key = "Auto-Submitted"
		/// `Autoforwarded`
		public static let autoforwarded: HTTPHeader.Key = "Autoforwarded"
		/// `Autosubmitted`
		public static let autosubmitted: HTTPHeader.Key = "Autosubmitted"
		/// `Base`
		public static let base: HTTPHeader.Key = "Base"
		/// `Bcc`
		public static let bcc: HTTPHeader.Key = "Bcc"
		/// `Body`
		public static let body: HTTPHeader.Key = "Body"
		/// `Cancel-Key`
		public static let cancelKey: HTTPHeader.Key = "Cancel-Key"
		/// `Cancel-Lock`
		public static let cancelLock: HTTPHeader.Key = "Cancel-Lock"
		/// `Cc`
		public static let cc: HTTPHeader.Key = "Cc"
		/// `Comments`
		public static let comments: HTTPHeader.Key = "Comments"
		/// `Cookie`
		public static let cookie: HTTPHeader.Key = "Cookie"
		/// `Content-Alternative`
		public static let contentAlternative: HTTPHeader.Key = "Content-Alternative"
		/// `Content-Base`
		public static let contentBase: HTTPHeader.Key = "Content-Base"
		/// `Content-Description`
		public static let contentDescription: HTTPHeader.Key = "Content-Description"
		/// `Content-Disposition`
		public static let contentDisposition: HTTPHeader.Key = "Content-Disposition"
		/// `Content-Duration`
		public static let contentDuration: HTTPHeader.Key = "Content-Duration"
		/// `Content-features`
		public static let contentfeatures: HTTPHeader.Key = "Content-features"
		/// `Content-ID`
		public static let contentID: HTTPHeader.Key = "Content-ID"
		/// `Content-Identifier`
		public static let contentIdentifier: HTTPHeader.Key = "Content-Identifier"
		/// `Content-Language`
		public static let contentLanguage: HTTPHeader.Key = "Content-Language"
		/// `Content-Encoding`
		public static let contentEncoding: HTTPHeader.Key = "Content-Encoding"
		/// `Content-Location`
		public static let contentLocation: HTTPHeader.Key = "Content-Location"
		/// `Content-MD5`
		public static let contentMD5: HTTPHeader.Key = "Content-MD5"
		/// `Content-Return`
		public static let contentReturn: HTTPHeader.Key = "Content-Return"
		/// `Content-Transfer-Encoding`
		public static let contentTransferEncoding: HTTPHeader.Key = "Content-Transfer-Encoding"
		/// `Content-Translation-Type`
		public static let contentTranslationType: HTTPHeader.Key = "Content-Translation-Type"
		/// `Content-Type`
		public static let contentType: HTTPHeader.Key = "Content-Type"
		/// `Control`
		public static let control: HTTPHeader.Key = "Control"
		/// `Conversion`
		public static let conversion: HTTPHeader.Key = "Conversion"
		/// `Conversion-With-Loss`
		public static let conversionWithLoss: HTTPHeader.Key = "Conversion-With-Loss"
		/// `DL-Expansion-History`
		public static let dLExpansionHistory: HTTPHeader.Key = "DL-Expansion-History"
		/// `Date`
		public static let date: HTTPHeader.Key = "Date"
		/// `Date-Received`
		public static let dateReceived: HTTPHeader.Key = "Date-Received"
		/// `Deferred-Delivery`
		public static let deferredDelivery: HTTPHeader.Key = "Deferred-Delivery"
		/// `Delivery-Date`
		public static let deliveryDate: HTTPHeader.Key = "Delivery-Date"
		/// `Discarded-X400-IPMS-Extensions`
		public static let discardedX400IPMSExtensions: HTTPHeader.Key = "Discarded-X400-IPMS-Extensions"
		/// `Discarded-X400-MTS-Extensions`
		public static let discardedX400MTSExtensions: HTTPHeader.Key = "Discarded-X400-MTS-Extensions"
		/// `Disclose-Recipients`
		public static let discloseRecipients: HTTPHeader.Key = "Disclose-Recipients"
		/// `Disposition-Notification-Options`
		public static let dispositionNotificationOptions: HTTPHeader.Key = "Disposition-Notification-Options"
		/// `Disposition-Notification-To`
		public static let dispositionNotificationTo: HTTPHeader.Key = "Disposition-Notification-To"
		/// `Distribution`
		public static let distribution: HTTPHeader.Key = "Distribution"
		/// `DKIM-Signature`
		public static let dKIMSignature: HTTPHeader.Key = "DKIM-Signature"
		/// `Downgraded-Bcc`
		public static let downgradedBcc: HTTPHeader.Key = "Downgraded-Bcc"
		/// `Downgraded-Cc`
		public static let downgradedCc: HTTPHeader.Key = "Downgraded-Cc"
		/// `Downgraded-Disposition-Notification-To`
		public static let downgradedDispositionNotificationTo: HTTPHeader.Key = "Downgraded-Disposition-Notification-To"
		/// `Downgraded-Final-Recipient`
		public static let downgradedFinalRecipient: HTTPHeader.Key = "Downgraded-Final-Recipient"
		/// `Downgraded-From`
		public static let downgradedFrom: HTTPHeader.Key = "Downgraded-From"
		/// `Downgraded-In-Reply-To`
		public static let downgradedInReplyTo: HTTPHeader.Key = "Downgraded-In-Reply-To"
		/// `Downgraded-Mail-From`
		public static let downgradedMailFrom: HTTPHeader.Key = "Downgraded-Mail-From"
		/// `Downgraded-Message-Id`
		public static let downgradedMessageId: HTTPHeader.Key = "Downgraded-Message-Id"
		/// `Downgraded-Original-Recipient`
		public static let downgradedOriginalRecipient: HTTPHeader.Key = "Downgraded-Original-Recipient"
		/// `Downgraded-Rcpt-To`
		public static let downgradedRcptTo: HTTPHeader.Key = "Downgraded-Rcpt-To"
		/// `Downgraded-References`
		public static let downgradedReferences: HTTPHeader.Key = "Downgraded-References"
		/// `Downgraded-Reply-To`
		public static let downgradedReplyTo: HTTPHeader.Key = "Downgraded-Reply-To"
		/// `Downgraded-Resent-Bcc`
		public static let downgradedResentBcc: HTTPHeader.Key = "Downgraded-Resent-Bcc"
		/// `Downgraded-Resent-Cc`
		public static let downgradedResentCc: HTTPHeader.Key = "Downgraded-Resent-Cc"
		/// `Downgraded-Resent-From`
		public static let downgradedResentFrom: HTTPHeader.Key = "Downgraded-Resent-From"
		/// `Downgraded-Resent-Reply-To`
		public static let downgradedResentReplyTo: HTTPHeader.Key = "Downgraded-Resent-Reply-To"
		/// `Downgraded-Resent-Sender`
		public static let downgradedResentSender: HTTPHeader.Key = "Downgraded-Resent-Sender"
		/// `Downgraded-Resent-To`
		public static let downgradedResentTo: HTTPHeader.Key = "Downgraded-Resent-To"
		/// `Downgraded-Return-Path`
		public static let downgradedReturnPath: HTTPHeader.Key = "Downgraded-Return-Path"
		/// `Downgraded-Sender`
		public static let downgradedSender: HTTPHeader.Key = "Downgraded-Sender"
		/// `Downgraded-To`
		public static let downgradedTo: HTTPHeader.Key = "Downgraded-To"
		/// `Encoding`
		public static let encoding: HTTPHeader.Key = "Encoding"
		/// `Encrypted`
		public static let encrypted: HTTPHeader.Key = "Encrypted"
		/// `Expires`
		public static let expires: HTTPHeader.Key = "Expires"
		/// `Expiry-Date`
		public static let expiryDate: HTTPHeader.Key = "Expiry-Date"
		/// `Followup-To`
		public static let followupTo: HTTPHeader.Key = "Followup-To"
		/// `From`
		public static let from: HTTPHeader.Key = "From"
		/// `Generate-Delivery-Report`
		public static let generateDeliveryReport: HTTPHeader.Key = "Generate-Delivery-Report"
		/// `Importance`
		public static let importance: HTTPHeader.Key = "Importance"
		/// `In-Reply-To`
		public static let inReplyTo: HTTPHeader.Key = "In-Reply-To"
		/// `Incomplete-Copy`
		public static let incompleteCopy: HTTPHeader.Key = "Incomplete-Copy"
		/// `Injection-Date`
		public static let injectionDate: HTTPHeader.Key = "Injection-Date"
		/// `Injection-Info`
		public static let injectionInfo: HTTPHeader.Key = "Injection-Info"
		/// `Keywords`
		public static let keywords: HTTPHeader.Key = "Keywords"
		/// `Language`
		public static let language: HTTPHeader.Key = "Language"
		/// `Latest-Delivery-Time`
		public static let latestDeliveryTime: HTTPHeader.Key = "Latest-Delivery-Time"
		/// `Lines`
		public static let lines: HTTPHeader.Key = "Lines"
		/// `List-Archive`
		public static let listArchive: HTTPHeader.Key = "List-Archive"
		/// `List-Help`
		public static let listHelp: HTTPHeader.Key = "List-Help"
		/// `List-ID`
		public static let listID: HTTPHeader.Key = "List-ID"
		/// `List-Owner`
		public static let listOwner: HTTPHeader.Key = "List-Owner"
		/// `List-Post`
		public static let listPost: HTTPHeader.Key = "List-Post"
		/// `List-Subscribe`
		public static let listSubscribe: HTTPHeader.Key = "List-Subscribe"
		/// `List-Unsubscribe`
		public static let listUnsubscribe: HTTPHeader.Key = "List-Unsubscribe"
		/// `List-Unsubscribe-Post`
		public static let listUnsubscribePost: HTTPHeader.Key = "List-Unsubscribe-Post"
		/// `Message-Context`
		public static let messageContext: HTTPHeader.Key = "Message-Context"
		/// `Message-ID`
		public static let messageID: HTTPHeader.Key = "Message-ID"
		/// `Message-Type`
		public static let messageType: HTTPHeader.Key = "Message-Type"
		/// `MIME-Version`
		public static let mIMEVersion: HTTPHeader.Key = "MIME-Version"
		/// `MMHS-Exempted-Address`
		public static let mMHSExemptedAddress: HTTPHeader.Key = "MMHS-Exempted-Address"
		/// `MMHS-Extended-Authorisation-Info`
		public static let mMHSExtendedAuthorisationInfo: HTTPHeader.Key = "MMHS-Extended-Authorisation-Info"
		/// `MMHS-Subject-Indicator-Codes`
		public static let mMHSSubjectIndicatorCodes: HTTPHeader.Key = "MMHS-Subject-Indicator-Codes"
		/// `MMHS-Handling-Instructions`
		public static let mMHSHandlingInstructions: HTTPHeader.Key = "MMHS-Handling-Instructions"
		/// `MMHS-Message-Instructions`
		public static let mMHSMessageInstructions: HTTPHeader.Key = "MMHS-Message-Instructions"
		/// `MMHS-Codress-Message-Indicator`
		public static let mMHSCodressMessageIndicator: HTTPHeader.Key = "MMHS-Codress-Message-Indicator"
		/// `MMHS-Originator-Reference`
		public static let mMHSOriginatorReference: HTTPHeader.Key = "MMHS-Originator-Reference"
		/// `MMHS-Primary-Precedence`
		public static let mMHSPrimaryPrecedence: HTTPHeader.Key = "MMHS-Primary-Precedence"
		/// `MMHS-Copy-Precedence`
		public static let mMHSCopyPrecedence: HTTPHeader.Key = "MMHS-Copy-Precedence"
		/// `MMHS-Message-Type`
		public static let mMHSMessageType: HTTPHeader.Key = "MMHS-Message-Type"
		/// `MMHS-Other-Recipients-Indicator-To`
		public static let mMHSOtherRecipientsIndicatorTo: HTTPHeader.Key = "MMHS-Other-Recipients-Indicator-To"
		/// `MMHS-Other-Recipients-Indicator-CC`
		public static let mMHSOtherRecipientsIndicatorCC: HTTPHeader.Key = "MMHS-Other-Recipients-Indicator-CC"
		/// `MMHS-Acp127-Message-Identifier`
		public static let mMHSAcp127MessageIdentifier: HTTPHeader.Key = "MMHS-Acp127-Message-Identifier"
		/// `MMHS-Originator-PLAD`
		public static let mMHSOriginatorPLAD: HTTPHeader.Key = "MMHS-Originator-PLAD"
		/// `MT-Priority`
		public static let mTPriority: HTTPHeader.Key = "MT-Priority"
		/// `Newsgroups`
		public static let newsgroups: HTTPHeader.Key = "Newsgroups"
		/// `NNTP-Posting-Date`
		public static let nNTPPostingDate: HTTPHeader.Key = "NNTP-Posting-Date"
		/// `NNTP-Posting-Host`
		public static let nNTPPostingHost: HTTPHeader.Key = "NNTP-Posting-Host"
		/// `Obsoletes`
		public static let obsoletes: HTTPHeader.Key = "Obsoletes"
		/// `Organization`
		public static let organization: HTTPHeader.Key = "Organization"
		/// `Original-Encoded-Information-Types`
		public static let originalEncodedInformationTypes: HTTPHeader.Key = "Original-Encoded-Information-Types"
		/// `Original-From`
		public static let originalFrom: HTTPHeader.Key = "Original-From"
		/// `Original-Message-ID`
		public static let originalMessageID: HTTPHeader.Key = "Original-Message-ID"
		/// `Original-Recipient`
		public static let originalRecipient: HTTPHeader.Key = "Original-Recipient"
		/// `Original-Sender`
		public static let originalSender: HTTPHeader.Key = "Original-Sender"
		/// `Originator-Return-Address`
		public static let originatorReturnAddress: HTTPHeader.Key = "Originator-Return-Address"
		/// `Original-Subject`
		public static let originalSubject: HTTPHeader.Key = "Original-Subject"
		/// `Path`
		public static let path: HTTPHeader.Key = "Path"
		/// `PICS-Label`
		public static let pICSLabel: HTTPHeader.Key = "PICS-Label"
		/// `Posting-Version`
		public static let postingVersion: HTTPHeader.Key = "Posting-Version"
		/// `Prevent-NonDelivery-Report`
		public static let preventNonDeliveryReport: HTTPHeader.Key = "Prevent-NonDelivery-Report"
		/// `Priority`
		public static let priority: HTTPHeader.Key = "Priority"
		/// `Received`
		public static let received: HTTPHeader.Key = "Received"
		/// `Received-SPF`
		public static let receivedSPF: HTTPHeader.Key = "Received-SPF"
		/// `References`
		public static let references: HTTPHeader.Key = "References"
		/// `Relay-Version`
		public static let relayVersion: HTTPHeader.Key = "Relay-Version"
		/// `Reply-By`
		public static let replyBy: HTTPHeader.Key = "Reply-By"
		/// `Reply-To`
		public static let replyTo: HTTPHeader.Key = "Reply-To"
		/// `Require-Recipient-Valid-Since`
		public static let requireRecipientValidSince: HTTPHeader.Key = "Require-Recipient-Valid-Since"
		/// `Resent-Bcc`
		public static let resentBcc: HTTPHeader.Key = "Resent-Bcc"
		/// `Resent-Cc`
		public static let resentCc: HTTPHeader.Key = "Resent-Cc"
		/// `Resent-Date`
		public static let resentDate: HTTPHeader.Key = "Resent-Date"
		/// `Resent-From`
		public static let resentFrom: HTTPHeader.Key = "Resent-From"
		/// `Resent-Message-ID`
		public static let resentMessageID: HTTPHeader.Key = "Resent-Message-ID"
		/// `Resent-Reply-To`
		public static let resentReplyTo: HTTPHeader.Key = "Resent-Reply-To"
		/// `Resent-Sender`
		public static let resentSender: HTTPHeader.Key = "Resent-Sender"
		/// `Resent-To`
		public static let resentTo: HTTPHeader.Key = "Resent-To"
		/// `Return-Path`
		public static let returnPath: HTTPHeader.Key = "Return-Path"
		/// `See-Also`
		public static let seeAlso: HTTPHeader.Key = "See-Also"
		/// `Sender`
		public static let sender: HTTPHeader.Key = "Sender"
		/// `Sensitivity`
		public static let sensitivity: HTTPHeader.Key = "Sensitivity"
		/// `Set-Cookie`
		public static let setCookie: HTTPHeader.Key = "Set-Cookie"
		/// `Solicitation`
		public static let solicitation: HTTPHeader.Key = "Solicitation"
		/// `Subject`
		public static let subject: HTTPHeader.Key = "Subject"
		/// `Summary`
		public static let summary: HTTPHeader.Key = "Summary"
		/// `Supersedes`
		public static let supersedes: HTTPHeader.Key = "Supersedes"
		/// `TLS-Report-Domain`
		public static let tLSReportDomain: HTTPHeader.Key = "TLS-Report-Domain"
		/// `TLS-Report-Submitter`
		public static let tLSReportSubmitter: HTTPHeader.Key = "TLS-Report-Submitter"
		/// `TLS-Required`
		public static let tLSRequired: HTTPHeader.Key = "TLS-Required"
		/// `To`
		public static let to: HTTPHeader.Key = "To"
		/// `User-Agent`
		public static let userAgent: HTTPHeader.Key = "User-Agent"
		/// `VBR-Info`
		public static let vBRInfo: HTTPHeader.Key = "VBR-Info"
		/// `X400-Content-Identifier`
		public static let x400ContentIdentifier: HTTPHeader.Key = "X400-Content-Identifier"
		/// `X400-Content-Return`
		public static let x400ContentReturn: HTTPHeader.Key = "X400-Content-Return"
		/// `X400-Content-Type`
		public static let x400ContentType: HTTPHeader.Key = "X400-Content-Type"
		/// `X400-MTS-Identifier`
		public static let x400MTSIdentifier: HTTPHeader.Key = "X400-MTS-Identifier"
		/// `X400-Originator`
		public static let x400Originator: HTTPHeader.Key = "X400-Originator"
		/// `X400-Received`
		public static let x400Received: HTTPHeader.Key = "X400-Received"
		/// `X400-Recipients`
		public static let x400Recipients: HTTPHeader.Key = "X400-Recipients"
		/// `X400-Trace`
		public static let x400Trace: HTTPHeader.Key = "X400-Trace"
		/// `Xrefcase`
		public static let xrefcase: HTTPHeader.Key = "Xrefcase"
		/// `Apparently-To`
		public static let apparentlyTo: HTTPHeader.Key = "Apparently-To"
		/// `Author`
		public static let author: HTTPHeader.Key = "Author"
		/// `EDIINT-Features`
		public static let eDIINTFeatures: HTTPHeader.Key = "EDIINT-Features"
		/// `Eesst-Version`
		public static let eesstVersion: HTTPHeader.Key = "Eesst-Version"
		/// `Errors-To`
		public static let errorsTo: HTTPHeader.Key = "Errors-To"
		/// `Form-Sub`
		public static let formSub: HTTPHeader.Key = "Form-Sub"
		/// `Jabber-ID`
		public static let jabberID: HTTPHeader.Key = "Jabber-ID"
		/// `MMHS-Authorizing-Users`
		public static let mMHSAuthorizingUsers: HTTPHeader.Key = "MMHS-Authorizing-Users"
		/// `Privicon`
		public static let privicon: HTTPHeader.Key = "Privicon"
		/// `SIO-Label`
		public static let sIOLabel: HTTPHeader.Key = "SIO-Label"
		/// `SIO-Label-History`
		public static let sIOLabelHistory: HTTPHeader.Key = "SIO-Label-History"
		/// `X-Archived-At`
		public static let xArchivedAt: HTTPHeader.Key = "X-Archived-At"
		/// `X-Mittente`
		public static let xMittente: HTTPHeader.Key = "X-Mittente"
		/// `X-PGP-Sig`
		public static let xPGPSig: HTTPHeader.Key = "X-PGP-Sig"
		/// `X-Ricevuta`
		public static let xRicevuta: HTTPHeader.Key = "X-Ricevuta"
		/// `X-Riferimento-Message-ID`
		public static let xRiferimentoMessageID: HTTPHeader.Key = "X-Riferimento-Message-ID"
		/// `X-TipoRicevuta`
		public static let xTipoRicevuta: HTTPHeader.Key = "X-TipoRicevuta"
		/// `X-Trasporto`
		public static let xTrasporto: HTTPHeader.Key = "X-Trasporto"
		/// `X-VerificaSicurezza`
		public static let xVerificaSicurezza: HTTPHeader.Key = "X-VerificaSicurezza"
	}
}

extension HTTPHeader.Key: Hashable, Codable, ExpressibleByStringLiteral,
	RawRepresentable, CustomStringConvertible, Equatable
{

	public var description: String { rawValue }

	/// Creates a new instance with the specified raw value.
	/// - Parameter rawValue: The raw value to use for the new instance.
	public init?(rawValue: String) { self.init(rawValue) }

	/// Creates an instance initialized to the given string value.
	///
	/// - Parameter value: The value of the new instance.
	public init(stringLiteral value: String) { self.init(value) }

	/// Creates a new instance by decoding from the given decoder.
	///
	/// This initializer throws an error if reading from the decoder fails, or
	/// if the data read is corrupted or otherwise invalid.
	///
	/// - Parameter decoder: The decoder to read data from.
	public init(from decoder: Decoder) throws {
		try self.init(String(from: decoder))
	}

	/// Hashes the essential components of this value by feeding them into the
	/// given hasher.
	///
	/// Implement this method to conform to the `Hashable` protocol. The
	/// components used for hashing must be the same as the components compared
	/// in your type's `==` operator implementation. Call `hasher.combine(_:)`
	/// with each of these components.
	///
	/// - Important: Never call `finalize()` on `hasher`. Doing so may become a
	///   compile-time error in the future.
	///
	/// - Parameter hasher: The hasher to use when combining the components
	///   of this instance.
	public func hash(into hasher: inout Hasher) {
		rawValue.hash(into: &hasher)
	}

	/// Encodes this value into the given encoder.
	///
	/// If the value fails to encode anything, `encoder` will encode an empty
	/// keyed container in its place.
	///
	/// This function throws an error if any values are invalid for the given
	/// encoder's format.
	///
	/// - Parameter encoder: The encoder to write data to.
	public func encode(to encoder: Encoder) throws {
		try rawValue.encode(to: encoder)
	}
}
