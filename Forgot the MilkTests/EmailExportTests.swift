import Foundation
import Testing

@testable import Forgot_the_Milk

private final class RecordingMail: MailComposing {
    var canCompose: Bool
    var lastSubject: String?
    var lastBody: String?

    init(canCompose: Bool) {
        self.canCompose = canCompose
    }

    func compose(subject: String, body: String) {
        lastSubject = subject
        lastBody = body
    }
}

private final class RecordingShareSheet: ShareSheetPresenting {
    var lastItems: [Any]?

    func present(items: [Any]) {
        lastItems = items
    }
}

@Suite("Email export service")
struct EmailExportTests {
    @Test func usesMailWhenConfigured() {
        let mail = RecordingMail(canCompose: true)
        let shareSheet = RecordingShareSheet()
        let service = EmailExportService(mail: mail, shareSheet: shareSheet)

        #expect(service.export(subject: "Household", body: "Milk") == .mail)
        #expect(mail.lastSubject == "Household")
        #expect(mail.lastBody == "Milk")
        #expect(shareSheet.lastItems == nil)
    }

    @Test func fallsBackToShareSheetWhenMailIsUnavailable() {
        let mail = RecordingMail(canCompose: false)
        let shareSheet = RecordingShareSheet()
        let service = EmailExportService(mail: mail, shareSheet: shareSheet)

        #expect(service.export(subject: "Household", body: "Milk") == .shareSheet)
        #expect(mail.lastSubject == nil)
        #expect(shareSheet.lastItems?.count == 1)
        #expect(shareSheet.lastItems?.first as? String == "Milk")
    }
}
