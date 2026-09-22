import Foundation
import MessageUI
import UIKit

protocol MailComposing: AnyObject {
    var canCompose: Bool { get }
    func compose(subject: String, body: String)
}

protocol ShareSheetPresenting: AnyObject {
    func present(items: [Any])
}

struct EmailExportService {
    let mail: MailComposing
    let shareSheet: ShareSheetPresenting

    enum Destination: Equatable {
        case mail
        case shareSheet
    }

    @discardableResult
    func export(subject: String, body: String) -> Destination {
        if mail.canCompose {
            mail.compose(subject: subject, body: body)
            return .mail
        }
        shareSheet.present(items: [body])
        return .shareSheet
    }
}

final class SystemMailComposer: NSObject, MailComposing {
    var canCompose: Bool {
        MFMailComposeViewController.canSendMail()
    }

    func compose(subject: String, body: String) {
        guard canCompose, let presenter = TopViewControllerPresenter.topViewController() else { return }
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        presenter.present(composer, animated: true)
    }
}

extension SystemMailComposer: MFMailComposeViewControllerDelegate {
    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true)
    }
}

final class SystemShareSheetPresenter: ShareSheetPresenting {
    func present(items: [Any]) {
        guard let presenter = TopViewControllerPresenter.topViewController() else { return }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        presenter.present(controller, animated: true)
    }
}

enum TopViewControllerPresenter {
    static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let window = scene.keyWindow else {
            return nil
        }
        var top = window.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

struct EmailExport {
    let service: EmailExportService
    #if DEBUG
    let debugState: ExportDebugState?
    #endif
}

enum EmailExportFactory {
    static func make() -> EmailExport {
        #if DEBUG
        if CommandLine.arguments.contains("fakeEmailExport") {
            let state = ExportDebugState()
            let service = EmailExportService(
                mail: FakeMailComposer(
                    state: state,
                    configured: CommandLine.arguments.contains("fakeMailConfigured")
                ),
                shareSheet: FakeShareSheetPresenter(state: state)
            )
            return EmailExport(service: service, debugState: state)
        }
        return EmailExport(service: production, debugState: nil)
        #else
        return EmailExport(service: production)
        #endif
    }

    private static var production: EmailExportService {
        EmailExportService(
            mail: SystemMailComposer(),
            shareSheet: SystemShareSheetPresenter()
        )
    }
}

#if DEBUG
@Observable
final class ExportDebugState {
    var pending: Pending?

    struct Pending: Identifiable {
        let id = UUID()
        let viaMail: Bool
        let subject: String
        let body: String
    }
}

final class FakeMailComposer: MailComposing {
    private let state: ExportDebugState
    private let configured: Bool

    init(state: ExportDebugState, configured: Bool) {
        self.state = state
        self.configured = configured
    }

    var canCompose: Bool { configured }

    func compose(subject: String, body: String) {
        Task { @MainActor in
            self.state.pending = .init(viaMail: true, subject: subject, body: body)
        }
    }
}

final class FakeShareSheetPresenter: ShareSheetPresenting {
    private let state: ExportDebugState

    init(state: ExportDebugState) {
        self.state = state
    }

    func present(items: [Any]) {
        let body = items.first as? String ?? ""
        Task { @MainActor in
            self.state.pending = .init(viaMail: false, subject: "", body: body)
        }
    }
}

/// DEBUG-only presenter for the `fakeCloudKit` launch-argument seam: the
/// system share sheet is unavailable in deterministic UI tests, so the
/// coordinator's Share List sheet is a no-op while the share state itself
/// remains observable in the UI.
final class NoopShareSheetPresenter: ShareSheetPresenting {
    func present(items: [Any]) {}
}
#endif
