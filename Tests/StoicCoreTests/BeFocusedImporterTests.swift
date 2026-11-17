import XCTest
import SwiftData
@testable import StoicCore

@MainActor
final class BeFocusedImporterTests: XCTestCase {
    private var realFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/85GN4K4XWZ.group.com.xwavesoft.pomodoromac/groupStorage.plist")
    }

    private func requireRealFile() throws {
        guard FileManager.default.fileExists(atPath: realFile.path) else {
            throw XCTSkip("本机没有 Be Focused 的 groupStorage.plist，跳过真实数据用例")
        }
    }

    func testParseRealFileMatchesKnownCounts() throws {
        try requireRealFile()
        let parsed = try BeFocusedParser.parse(plistAt: realFile)

        XCTAssertEqual(parsed.tasks.count, 32, "任务数应与调研一致")
        XCTAssertEqual(parsed.intervals.count, 3_749, "interval 数应与调研一致")

        let work = parsed.intervals.filter { !$0.isRest }
        let rest = parsed.intervals.filter { $0.isRest }
        XCTAssertEqual(work.count, 2_264)
        XCTAssertEqual(rest.count, 1_485)
    }

    func testParseSampleTimestamp() throws {
        try requireRealFile()
        let parsed = try BeFocusedParser.parse(plistAt: realFile)
        let sample = parsed.intervals.first { $0.legacyID == "110D6E43-8335-40D3-AD44-F2B68B2F4853" }
        let unwrapped = try XCTUnwrap(sample)
        XCTAssertEqual(unwrapped.startedAt.timeIntervalSince1970, 1_511_530_848.789452, accuracy: 0.001)
        XCTAssertEqual(unwrapped.duration, 1_500, accuracy: 0.001)
        XCTAssertFalse(unwrapped.isRest)
    }

    func testImportIntoMemoryStore() throws {
        try requireRealFile()
        let container = try StoicStore.makeContainer(inMemory: true)
        let importer = BeFocusedImporter()
        let summary = try importer.importAll(from: realFile, into: container)

        XCTAssertEqual(summary.insertedTasks, 32, "只统计用户任务；「其他」是系统建的")
        XCTAssertEqual(summary.insertedIntervals, 3_749)

        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskItem>()), 33, "32 个用户任务 + 1 个「其他」")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Interval>()), 3_749)

        let intervals = try context.fetch(FetchDescriptor<Interval>())
        XCTAssertEqual(intervals.filter { $0.task == nil }.count, 0, "每条 interval 都必须有归属")
        let others = intervals.filter { $0.task?.legacyID == "__other__" }
        XCTAssertEqual(others.count, 1_032 + 479, "PMDefaultTask 与已删除任务都应归到「其他」")
    }

    func testImportIsIdempotent() throws {
        try requireRealFile()
        let container = try StoicStore.makeContainer(inMemory: true)
        let importer = BeFocusedImporter()
        _ = try importer.importAll(from: realFile, into: container)
        let second = try importer.importAll(from: realFile, into: container)

        XCTAssertEqual(second.insertedTasks, 0)
        XCTAssertEqual(second.insertedIntervals, 0)
        XCTAssertEqual(second.skippedDuplicates, 3_749)

        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Interval>()), 3_749)
    }
}
