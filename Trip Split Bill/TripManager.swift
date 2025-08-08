//
//  TripManager.swift
//  Trip Split Bill
//
//  Created by Kelvin on 08/08/25.
//

import SwiftUI
import Foundation
import Combine

// MARK: - Trip Manager with Online Sync
class TripManager: ObservableObject {
    @Published var currentTrip: Trip?
    @Published var isOnline = false
    @Published var isSyncing = false
    @Published var syncError: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let cloudService = CloudSyncService()
    
    init() {
        setupNetworkMonitoring()
        loadLocalTrip()
    }
    
    // MARK: - Trip Management
    func createTrip(name: String, participants: [Person], startDate: Date, endDate: Date) {
        let trip = Trip(name: name, participants: participants, expenses: [], startDate: startDate, endDate: endDate)
        currentTrip = trip
        saveLocalTrip()
        
        if isOnline {
            syncToCloud()
        }
    }
    
    func addExpense(_ expense: Expense) {
        currentTrip?.expenses.append(expense)
        currentTrip?.lastUpdated = Date()
        saveLocalTrip()
        
        if isOnline {
            syncToCloud()
        }
    }
    
    func deleteExpense(_ expense: Expense) {
        currentTrip?.expenses.removeAll { $0.id == expense.id }
        currentTrip?.lastUpdated = Date()
        saveLocalTrip()
        
        if isOnline {
            syncToCloud()
        }
    }
    
    func joinTripWithCode(_ code: String) {
        guard isOnline else {
            syncError = "Internet connection required to join trip"
            return
        }
        
        isSyncing = true
        
        cloudService.fetchTrip(withCode: code) { [weak self] result in
            DispatchQueue.main.async {
                self?.isSyncing = false
                
                switch result {
                case .success(let trip):
                    self?.currentTrip = trip
                    self?.saveLocalTrip()
                    self?.syncError = nil
                case .failure(let error):
                    self?.syncError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Calculations
    func calculateSettlements() -> [Settlement] {
        guard let trip = currentTrip else { return [] }
        
        var balances: [String: Double] = [:]
        
        // Initialize balances
        for participant in trip.participants {
            balances[participant.name] = 0.0
        }
        
        // Calculate balances
        for expense in trip.expenses {
            let splitAmount = expense.amount / Double(expense.splitAmong.count)
            
            // Person who paid gets credited
            balances[expense.paidBy.name, default: 0] += expense.amount
            
            // Everyone who should pay gets debited
            for person in expense.splitAmong {
                balances[person.name, default: 0] -= splitAmount
            }
        }
        
        // Create settlements
        var settlements: [Settlement] = []
        let sortedBalances = balances.sorted { $0.value < $1.value }
        var debtors = sortedBalances.filter { $0.value < 0 }
        var creditors = sortedBalances.filter { $0.value > 0 }
        
        var i = 0, j = 0
        while i < debtors.count && j < creditors.count {
            let debtor = debtors[i]
            let creditor = creditors[j]
            
            let settleAmount = min(-debtor.value, creditor.value)
            
            if settleAmount > 100 { // At least Rp100
                if let fromPerson = trip.participants.first(where: { $0.name == debtor.key }),
                   let toPerson = trip.participants.first(where: { $0.name == creditor.key }) {
                    settlements.append(Settlement(from: fromPerson, to: toPerson, amount: settleAmount))
                }
            }
            
            debtors[i] = (key: debtor.key, value: debtor.value + settleAmount)
            creditors[j] = (key: creditor.key, value: creditor.value - settleAmount)
            
            if abs(debtors[i].value) < 100 {
                i += 1
            }
            if abs(creditors[j].value) < 100 {
                j += 1
            }
        }
        
        return settlements
    }
    
    func getTotalExpenses() -> Double {
        return currentTrip?.expenses.reduce(0) { $0 + $1.amount } ?? 0
    }
    
    func getExpensesByCategory() -> [ExpenseCategory: Double] {
        guard let trip = currentTrip else { return [:] }
        
        var categoryTotals: [ExpenseCategory: Double] = [:]
        for expense in trip.expenses {
            categoryTotals[expense.category, default: 0] += expense.amount
        }
        return categoryTotals
    }
    
    // MARK: - Local Storage
    private func saveLocalTrip() {
        guard let trip = currentTrip else { return }
        
        do {
            let data = try JSONEncoder().encode(trip)
            UserDefaults.standard.set(data, forKey: "currentTrip")
        } catch {
            print("Failed to save trip locally: \(error)")
        }
    }
    
    private func loadLocalTrip() {
        guard let data = UserDefaults.standard.data(forKey: "currentTrip") else { return }
        
        do {
            currentTrip = try JSONDecoder().decode(Trip.self, from: data)
        } catch {
            print("Failed to load trip locally: \(error)")
        }
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        // Simple network check - in real app, use Network framework
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkNetworkStatus()
            }
            .store(in: &cancellables)
    }
    
    private func checkNetworkStatus() {
        // Simplified network check
        let url = URL(string: "https://www.google.com")!
        
        URLSession.shared.dataTask(with: url) { [weak self] _, _, error in
            DispatchQueue.main.async {
                self?.isOnline = error == nil
            }
        }.resume()
    }
    
    // MARK: - Cloud Sync
    private func syncToCloud() {
        guard let trip = currentTrip, isOnline else { return }
        
        isSyncing = true
        syncError = nil
        
        cloudService.syncTrip(trip) { [weak self] result in
            DispatchQueue.main.async {
                self?.isSyncing = false
                
                switch result {
                case .success:
                    self?.syncError = nil
                case .failure(let error):
                    self?.syncError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Cloud Sync Service
class CloudSyncService {
    private let baseURL = "https://your-firebase-or-api-endpoint.com"
    
    func syncTrip(_ trip: Trip, completion: @escaping (Result<Void, Error>) -> Void) {
        // Simulate API call - replace with your backend
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            // In real implementation, send trip data to your server
            completion(.success(()))
        }
    }
    
    func fetchTrip(withCode code: String, completion: @escaping (Result<Trip, Error>) -> Void) {
        // Simulate API call - replace with your backend
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            // In real implementation, fetch trip from server using code
            let error = NSError(domain: "TripError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Trip not found with code: \(code)"])
            completion(.failure(error))
        }
    }
}
