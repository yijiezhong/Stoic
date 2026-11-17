import XCTest
@testable import StoicCore

final class DataExportTests: XCTestCase {
    private func makePayload() -> ExportPayload {
        ExportPayload(
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            tasks: [
                ExportTask(
                    id: UUID(), title: "写作", note: "第 3 章", createdAt: Date(timeIntervalSince1970: 1_690_000_000),
                    completedAt: nil, dueDate: nil, isImportant: true, isUrgent: false,
                    expectedIntervals: 3, sortIndex: 1, legacyID: "legacy-1"
                )
            ],
            intervals: [
                ExportInterval(
                    id: UUID(), startedAt: Date(timeIntervalSince1970: 1_699_000_000),
                    duration: 1_500, isRest: false, roundIndex: 1, completionState: 3,
                    interruptionCount: 2, interruptionReasons: "distraction,rest",
                    mode: "focus50", taskTitle: "写作", legacyID: nil
                )
            ],
            settings: ExportSettings(
                workMinutes: 50, shortRestMinutes: 10, longRestMinutes: 30,
                segmentsPerRound: 4, autoStartNext: false
            )
        )
    }

    func testJSONRoundTrip() throws {
        let payload = makePayload()
        let data = try DataExport.encodeJSON(payload)
        let decoded = try DataExport.decodeJSON(data)
        XCTAssertEqual(decoded, payload, "导出再导入应完全一致")
    }

    func testCSVHeaderAndRows() {
        let payload = makePayload()
        let csv = DataExport.encodeCSV(payload.intervals)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("startedAt,durationSeconds"))
        XCTAssertTrue(lines[1].contains("1500"))
        XCTAssertTrue(lines[1].contains("focus50"))
        XCTAssertTrue(lines[1].contains("写作"))
    }

    func testCSVEscapesCommasInTaskTitle() {
        let interval = ExportInterval(
            id: UUID(), startedAt: Date(), duration: 60, isRest: false,
            roundIndex: 0, completionState: 3, interruptionCount: 0,
            interruptionReasons: "", mode: "pomodoro", taskTitle: "写作, 修订", legacyID: nil
        )
        let csv = DataExport.encodeCSV([interval])
        XCTAssertTrue(csv.contains("\"写作, 修订\""), "含逗号的标题应被引号包裹")
    }
}
