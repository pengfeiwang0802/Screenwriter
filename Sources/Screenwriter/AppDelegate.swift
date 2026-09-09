import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    /// 编剧助手插件实例（持有，避免过早释放）
    private let scriptwritingPlugin = ScriptwritingPlugin()

    /// 版本号：Info.plist 优先（release build），硬编码兜底（debug build）
    static var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "v\(version)"
        }
        return "v0.1.0"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = scriptwritingPlugin.makeWindow()
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        // 从 Xcode/SPM 直接运行时 app 不会自动激活到前台，需显式激活，否则窗口不置前
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 处理双击 .swsproj/.sws 文件打开（app 未运行时，此回调在 didFinishLaunching 之前触发）
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme?.lowercased() == "screenwriter" {
                handleScreenwriterURL(url)
            } else {
                scriptwritingPlugin.openDocument(url: url)
            }
        }
    }

    /// 处理 URL scheme 唤起（screenwriter://open?path=...）
    func application(_ application: NSApplication, open url: URL) {
        guard url.scheme?.lowercased() == "screenwriter" else { return }
        handleScreenwriterURL(url)
    }

    private func handleScreenwriterURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let path = components.queryItems?.first(where: { $0.name == "path" })?.value else {
            print("[AppDelegate] screenwriter:// 缺少 path 参数")
            return
        }
        let fileURL = URL(fileURLWithPath: path)
        scriptwritingPlugin.openDocument(url: fileURL)
    }
}

extension AppDelegate: NSWindowDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
