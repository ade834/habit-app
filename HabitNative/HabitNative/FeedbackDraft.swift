import Foundation

enum FeedbackDraft {
    static func components(language: String, appName: String, version: String, build: String, model: String, system: String, bundleID: String) -> URLComponents {
        func text(_ zh: String, _ en: String, _ ja: String) -> String {
            language == "zh-Hans" ? zh : (language == "ja" ? ja : en)
        }
        let body = "\(text("请在此处输入您的意见或建议", "Please enter your feedback or suggestions here", "ご意見やご提案をこちらに入力してください"))\n\n\n---\n\(text("应用名称", "App name", "アプリ名")): \(appName)\n\(text("版本号", "Version", "バージョン")): \(version) (\(build))\n\(text("设备型号", "Device model", "機種")): \(model)\n\(text("系统版本", "System version", "OSバージョン")): \(system)\n\(text("包名", "Bundle ID", "バンドルID")): \(bundleID)"
        var result = URLComponents()
        result.scheme = "mailto"
        result.path = "deshiru@foxmail.com"
        result.queryItems = [URLQueryItem(name: "subject", value: text("MAYBII 意见反馈", "MAYBII Feedback", "MAYBII フィードバック")), URLQueryItem(name: "body", value: body)]
        return result
    }
}
