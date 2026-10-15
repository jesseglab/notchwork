import SwiftUI
import WebKit
import NotchworkKit

/// A separate WebKit process renders app content. It receives no host token or files; CSP restricts resource loading.
struct CustomInterfaceView: NSViewRepresentable {
    let interface: ActivityInterface
    let invoke: (String, String) -> Bool
    func makeCoordinator() -> Coordinator { Coordinator(invoke: invoke) }
    func makeNSView(context: Context) -> IsolatedWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.add(context.coordinator, name: "notchwork")
        let view = IsolatedWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsLinkPreview = false
        view.setValue(false, forKey: "drawsBackground")
        view.document = Self.document(interface.html)
        return view
    }
    func updateNSView(_ view: IsolatedWebView, context: Context) {
        context.coordinator.invoke = invoke
        view.document = Self.document(interface.html)
    }
    static func dismantleNSView(_ view: IsolatedWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "notchwork")
        view.document = ""; view.stopLoading(); view.loadHTMLString("", baseURL: nil)
    }
    static func document(_ html: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;background:transparent;color:white;color-scheme:dark}*{box-sizing:border-box}</style>
        <script>window.notchwork=Object.freeze({invoke:(action,value='')=>{if(typeof action==='string'&&typeof value==='string')window.webkit.messageHandlers.notchwork.postMessage({action,value})}});</script>
        </head><body>\(html)</body></html>
        """
    }
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        var invoke: (String, String) -> Bool
        init(invoke: @escaping (String, String) -> Bool) { self.invoke = invoke }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let body = message.body as? [String: String],
                  let action = body["action"], let value = body["value"], value.utf8.count <= 4096 else { return }
            _ = invoke(action, value)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.navigationType == .other && navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
        }
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) { completionHandler() }
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) { completionHandler(false) }
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) { completionHandler(nil) }
    }
}
final class IsolatedWebView: WKWebView {
    var document = "" { didSet { if document != oldValue && window != nil { loadHTMLString(document, baseURL: nil) } } }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Detaching a collapsed surface destroys the page, including any JavaScript timers.
        stopLoading(); loadHTMLString(window == nil ? "" : document, baseURL: nil)
    }
}
