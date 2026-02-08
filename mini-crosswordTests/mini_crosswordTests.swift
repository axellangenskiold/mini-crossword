//
//  mini_crosswordTests.swift
//  mini-crosswordTests
//
//  Created by Axel Langenskiöld on 2026-02-06.
//

import Foundation
import Testing
@testable import mini_crossword

struct mini_crosswordTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    private func sampleEntries() -> (across: [Entry], down: [Entry]) {
        let across = [
            Entry(number: 1, cells: [Coordinate(row: 0, col: 0), Coordinate(row: 0, col: 1), Coordinate(row: 0, col: 2)], answer: "CAT", clue: ""),
            Entry(number: 2, cells: [Coordinate(row: 1, col: 0), Coordinate(row: 1, col: 1), Coordinate(row: 1, col: 2)], answer: "ARE", clue: ""),
            Entry(number: 3, cells: [Coordinate(row: 2, col: 0), Coordinate(row: 2, col: 1), Coordinate(row: 2, col: 2)], answer: "RAT", clue: "")
        ]
        let down = [
            Entry(number: 1, cells: [Coordinate(row: 0, col: 0), Coordinate(row: 1, col: 0), Coordinate(row: 2, col: 0)], answer: "CAR", clue: ""),
            Entry(number: 2, cells: [Coordinate(row: 0, col: 1), Coordinate(row: 1, col: 1), Coordinate(row: 2, col: 1)], answer: "AER", clue: ""),
            Entry(number: 3, cells: [Coordinate(row: 0, col: 2), Coordinate(row: 1, col: 2), Coordinate(row: 2, col: 2)], answer: "TET", clue: "")
        ]
        return (across, down)
    }

    @Test func eligibilityWindowUsesFirstOfMonthThroughToday() async throws {
        let today = makeDate(year: 2026, month: 2, day: 10)
        let dates = Eligibility.eligibleDates(today: today, calendar: calendar)
        #expect(dates.count == 10)
        #expect(dates.first == makeDate(year: 2026, month: 2, day: 1))
        #expect(dates.last == today)
        #expect(Eligibility.isEligible(date: makeDate(year: 2026, month: 2, day: 1), today: today, calendar: calendar))
        #expect(!Eligibility.isEligible(date: makeDate(year: 2026, month: 2, day: 11), today: today, calendar: calendar))
    }

    @Test func navigationAdvancesAcrossThenSwitchesToDown() async throws {
        let entries = sampleEntries()
        let across = entries.across
        let down = entries.down
        let blackCells = Set<Coordinate>()

        let initial = NavigationLogic.initialState(
            acrossEntries: across,
            downEntries: down,
            width: 3,
            height: 3,
            blackCells: blackCells
        )
        #expect(initial?.phase == .across)
        #expect(initial?.entryIndex == 0)
        #expect(initial?.cellIndex == 0)

        let lastAcrossCell = NavigationState(phase: .across, entryIndex: 2, cellIndex: 2)
        let nextState = NavigationLogic.advanceState(
            lastAcrossCell,
            acrossEntries: across,
            downEntries: down,
            width: 3,
            height: 3,
            blackCells: blackCells
        )
        #expect(nextState?.phase == .down)
        #expect(nextState?.entryIndex == 0)
        #expect(nextState?.cellIndex == 0)
    }

    @Test func hintSkipsLockedCell() async throws {
        let entries = sampleEntries()
        let across = entries.across
        let down = entries.down
        let blackCells = Set<Coordinate>()
        let state = NavigationState(phase: .across, entryIndex: 0, cellIndex: 0)
        let lockedCells = Set([Coordinate(row: 0, col: 0)])

        let target = NavigationLogic.hintTarget(
            state: state,
            acrossEntries: across,
            downEntries: down,
            lockedCells: lockedCells,
            width: 3,
            height: 3,
            blackCells: blackCells
        )

        #expect(target == Coordinate(row: 0, col: 1))
    }

    @Test func validationChecksEntryAndPuzzleCompletionAndCorrectness() async throws {
        let entries = sampleEntries()
        let entry = entries.across[0]
        let solution: [[String?]] = [
            ["C", "A", "T"],
            ["A", "R", "E"],
            ["R", "A", "T"]
        ]
        let incomplete: [[String?]] = [
            ["C", nil, "T"],
            ["A", "R", "E"],
            ["R", "A", "T"]
        ]
        let filled: [[String?]] = solution
        let blackCells = Set<Coordinate>()

        #expect(!ValidationLogic.isEntryComplete(entry, filledGrid: incomplete))
        #expect(ValidationLogic.isEntryComplete(entry, filledGrid: filled))
        #expect(!ValidationLogic.isEntryCorrect(entry, filledGrid: incomplete, solutionGrid: solution))
        #expect(ValidationLogic.isEntryCorrect(entry, filledGrid: filled, solutionGrid: solution))
        #expect(!ValidationLogic.isPuzzleComplete(width: 3, height: 3, blackCells: blackCells, filledGrid: incomplete))
        #expect(ValidationLogic.isPuzzleComplete(width: 3, height: 3, blackCells: blackCells, filledGrid: filled))
        #expect(ValidationLogic.isPuzzleCorrect(width: 3, height: 3, blackCells: blackCells, filledGrid: filled, solutionGrid: solution))
    }
}
