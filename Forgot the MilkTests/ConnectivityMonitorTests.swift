import Foundation
import Testing

@testable import Forgot_the_Milk

@Suite("Connectivity monitor")
struct ConnectivityMonitorTests {
    @Test func reportsOfflineInitially() {
        let monitor = FakeConnectivityMonitor()
        #expect(monitor.isOnline == false)
    }

    @Test func setOnlineFiresHandlerOnlyOnChange() {
        let monitor = FakeConnectivityMonitor()
        var events: [Bool] = []
        monitor.setChangeHandler { events.append($0) }

        monitor.setOnline(true)
        #expect(monitor.isOnline)
        #expect(events == [true])

        monitor.setOnline(true)
        #expect(events == [true])

        monitor.setOnline(false)
        #expect(monitor.isOnline == false)
        #expect(events == [true, false])
    }

    @Test func clearingHandlerStopsNotifications() {
        let monitor = FakeConnectivityMonitor()
        var events: [Bool] = []
        monitor.setChangeHandler { events.append($0) }

        monitor.setOnline(true)
        monitor.setChangeHandler(nil)
        monitor.setOnline(false)

        #expect(events == [true])
        #expect(monitor.isOnline == false)
    }

    @Test func replacedHandlerReceivesSubsequentChanges() {
        let monitor = FakeConnectivityMonitor()
        var first: [Bool] = []
        var second: [Bool] = []
        monitor.setChangeHandler { first.append($0) }
        monitor.setChangeHandler { second.append($0) }

        monitor.setOnline(true)

        #expect(first.isEmpty)
        #expect(second == [true])
    }
}
