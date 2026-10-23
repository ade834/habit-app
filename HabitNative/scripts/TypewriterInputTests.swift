import SwiftUI
import UIKit
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        Task { @MainActor in await run(scene as! UIWindowScene) }
    }
    @MainActor func run(_ scene: UIWindowScene) async {
        var value = ""
        var composing = false
        var caret = CGPoint.zero
        var strikeKinds: [AppSoundFeedback.Kind] = []
        let control = TypewriterInputControl()
        let editor = TypewriterNativeInput(text: Binding(get: { value }, set: { value = $0 }), composing: Binding(get: { composing }, set: { composing = $0 }), caret: Binding(get: { caret }, set: { caret = $0 }), control: control, baseline: 200, reduceMotion: true, onStrike: { strikeKinds.append($0) })
        let controller = UIHostingController(rootView: InputTestSurface(input: editor, control: control))
        let window = UIWindow(windowScene: scene)
        self.window = window
        window.rootViewController = controller
        window.makeKeyAndVisible()
        try? await Task.sleep(for: .milliseconds(250))
        guard let view = control.view else { fatalError("missing input") }
        control.focus()
        let inputFrame = view.convert(view.bounds, to: window)
        assert(inputFrame.minY > window.bounds.height * 0.70 && inputFrame.height <= 44, "IME's real input must stay at the bottom")
        let coordinator = view.delegate as! TypewriterNativeInput.Coordinator
        assert(coordinator.textView(view, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "n"))
        view.setMarkedText("n", selectedRange: NSRange(location: 1, length: 0))
        view.delegate?.textViewDidChange?(view)
        assert(view.markedTextRange != nil && value.isEmpty && composing, "pinyin must not leak into committed draft")
        assert(strikeKinds == [.key], "each pinyin key has a strike")
        assert(control.visibleText == "n" && control.compositionText == "n", "paper mirrors provisional pinyin without saving it")
        assert(coordinator.textView(view, shouldChangeTextIn: NSRange(location: 1, length: 0), replacementText: "i"))
        view.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        view.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))
        view.delegate?.textViewDidChange?(view)
        assert(value.isEmpty && strikeKinds == [.key, .key], "composition text remains provisional while each key gets sound")
        assert(coordinator.textView(view, shouldChangeTextIn: NSRange(location: 0, length: 5), replacementText: "你好"))
        view.insertText("你好")
        view.unmarkText()
        view.delegate?.textViewDidChange?(view)
        assert(value == "你好" && strikeKinds == [.key, .key, .candidate], "candidate selection has distinct feedback: \(value)")
        view.insertText("🌱")
        assert(value == "你好🌱")
        control.deleteBackward()
        assert(value == "你好", "delete whole emoji")
        view.selectedRange = NSRange(location: 0, length: 1)
        view.insertText("你们")
        assert(value == "你们好", "selection replacement")
        view.selectedRange = NSRange(location: (view.text as NSString).length, length: 0)
        view.insertText("\n" + String(repeating: "把注意力留给重要的事。", count: 60))
        try? await Task.sleep(for: .milliseconds(100))
        assert(value.hasPrefix("你们好\n"), "multiline paste")
        assert(view.contentOffset.y > 0, "bottom input scrolls its own caret into view")
        let paper = findPaper(controller.view)!
        assert(paper.text == control.visibleText && paper.contentOffset.y > 0, "long paper mirrors text and feeds upward")
        assert(control.paperFeed > 0 && abs(control.paperFeed - paper.contentOffset.y) < 1, "header and paper texture must receive the actual TextKit feed distance")
        let caretPosition = view.selectedTextRange!.end
        let lowerCaret = view.convert(view.caretRect(for: caretPosition), to: window)
        assert(lowerCaret.minY > window.bounds.height * 0.65, "long input must not move the IME anchor back onto the paper")
        let snapshot = control.commit()
        assert(snapshot == value, "save flushes current input")
        control.clear()
        assert(value.isEmpty && view.text.isEmpty && control.visibleText.isEmpty, "clear updates native text, paper mirror, and draft")
        try? await Task.sleep(for: .milliseconds(100))
        assert(control.paperFeed < 2, "clearing text returns the paper header to its starting position")
        view.setMarkedText("zhongwen", selectedRange: NSRange(location: 8, length: 0))
        view.delegate?.textViewDidChange?(view)
        control.clear()
        assert(view.markedTextRange == nil && value.isEmpty && control.visibleText.isEmpty, "clear while composing clears both paper and native candidate transaction")
        view.setMarkedText("zhongwen", selectedRange: NSRange(location: 8, length: 0))
        let markedSave = control.commit()
        assert(markedSave == view.text && view.markedTextRange == nil, "save resolves composition")
        let date = Date(timeIntervalSince1970: 1234)
        ReviewWritingDrafts.save(["primary": "中文草稿🌱"], goal: "TYPEWRITER-TEST", date: date)
        assert(ReviewWritingDrafts.load(goal: "TYPEWRITER-TEST", date: date)["primary"] == "中文草稿🌱")
        ReviewWritingDrafts.removeAll()
        assert(ReviewWritingDrafts.load(goal: "TYPEWRITER-TEST", date: date).isEmpty, "clear app data removes drafts")
        print("PASS: per-key pinyin sounds, distinct candidate sound, Chinese commit, emoji deletion, selected replacement, bottom IME anchor, paper mirror and long-paper feed, save flush, clear, draft roundtrip")
        fflush(stdout)
        exit(0)
    }
}

private struct InputTestSurface: View {
    let input: TypewriterNativeInput
    let control: TypewriterInputControl
    var body: some View {
        VStack(spacing: 0) {
            TypewriterPaperText(control: control, text: control.visibleText, selection: control.selection, markedRange: control.markedRange, baseline: 200, reduceMotion: true, onCaret: { _ in })
            input.frame(height: 38)
        }
        .ignoresSafeArea(.keyboard)
    }
}

@MainActor private func findPaper(_ view: UIView) -> UITextView? {
    if let text = view as? UITextView, text.accessibilityIdentifier == "typewriter.paper.mirror" { return text }
    for child in view.subviews { if let found = findPaper(child) { return found } }
    return nil
}
