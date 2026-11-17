import XCTest
import SwiftData
@testable import StoicCore

@MainActor
final class StoreTests: XCTestCase {
    func testTaskOrderingBySortIndex() throws {
        let container = try StoicStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        for (index, title) in [(2, "C"), (0, "A"), (1, "B")] {
            context.insert(TaskItem(title: title, sortIndex: index))
        }
        try context.save()

        let fetched = try context.fetch(
            FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\TaskItem.sortIndex)])
        )
        XCTAssertEqual(fetched.map(\.title), ["A", "B", "C"])
    }

    func testSettingsRoundTrip() throws {
        let container = try StoicStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let record = SettingsRecord()
        record.workMinutes = 50
        record.shortRestMinutes = 10
        record.longRestMinutes = 30
        record.segmentsPerRound = 4
        record.autoStartNext = false
        context.insert(record)
        try context.save()

        let loaded = try XCTUnwrap(try context.fetch(FetchDescriptor<SettingsRecord>()).first)
        XCTAssertEqual(loaded.workMinutes, 50)
        XCTAssertEqual(loaded.shortRestMinutes, 10)
        XCTAssertEqual(loaded.longRestMinutes, 30)
        XCTAssertEqual(loaded.segmentsPerRound, 4)
        XCTAssertFalse(loaded.autoStartNext)
    }

    func testDeletingTaskCascadesIntervals() throws {
        let container = try StoicStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let task = TaskItem(title: "临时")
        context.insert(task)
        context.insert(Interval(startedAt: Date(), duration: 1_500, isRest: false, task: task))
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Interval>()), 1)

        context.delete(task)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Interval>()), 0, "删除任务应级联删除记录")
    }
}
