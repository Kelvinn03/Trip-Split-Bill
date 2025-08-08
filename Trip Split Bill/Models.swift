//
//  Models.swift
//  Trip Split Bill
//
//  Created by Kelvin on 08/08/25.
//

import SwiftUI
import Foundation

// MARK: - Data Models
struct Person: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    
    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

struct Expense: Identifiable, Codable {
    var id: UUID
    var title: String
    var amount: Double
    var paidBy: Person
    var splitAmong: [Person]
    var date: Date
    var category: ExpenseCategory
    var receiptImageData: Data?
    var notes: String?
    
    init(title: String, amount: Double, paidBy: Person, splitAmong: [Person], date: Date, category: ExpenseCategory, receiptImageData: Data? = nil, notes: String? = nil) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.paidBy = paidBy
        self.splitAmong = splitAmong
        self.date = date
        self.category = category
        self.receiptImageData = receiptImageData
        self.notes = notes
    }
}

enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "Food"
    case accommodation = "Accommodation"
    case transport = "Transport"
    case activities = "Activities"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .accommodation: return "house.fill"
        case .transport: return "car.fill"
        case .activities: return "figure.hiking"
        case .other: return "plus.circle"
        }
    }
}

struct Trip: Identifiable, Codable {
    var id: UUID
    var name: String
    var participants: [Person]
    var expenses: [Expense]
    var startDate: Date
    var endDate: Date
    var shareCode: String?
    var lastUpdated: Date
    
    init(name: String, participants: [Person], expenses: [Expense], startDate: Date, endDate: Date) {
        self.id = UUID()
        self.name = name
        self.participants = participants
        self.expenses = expenses
        self.startDate = startDate
        self.endDate = endDate
        self.shareCode = Self.generateShareCode()
        self.lastUpdated = Date()
    }
    
    private static func generateShareCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map{ _ in letters.randomElement()! })
    }
}

struct Settlement {
    let from: Person
    let to: Person
    let amount: Double
}

// MARK: - Currency Formatter
struct CurrencyFormatter {
    static let shared = CurrencyFormatter()
    
    private let formatter: NumberFormatter
    
    init() {
        formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "IDR"
        formatter.currencySymbol = "Rp"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
    }
    
    func format(_ amount: Double) -> String {
        return formatter.string(from: NSNumber(value: amount)) ?? "Rp0"
    }
    
    func formatShort(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return "Rp\(String(format: "%.1f", amount / 1_000_000))M"
        } else if amount >= 1_000 {
            return "Rp\(String(format: "%.0f", amount / 1_000))K"
        } else {
            return format(amount)
        }
    }
}
