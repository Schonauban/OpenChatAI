import Foundation

enum AppError: LocalizedError {
    case apiError(String)
    case audioError(String)
    case transcriptionError(String)
    case ttsError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "API Error: \(message)"
        case .audioError(let message):
            return "Audio Error: \(message)"
        case .transcriptionError(let message):
            return "Transcription Error: \(message)"
        case .ttsError(let message):
            return "Text-to-Speech Error: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        }
    }
}

class ErrorHandler {
    static func handle(_ error: Error) -> String {
        if let appError = error as? AppError {
            return appError.localizedDescription
        } else {
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
} 