//
//  ContentView.swift
//  Trip Split Bill
//
//  Created by Kelvin on 08/08/25.
//

import SwiftUI

struct ContentView: View {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
