import XCTest
@testable import Muslim_5

final class ICloudSyncStateMachineTests: XCTestCase {
    private let completionDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testLocalSaveWaitsForConfirmedExport() {
        var machine = ICloudSyncStateMachine()

        machine.accountBecameAvailable()
        machine.localChangeSaved()

        XCTAssertEqual(machine.state, .waitingToBackUp)
        XCTAssertTrue(machine.hasPendingLocalChanges)

        machine.eventStarted(.export)
        XCTAssertEqual(machine.state, .syncing)

        machine.eventFinished(.export, succeeded: true, at: completionDate)
        XCTAssertEqual(machine.state, .backedUp(completionDate))
        XCTAssertFalse(machine.hasPendingLocalChanges)
    }

    func testImportDoesNotClearPendingLocalBackup() {
        var machine = ICloudSyncStateMachine()
        machine.localChangeSaved()

        machine.eventStarted(.import)
        machine.eventFinished(.import, succeeded: true, at: completionDate)

        XCTAssertEqual(machine.state, .waitingToBackUp)
        XCTAssertTrue(machine.hasPendingLocalChanges)
    }

    func testSuccessfulImportReportsUpToDateWithoutPendingChanges() {
        var machine = ICloudSyncStateMachine()
        machine.accountBecameAvailable()

        machine.eventStarted(.import)
        machine.eventFinished(.import, succeeded: true, at: completionDate)

        XCTAssertEqual(machine.state, .upToDate(completionDate))
    }

    func testFailedExportPreservesPendingChangeAndShowsError() {
        var machine = ICloudSyncStateMachine()
        machine.localChangeSaved()
        machine.eventStarted(.export)

        machine.eventFinished(
            .export,
            succeeded: false,
            at: completionDate,
            errorMessage: "Network unavailable"
        )

        XCTAssertEqual(machine.state, .failed("Network unavailable"))
        XCTAssertTrue(machine.hasPendingLocalChanges)
    }
}
