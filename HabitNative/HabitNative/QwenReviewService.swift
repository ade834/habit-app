import Foundation
import Security

/// Production requests use HTTPS. The release service remains unavailable until anonymous access is secured.
enum QwenReviewService {
    #if DEBUG
    private static let endpoint = URL(string: "http://127.0.0.1:8765/api/review")!
    #else
    private static let endpoint = URL(string: "https://api.ddream.top/api/review")!
    #endif

    struct MonthlyReports: Decodable {
        let analysis: String
        let encouragement: String
    }

    static func analyzeMonth(_ report: String, language: String) async throws -> MonthlyReports {
        try await analyze(report, period: "month", language: language)
    }

    static func analyzeWeek(_ report: String, language: String) async throws -> MonthlyReports {
        try await analyze(report, period: "week", language: language)
    }

    private static func analyze(_ report: String, period: String, language: String) async throws -> MonthlyReports {
        var url = endpoint
        var session = URLSession(configuration: .ephemeral)
        #if DEBUG && !targetEnvironment(simulator)
        guard let configURL = Bundle.main.url(forResource: "DeviceReviewConfig", withExtension: "plist"),
              let configData = try? Data(contentsOf: configURL),
              let config = try? PropertyListDecoder().decode(DeviceReviewConfig.self, from: configData),
              let deviceURL = URL(string: config.endpoint), let certificate = Data(base64Encoded: config.certificate) else {
            throw KeyError.proxyUnavailable
        }
        url = deviceURL
        session = URLSession(configuration: .ephemeral, delegate: DeviceProxyTrust(certificate: certificate), delegateQueue: nil)
        #endif
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        #if DEBUG && !targetEnvironment(simulator)
        request.setValue("Bearer " + config.token, forHTTPHeaderField: "Authorization")
        #endif
        request.httpMethod = "POST"
        request.timeoutInterval = 240
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try JSONEncoder().encode(ReviewRequest(report: report, period: period, language: language))
        request.httpBody = body
        #if !DEBUG
        try await ReviewAccessClient.completePendingTrialReset()
        for (key, value) in try await ReviewAccessClient.headers(for: body) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        #endif
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost].contains(error.code) {
            throw KeyError.proxyUnavailable
        }
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

    private struct ReviewRequest: Encodable { let report: String; let period: String; let language: String }
    private struct ServiceError: Decodable { let error: String? }
    private enum KeyError: LocalizedError {
        case invalidResponse, server(Int, String?), emptyResponse, proxyUnavailable
        var errorDescription: String? {
            switch self {
            case .server(401, _): AppLanguage.text("复盘服务正在准备中，请稍后再试。")
            case .server(429, _): AppLanguage.text("已达到调用限额，请稍后再试。")
            case .server(413, _): AppLanguage.text("ai.review.tooLarge")
            case .server(503, _): AppLanguage.text("复盘服务正在准备中，请稍后再试。")
            case .proxyUnavailable: AppLanguage.text("复盘服务暂时无法连接，请检查网络后重试。")
            case .invalidResponse: AppLanguage.text("千问返回了无效响应。")
            case .server(404, _): AppLanguage.text("复盘服务暂时不可用，请稍后重试。")
            case .server(_, "output_language_mismatch"): AppLanguage.text("生成的报告语言不符合设置，请重试。")
            case .server(let code, _): String(format: AppLanguage.text("千问服务暂不可用（HTTP %lld）。"), code)
            case .emptyResponse: AppLanguage.text("千问暂时没有返回分析内容。")
            }
        }
    }
}

#if DEBUG && !targetEnvironment(simulator)
private struct DeviceReviewConfig: Decodable {
    let endpoint: String
    let token: String
    let certificate: String
}

private final class DeviceProxyTrust: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let certificate: Data
    init(certificate: Data) { self.certificate = certificate }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first, SecCertificateCopyData(leaf) as Data == certificate else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
#endif
