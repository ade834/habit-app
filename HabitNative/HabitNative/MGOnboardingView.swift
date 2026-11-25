import SwiftUI
import WebKit

// MARK: - 迪士尼与谷歌动效物理曲线体系 (保留向后兼容)
public enum MGMotion {
    public static let disneyOvershoot = Animation.spring(response: 0.48, dampingFraction: 0.66, blendDuration: 0.15)
    public static let disneySquash = Animation.spring(response: 0.32, dampingFraction: 0.72)
    public static let disneyJuicy = Animation.interpolatingSpring(stiffness: 280, damping: 18)
    public static let googleEmphasized = Animation.timingCurve(0.2, 0.0, 0.0, 1.0, duration: 0.65)
    public static let googleDecelerate = Animation.timingCurve(0.0, 0.0, 0.2, 1.0, duration: 0.45)
    public static let googleStandard = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.35)
}

// MARK: - MG 动画引导阶段枚举 (保留向后兼容)
public enum MGChapter: Int, CaseIterable, Identifiable {
    case morningWake = 0
    case deckSelection = 1
    case focusedAction = 2
    case liquidGrowth = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .morningWake: return "01 晨启节奏"
        case .deckSelection: return "02 选定习惯"
        case .focusedAction: return "03 专注打卡"
        case .liquidGrowth: return "04 生长闭环"
        }
    }

    public var subtitle: String {
        switch self {
        case .morningWake: return "每天清晨，给你一个没有心理负担的起点。"
        case .deckSelection: return "轻触卡片，随心翻阅。挑选 1~3 个想做的小习惯。"
        case .focusedAction: return "不设繁重流程，写下一句话，完成一次微小蜕变。"
        case .liquidGrowth: return "晶莹水滴流动，每一次打卡都在滋养你的芽苗。"
        }
    }
}

// MARK: - MG 动画多语言支持枚举
public enum MGLanguage: String, CaseIterable, Identifiable {
    case zh = "中文"
    case ja = "日本語"
    case en = "English"

    public var id: String { rawValue }

    public var displayName: String { rawValue }
    public var menuTitle: String { rawValue }

    public var resourceName: String {
        switch self {
        case .zh: return "index_zh"
        case .ja: return "index_ja"
        case .en: return "index_en"
        }
    }

    /// 根据系统及软件语言环境自动解析默认语言：
    /// 简体中文与繁体中文默认均为中文；日文为日文；除中日外均默认英文。
    public static func systemDefault() -> MGLanguage {
        let appLang = AppLanguage.current.lowercased()
        if appLang.hasPrefix("zh") { return .zh }
        if appLang.hasPrefix("ja") { return .ja }
        if appLang.hasPrefix("en") { return .en }

        for lang in Locale.preferredLanguages {
            let lower = lang.lowercased()
            if lower.hasPrefix("zh") {
                return .zh
            }
            if lower.hasPrefix("ja") {
                return .ja
            }
        }
        return .en
    }
}

// MARK: - MG 动画全屏引导主视图 (WKWebView 容器实现)
public struct MGOnboardingView: View {
    @Binding var isPresented: Bool
    @State private var selectedLanguage: MGLanguage

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        if let langArgIndex = CommandLine.arguments.firstIndex(of: "-lang"),
           langArgIndex + 1 < CommandLine.arguments.count {
            let lang = CommandLine.arguments[langArgIndex + 1]
            if lang == "en" {
                self._selectedLanguage = State(initialValue: .en)
                return
            } else if lang == "ja" {
                self._selectedLanguage = State(initialValue: .ja)
                return
            } else if lang == "zh" {
                self._selectedLanguage = State(initialValue: .zh)
                return
            }
        }
        self._selectedLanguage = State(initialValue: MGLanguage.systemDefault())
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // 底层背景
            Color(red: 0.98, green: 0.97, blue: 0.99)
                .ignoresSafeArea()

            // 1. 极简色块面 MG 动效 Webview 核心视图
            MGWebView(
                resourceName: selectedLanguage.resourceName,
                onDismiss: {
                    isPresented = false
                }
            )
            .ignoresSafeArea()

            // 2. 悬浮辅助控制栏（支持原生切换语言及随时关闭）
            HStack {
                Menu {
                    ForEach(MGLanguage.allCases) { lang in
                        Button(action: {
                            selectedLanguage = lang
                        }) {
                            HStack {
                                Text(lang.menuTitle)
                                if selectedLanguage == lang {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 12, weight: .semibold))
                        Text(selectedLanguage.displayName)
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Color.primary.opacity(0.75))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.primary.opacity(0.75))
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 54)
        }
    }
}

// MARK: - WKWebView 包装器
struct MGWebView: UIViewRepresentable {
    let resourceName: String
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "onboarding")
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator

        context.coordinator.loadHTML(resourceName: resourceName, in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if context.coordinator.currentResource != resourceName {
            context.coordinator.loadHTML(resourceName: resourceName, in: uiView)
        }
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: MGWebView
        var currentResource: String?

        init(_ parent: MGWebView) {
            self.parent = parent
        }

        func loadHTML(resourceName: String, in webView: WKWebView) {
            currentResource = resourceName
            guard let baseUrl = Bundle.main.url(forResource: resourceName, withExtension: "html") ?? Bundle.main.url(forResource: "index", withExtension: "html") else { return }
            webView.loadFileURL(baseUrl, allowingReadAccessTo: Bundle.main.bundleURL)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WEBVIEW DID FAIL NAVIGATION: \(error)")
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WEBVIEW DID FAIL PROVISIONAL: \(error)")
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let seekArgIndex = CommandLine.arguments.firstIndex(of: "-seek"),
               seekArgIndex + 1 < CommandLine.arguments.count,
               let seekTime = Double(CommandLine.arguments[seekArgIndex + 1]) {
                let js = """
                (function pauseAndRender() {
                    isPlaying = false;
                    manualOffset = \(seekTime);
                    renderFrame(\(seekTime));
                })();
                """
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "onboarding" {
                if let body = message.body as? [String: Any],
                   let action = body["action"] as? String,
                   action == "skip" || action == "finish" {
                    DispatchQueue.main.async {
                        self.parent.onDismiss()
                    }
                }
            }
        }
    }
}
