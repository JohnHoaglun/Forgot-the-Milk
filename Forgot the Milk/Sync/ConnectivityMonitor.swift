import Foundation
import Network

protocol ConnectivityMonitoring: AnyObject {
    var isOnline: Bool { get }
    func setChangeHandler(_ handler: ((Bool) -> Void)?)
}

final class SystemConnectivityMonitor: ConnectivityMonitoring {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.hoaglun.forgotthemilk.connectivity")
    private var online = false
    private var handler: ((Bool) -> Void)?

    var isOnline: Bool { online }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let online = path.status == .satisfied
                self.online = online
                self.handler?(online)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    func setChangeHandler(_ handler: ((Bool) -> Void)?) {
        self.handler = handler
    }
}

#if DEBUG
final class FakeConnectivityMonitor: ConnectivityMonitoring {
    private var online = false
    private var handler: ((Bool) -> Void)?

    var isOnline: Bool { online }

    func setChangeHandler(_ handler: ((Bool) -> Void)?) {
        self.handler = handler
    }

    func setOnline(_ online: Bool) {
        guard online != self.online else { return }
        self.online = online
        handler?(online)
    }
}
#endif
