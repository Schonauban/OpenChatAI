import Foundation

enum OpenAIServiceError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
    case invalidAPIKey
    case invalidAudioFile
    case rateLimitExceeded
    case unknownError(Error)
}

class OpenAIService {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func fetchModels() async throws -> [String] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw OpenAIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIServiceError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
                return response.data.map { $0.id }.sorted()
            case 401:
                throw OpenAIServiceError.invalidAPIKey
            case 429:
                throw OpenAIServiceError.rateLimitExceeded
            default:
                throw OpenAIServiceError.serverError("HTTP Status: \(httpResponse.statusCode)")
            }
        } catch let error as DecodingError {
            throw OpenAIServiceError.decodingError(error)
        } catch {
            throw OpenAIServiceError.networkError(error)
        }
    }
    
    func transcribeAudio(fileURL: URL) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/audio/transcriptions") else {
            throw OpenAIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        do {
            // Add file
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            data.append(try Data(contentsOf: fileURL))
            data.append("\r\n".data(using: .utf8)!)
            
            // Add model
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            data.append("whisper-1\r\n".data(using: .utf8)!)
            
            data.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = data
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIServiceError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let response = try JSONDecoder().decode(TranscriptionResponse.self, from: responseData)
                return response.text
            case 401:
                throw OpenAIServiceError.invalidAPIKey
            case 429:
                throw OpenAIServiceError.rateLimitExceeded
            default:
                throw OpenAIServiceError.serverError("HTTP Status: \(httpResponse.statusCode)")
            }
        } catch let error as DecodingError {
            throw OpenAIServiceError.decodingError(error)
        } catch {
            throw OpenAIServiceError.networkError(error)
        }
    }
    
    func generateSpeech(text: String, model: String, voice: String) async throws -> Data {
        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else {
            throw OpenAIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let ttsRequest = TTSRequest(model: model, input: text, voice: voice)
        request.httpBody = try JSONEncoder().encode(ttsRequest)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIServiceError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                return data
            case 401:
                throw OpenAIServiceError.invalidAPIKey
            case 429:
                throw OpenAIServiceError.rateLimitExceeded
            default:
                throw OpenAIServiceError.serverError("HTTP Status: \(httpResponse.statusCode)")
            }
        } catch {
            throw OpenAIServiceError.networkError(error)
        }
    }
    
    func sendChatCompletion(messages: [OpenAIMessage], model: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw OpenAIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = OpenAIRequest(model: model, messages: messages)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIServiceError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                return response.choices.first?.message.content ?? ""
            case 401:
                throw OpenAIServiceError.invalidAPIKey
            case 429:
                throw OpenAIServiceError.rateLimitExceeded
            default:
                throw OpenAIServiceError.serverError("HTTP Status: \(httpResponse.statusCode)")
            }
        } catch let error as DecodingError {
            throw OpenAIServiceError.decodingError(error)
        } catch {
            throw OpenAIServiceError.networkError(error)
        }
    }
    
    func sendResponseAPI(input: String, model: String, onDelta: @escaping (String) -> Void) async throws -> (String, [ResponseAPIResponse.Output.Content.Annotation]) {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw OpenAIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = ResponseAPIRequest(
            model: model,
            input: input,
            //tools: [ResponseAPIRequest.Tool(type: "web_search_preview")],
            tools: [],
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        
        let session = URLSession(configuration: configuration)
        
        return try await withCheckedThrowingContinuation { continuation in
            let streamingHandler = StreamingResponseHandler(
                onDelta: { delta in
                    onDelta(delta)
                },
                onComplete: { text, annotations in
                    continuation.resume(returning: (text, annotations))
                },
                onError: { error in
                    continuation.resume(throwing: error)
                }
            )
            
            let task = session.dataTask(with: request)
            task.delegate = streamingHandler
            
            // Set up a timeout timer
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { _ in
                task.cancel()
                continuation.resume(throwing: OpenAIServiceError.networkError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])))
            }
            
            // Store the timer in the task's userInfo using a unique key
            let timerKey = "timeoutTimer"
            objc_setAssociatedObject(task, timerKey, timeoutTimer, .OBJC_ASSOCIATION_RETAIN)
            
            // Start the task
            task.resume()
        }
    }
} 