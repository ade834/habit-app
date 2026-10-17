import Foundation

/// Talks to the local development proxy. Production builds must use a hosted backend.
enum QwenReviewService {
    private static let endpoint = URL(string: "http://127.0.0.1:8765/api/review")!

    struct MonthlyReports: Decodable {
        let analysis: String
        let encouragement: String
    }

    static func analyzeMonth(_ report: String) async throws -> MonthlyReports {
        try await analyze(report, period: "month")
    }

    static func analyzeWeek(_ report: String) async throws -> MonthlyReports {
        try await analyze(report, period: "week")
    }

    private static func analyze(_ report: String, period: String) async throws -> MonthlyReports {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ReviewRequest(report: report, period: period))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw KeyError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = try? JSONDecoder().decode(ServiceError.self, from: data)
            throw KeyError.server(http.statusCode, message?.error)
        }
        let parsed = try JSONDecoder().decode(MonthlyReports.self, from: data)
        guard !parsed.analysis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !parsed.encouragement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw KeyError.emptyResponse }
        return parsed
    }

    private struct ReviewRequest: Encodable { let report: String; let period: String }
    private struct ServiceError: Decodable { let error: String? }
    private enum KeyError: LocalizedError {
        case invalidResponse, server(Int, String?), emptyResponse
        var errorDescription: String? {
            switch self {
            case .invalidResponse: "千问返回了无效响应。"
            case .server(404, _): "本地复盘服务接口未找到（404）。请重启本地千问代理后重试。"
            case .server(let code, let detail): "千问服务暂不可用（HTTP \(code)\(detail.map { "：\($0)" } ?? "")）。"
            case .emptyResponse: "千问暂时没有返回分析内容。"
            }
        }
    }
}
