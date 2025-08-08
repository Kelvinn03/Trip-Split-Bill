//
//  MainViews.swift
//  Trip Split Bill
//
//  Created by Kelvin on 08/08/25.
//

import SwiftUI

// MARK: - Content View
struct MainViews: View {
    @StateObject private var tripManager = TripManager()
    
    var body: some View {
        NavigationView {
            if tripManager.currentTrip == nil {
                TripSetupView(tripManager: tripManager)
            } else {
                TripDashboardView(tripManager: tripManager)
            }
        }
        .alert("Sync Error", isPresented: .constant(tripManager.syncError != nil)) {
            Button("OK") {
                tripManager.syncError = nil
            }
        } message: {
            Text(tripManager.syncError ?? "")
        }
    }
}

// MARK: - Trip Setup View
struct TripSetupView: View {
    @ObservedObject var tripManager: TripManager
    @State private var tripName = ""
    @State private var participantNames: [String] = [""]
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400)
    @State private var showingJoinTrip = false
    @State private var joinCode = ""
    
    var body: some View {
        VStack {
            if tripManager.isSyncing {
                ProgressView("Syncing...")
                    .padding()
            }
            
            Form {
                Section(header: Text("Trip Details")) {
                    TextField("Trip Name (e.g., Glamping Adventure)", text: $tripName)
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
                
                Section(header: Text("Participants")) {
                    ForEach(participantNames.indices, id: \.self) { index in
                        HStack {
                            TextField("Participant Name", text: $participantNames[index])
                            
                            if participantNames.count > 1 {
                                Button("Remove") {
                                    participantNames.remove(at: index)
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button("Add Participant") {
                        participantNames.append("")
                    }
                    .foregroundColor(.blue)
                }
                
                Section {
                    Button("Create Trip") {
                        createTrip()
                    }
                    .disabled(!canCreateTrip)
                }
                
                Section(header: Text("Join Existing Trip")) {
                    HStack {
                        TextField("Enter Trip Code", text: $joinCode)
                            .textCase(.uppercase)
                        
                        Button("Join") {
                            tripManager.joinTripWithCode(joinCode)
                        }
                        .disabled(joinCode.count != 6 || !tripManager.isOnline)
                    }
                }
            }
        }
        .navigationTitle("New Trip")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if tripManager.isOnline {
                        Image(systemName: "wifi")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private var canCreateTrip: Bool {
        !tripName.isEmpty &&
        participantNames.filter { !$0.isEmpty }.count >= 2 &&
        startDate <= endDate
    }
    
    private func createTrip() {
        let participants = participantNames
            .filter { !$0.isEmpty }
            .map { Person(name: $0) }
        
        tripManager.createTrip(
            name: tripName,
            participants: participants,
            startDate: startDate,
            endDate: endDate
        )
    }
}

// MARK: - Trip Dashboard View
struct TripDashboardView: View {
    @ObservedObject var tripManager: TripManager
    @State private var showingAddExpense = false
    
    var body: some View {
        TabView {
            ExpensesView(tripManager: tripManager, showingAddExpense: $showingAddExpense)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Expenses")
                }
            
            SummaryView(tripManager: tripManager)
                .tabItem {
                    Image(systemName: "chart.pie")
                    Text("Summary")
                }
            
            SettlementsView(tripManager: tripManager)
                .tabItem {
                    Image(systemName: "dollarsign.circle")
                    Text("Settlements")
                }
            
            ShareView(tripManager: tripManager)
                .tabItem {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(tripManager: tripManager)
        }
    }
}

// MARK: - Share View
struct ShareView: View {
    @ObservedObject var tripManager: TripManager
    
    var body: some View {
        VStack(spacing: 30) {
            if let trip = tripManager.currentTrip {
                VStack(spacing: 15) {
                    Text("Share Trip")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Share this code with others to let them join your trip")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 20) {
                    Text(trip.shareCode ?? "N/A")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    HStack(spacing: 20) {
                        Button("Copy Code") {
                            UIPasteboard.general.string = trip.shareCode
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Share") {
                            shareTrip()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: tripManager.isOnline ? "wifi" : "wifi.slash")
                            .foregroundColor(tripManager.isOnline ? .green : .red)
                        Text(tripManager.isOnline ? "Online - Auto sync enabled" : "Offline - Changes saved locally")
                            .font(.caption)
                    }
                    
                    if tripManager.isSyncing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing...")
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .navigationTitle("Share")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func shareTrip() {
        guard let trip = tripManager.currentTrip,
              let shareCode = trip.shareCode else { return }
        
        let activityController = UIActivityViewController(
            activityItems: ["Join my trip '\(trip.name)' with code: \(shareCode)"],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
}
