//
//  SummaryTripAndSettlementViews.swift
//  Trip Split Bill
//
//  Created by Kelvin on 08/08/25.
//

import SwiftUI

// MARK: - Summary View
struct SummaryView: View {
    @ObservedObject var tripManager: TripManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Total Expenses Card
                VStack(spacing: 10) {
                    Text("Total Expenses")
                        .font(.headline)
                    
                    Text(CurrencyFormatter.shared.format(tripManager.getTotalExpenses()))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    if let trip = tripManager.currentTrip {
                        Text("\(trip.expenses.count) expense\(trip.expenses.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Category Breakdown
                VStack(alignment: .leading, spacing: 15) {
                    Text("Expenses by Category")
                        .font(.headline)
                    
                    let categoryTotals = tripManager.getExpensesByCategory()
                    
                    if categoryTotals.isEmpty {
                        Text("No expenses yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            if let amount = categoryTotals[category], amount > 0 {
                                HStack {
                                    Image(systemName: category.icon)
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    
                                    Text(category.rawValue)
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing) {
                                        Text(CurrencyFormatter.shared.format(amount))
                                            .fontWeight(.semibold)
                                        
                                        if tripManager.getTotalExpenses() > 0 {
                                            Text("\(Int((amount / tripManager.getTotalExpenses()) * 100))%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                            .frame(height: 4)
                                        
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(width: tripManager.getTotalExpenses() > 0 ?
                                                  geometry.size.width * (amount / tripManager.getTotalExpenses()) : 0,
                                                  height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Per Person Summary
                if let trip = tripManager.currentTrip {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Per Person Average")
                            .font(.headline)
                        
                        let averagePerPerson = tripManager.getTotalExpenses() / Double(trip.participants.count)
                        
                        ForEach(trip.participants) { participant in
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text(String(participant.name.prefix(1)).uppercased())
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    )
                                
                                Text(participant.name)
                                
                                Spacer()
                                
                                Text(CurrencyFormatter.shared.format(averagePerPerson))
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total Split")
                                .fontWeight(.bold)
                            Spacer()
                            Text(CurrencyFormatter.shared.format(tripManager.getTotalExpenses()))
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Sync Status
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: tripManager.isOnline ? "wifi" : "wifi.slash")
                            .foregroundColor(tripManager.isOnline ? .green : .orange)
                        
                        Text(tripManager.isOnline ? "Online - Auto sync enabled" : "Offline - Changes saved locally")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if tripManager.isSyncing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing changes...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let trip = tripManager.currentTrip {
                        Text("Last updated: \(DateFormatter.localizedString(from: trip.lastUpdated, dateStyle: .short, timeStyle: .short))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Settlements View
struct SettlementsView: View {
    @ObservedObject var tripManager: TripManager
    
    var body: some View {
        VStack {
            let settlements = tripManager.calculateSettlements()
            
            if settlements.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("All settled up!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("No one owes anyone money")
                        .foregroundColor(.secondary)
                    
                    if tripManager.getTotalExpenses() > 0 {
                        VStack(spacing: 8) {
                            Text("Trip Total: \(CurrencyFormatter.shared.format(tripManager.getTotalExpenses()))")
                                .font(.headline)
                            
                            if let trip = tripManager.currentTrip {
                                Text("Split equally among \(trip.participants.count) people")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary card
                        VStack(spacing: 10) {
                            Text("Settlement Required")
                                .font(.headline)
                            
                            Text("\(settlements.count) payment\(settlements.count == 1 ? "" : "s") needed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Total: \(CurrencyFormatter.shared.format(settlements.reduce(0) { $0 + $1.amount }))")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Settlement list
                        VStack(spacing: 12) {
                            ForEach(settlements.indices, id: \.self) { index in
                                let settlement = settlements[index]
                                
                                SettlementRowView(settlement: settlement)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Settlements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Settlement Row View
struct SettlementRowView: View {
    let settlement: Settlement
    @State private var isPaid = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // From person
                VStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(settlement.from.name.prefix(1)).uppercased())
                                .font(.headline)
                                .fontWeight(.bold)
                        )
                    
                    Text(settlement.from.name)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Arrow and amount
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text(CurrencyFormatter.shared.format(settlement.amount))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                // To person
                VStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(settlement.to.name.prefix(1)).uppercased())
                                .font(.headline)
                                .fontWeight(.bold)
                        )
                    
                    Text(settlement.to.name)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Payment status toggle
            Button(action: {
                isPaid.toggle()
            }) {
                HStack {
                    Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isPaid ? .green : .gray)
                    
                    Text(isPaid ? "Paid" : "Mark as Paid")
                        .foregroundColor(isPaid ? .green : .primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isPaid ? Color.green.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(isPaid ? 0.6 : 1.0)
    }
}
