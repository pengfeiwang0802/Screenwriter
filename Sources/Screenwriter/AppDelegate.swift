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
    }
}

extension AppDelegate: NSWindowDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
