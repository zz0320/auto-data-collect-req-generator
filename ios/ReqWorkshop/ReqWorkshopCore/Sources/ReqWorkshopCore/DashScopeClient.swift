import Foundation

public struct DashScopeClient: LLMClient {
    public var apiKeyProvider: () throws -> String
    public var model: String
    public var endpoint: URL
    public var session: URLSession

    public init(
        apiKeyProvider: @escaping () throws -> String,
        model: String,
        endpoint: URL,
        session: URLSession = .shared
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.model = model
        self.endpoint = endpoint
        self.session = session
    }

    public func generateJSON(system: String, user: String, timeoutSeconds: TimeInterval) async throws -> [String: Any] {
        let apiKey = try apiKeyProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw DashScopeError.missingAPIKey }
        var request = URLRequest(url: endpoint, timeoutInterval: timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": model,
            "input": [
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user],
                ],
            ],
            "parameters": [
                "result_format": "message",
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DashScopeError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw DashScopeError.http(status: http.statusCode, message: errorMessage(from: data))
        }
        let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = extractContent(from: envelope ?? [:]) else { throw DashScopeError.invalidResponse }
        let clean = stripMarkdownFence(content)
        guard let jsonData = clean.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw DashScopeError.invalidJSON(content)
        }
        return parsed
    }

    private func extractContent(from envelope: [String: Any]) -> String? {
        if let output = envelope["output"] as? [String: Any] {
            if let text = output["text"] as? String { return text }
            if let choices = output["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        }
        if let choices = envelope["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        if let text = envelope["text"] as? String { return text }
        return nil
    }

    private func errorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["message", "error", "errorMessage"] {
                if let value = json[key] as? String { return value }
            }
        }
        return String(data: data, encoding: .utf8) ?? "HTTP 请求失败"
    }

    private func stripMarkdownFence(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"^\s*```(?:json)?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*```\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum DashScopeError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case invalidJSON(String)
    case http(status: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: "请先在 API 配置中填写 DashScope API Key"
        case .invalidResponse: "DashScope 响应格式无法识别"
        case .invalidJSON(let content): "模型没有返回有效 JSON：\(content.prefix(120))"
        case .http(let status, let message): "DashScope HTTP \(status): \(message)"
        }
    }
}
