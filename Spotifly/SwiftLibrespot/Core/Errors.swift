//
//  Errors.swift
//  SwiftLibrespot
//
//  Error types for the Swift librespot implementation
//

import Foundation

/// Errors that can occur during Spotify connection and playback
public enum LibrespotError: Error, LocalizedError, Sendable, Equatable {
    // MARK: - Connection Errors

    case connectionFailed(String)
    case authenticationFailed(String)
    /// The accesspoint refused the login because the account is not Premium.
    case premiumRequired
    case sessionExpired
    case networkUnavailable

    // MARK: - Protocol Errors

    case handshakeFailed(String)
    case invalidPacket(String)
    case encryptionError(String)
    case protobufError(String)
    case macMismatch

    // MARK: - Playback Errors

    case trackNotFound(String)
    /// Spotify lists no file for this track, and none for a substitute: it withholds the track
    /// from this account. Unlike `trackNotFound` or a failed request, this is a fact about the
    /// track, so loading it again gets the same answer. Auto-advance skips it; see
    /// `AutoAdvance`.
    case trackUnavailable(name: String)
    case audioKeyFailed(String)
    case audioKeyError(Int)
    case decryptionFailed(String)
    case decodingFailed(String)
    case cdnError(String)
    /// A request the playback stack makes to spclient was answered with an error, after its
    /// retries.
    case requestFailed(String, status: Int)

    // MARK: - SPIRC/Connect Errors

    case spircNotReady
    case deviceNotFound(String)
    case transferFailed(String)
    case commandFailed(String)

    // MARK: - General Errors

    case notInitialized
    case invalidState(String)
    case timeout(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case let .connectionFailed(message):
            "Connection failed: \(message)"
        case let .authenticationFailed(message):
            "Authentication failed: \(message)"
        case .premiumRequired:
            String(localized: "playback.needs_premium")
        case .sessionExpired:
            "Session expired, please re-authenticate"
        case .networkUnavailable:
            "Network unavailable"
        case let .handshakeFailed(message):
            "Handshake failed: \(message)"
        case let .invalidPacket(message):
            "Invalid packet: \(message)"
        case let .encryptionError(message):
            "Encryption error: \(message)"
        case let .protobufError(message):
            "Protobuf error: \(message)"
        case .macMismatch:
            "MAC verification failed"
        case let .trackNotFound(uri):
            "Track not found: \(uri)"
        case let .trackUnavailable(name):
            String(localized: "error.track_unavailable \(name)")
        case let .audioKeyFailed(message):
            "Failed to get audio key: \(message)"
        case .audioKeyError(1):
            // Code 1 is a refusal that belongs to the account rather than to the request, and
            // there is no fixing it from here; see `isPermanentAudioKeyRefusal`.
            String(localized: "error.audio_key_refused")
        case let .audioKeyError(code):
            "Audio key error: \(code)"
        case let .decryptionFailed(message):
            "Decryption failed: \(message)"
        case let .decodingFailed(message):
            "Decoding failed: \(message)"
        case let .cdnError(message):
            "CDN error: \(message)"
        case let .requestFailed(request, status):
            "\(request) failed: HTTP \(status)"
        case .spircNotReady:
            "SPIRC controller not ready"
        case let .deviceNotFound(id):
            "Device not found: \(id)"
        case let .transferFailed(message):
            "Playback transfer failed: \(message)"
        case let .commandFailed(message):
            "Command failed: \(message)"
        case .notInitialized:
            "Not initialized"
        case let .invalidState(message):
            "Invalid state: \(message)"
        case let .timeout(message):
            "Timeout: \(message)"
        case let .unknown(message):
            "Unknown error: \(message)"
        }
    }

    /// Whether Spotify refused the audio key for good.
    ///
    /// Code 1 is a fact about the account, not about the request: every track is answered the
    /// same way, three gateways and as many device ids included (measured 2026-11-14 on an
    /// account created after Spotify's cutoff), so no retry and no rebuild of the request
    /// changes it. Spotify's own clients play such an account through a decryption scheme
    /// librespot cannot use, which is why the answer is another device, not another attempt.
    ///
    /// Code 2 is a burst that clears up, and is not this. Nothing here paces or retries the
    /// request either way; what this decides is whether a start is worth trying here at all.
    var isPermanentAudioKeyRefusal: Bool {
        self == .audioKeyError(1)
    }
}
