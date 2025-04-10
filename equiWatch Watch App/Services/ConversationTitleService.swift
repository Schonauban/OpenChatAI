import Foundation

class ConversationTitleService {
    private let openAIService: OpenAIService
    
    init(openAIService: OpenAIService) {
        self.openAIService = openAIService
    }
    
    func generateTitle(for messages: [Message]) async throws -> String {
        // Format the conversation for the title generation
        let conversationText = messages.map { message in
            "\(message.isUserMessage ? "User" : "Assistant"): \(message.content)"
        }.joined(separator: "\n")
        
        // Create a system message to instruct GPT to generate a title
        let systemMessage = OpenAIMessage(
            role: "system",
            content: "You are a helpful assistant that generates concise, descriptive titles for conversations. Your response should be a single line title that captures the main topic or theme of the conversation. Do not include any additional text or formatting. Make it short and concise."
        )
        
        let userMessage = OpenAIMessage(
            role: "user",
            content: "Please generate a title for this conversation:\n\n\(conversationText)"
        )
        
        // Use the chat completion API to generate the title
        let title = try await openAIService.sendChatCompletion(
            messages: [systemMessage, userMessage],
            model: "gpt-3.5-turbo"
        )
        
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 