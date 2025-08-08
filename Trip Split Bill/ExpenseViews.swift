//
//  ExpenseViews.swift
//  Trip Split Bill
//
//  Created by Kelvin on 08/08/25.
//

import SwiftUI

// MARK: - Expenses View
struct ExpensesView: View {
    @ObservedObject var tripManager: TripManager
    @Binding var showingAddExpense: Bool
    
    var body: some View {
        VStack {
            if let trip = tripManager.currentTrip {
                if trip.expenses.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "receipt")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No expenses yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("Tap the + button to add your first expense")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(trip.expenses) { expense in
                            ExpenseRowView(expense: expense)
                        }
                        .onDelete(perform: deleteExpenses)
                    }
                }
            }
        }
        .navigationTitle(tripManager.currentTrip?.name ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("New Trip") {
                    tripManager.currentTrip = nil
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    showingAddExpense = true
                }
            }
        }
    }
    
    private func deleteExpenses(offsets: IndexSet) {
        guard let trip = tripManager.currentTrip else { return }
        
        for index in offsets {
            let expense = trip.expenses[index]
            tripManager.deleteExpense(expense)
        }
    }
}

// MARK: - Expense Row View
struct ExpenseRowView: View {
    let expense: Expense
    @State private var showingReceipt = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: expense.category.icon)
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(expense.title)
                            .font(.headline)
                        
                        Text("Paid by \(expense.paidBy.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Split among: \(expense.splitAmong.map { $0.name }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if expense.receiptImageData != nil {
                    Button("View Receipt") {
                        showingReceipt = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(CurrencyFormatter.shared.format(expense.amount))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(CurrencyFormatter.shared.format(expense.amount / Double(expense.splitAmong.count))) each")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingReceipt) {
            ReceiptDetailView(expense: expense)
        }
    }
}

// MARK: - Receipt Detail View
struct ReceiptDetailView: View {
    let expense: Expense
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let imageData = expense.receiptImageData,
                       let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text(expense.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text("Amount:")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(CurrencyFormatter.shared.format(expense.amount))
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Paid by:")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(expense.paidBy.name)
                        }
                        
                        HStack {
                            Text("Category:")
                                .fontWeight(.semibold)
                            Spacer()
                            HStack {
                                Image(systemName: expense.category.icon)
                                Text(expense.category.rawValue)
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Split among:")
                                .fontWeight(.semibold)
                            
                            ForEach(expense.splitAmong, id: \.id) { person in
                                HStack {
                                    Text("• \(person.name)")
                                    Spacer()
                                    Text(CurrencyFormatter.shared.format(expense.amount / Double(expense.splitAmong.count)))
                                }
                            }
                        }
                        
                        if let notes = expense.notes, !notes.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Notes:")
                                    .fontWeight(.semibold)
                                Text(notes)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss modal
                    }
                }
            }
        }
    }
}

// MARK: - Add Expense View
struct AddExpenseView: View {
    @ObservedObject var tripManager: TripManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var title = ""
    @State private var amount = ""
    @State private var selectedPayer: Person?
    @State private var selectedParticipants: Set<UUID> = []
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var notes = ""
    
    // Receipt scanning
    @State private var showingScanner = false
    @State private var showingImagePicker = false
    @State private var receiptImage: UIImage?
    @State private var receiptImageData: Data?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Description (e.g., Groceries)", text: $title)
                    
                    HStack {
                        TextField("Amount (IDR)", text: $amount)
                            .keyboardType(.numberPad)
                        
                        if !amount.isEmpty, let amountValue = Double(amount) {
                            Text(CurrencyFormatter.shared.formatShort(amountValue))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    
                    TextField("Notes (optional)", text: $notes)
                }
                
                Section(header: Text("Receipt")) {
                    if let image = receiptImage {
                        HStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 100)
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            Button("Remove") {
                                receiptImage = nil
                                receiptImageData = nil
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        VStack(spacing: 10) {
                            Button("Scan Receipt") {
                                showingScanner = true
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Choose from Photos") {
                                showingImagePicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                if let trip = tripManager.currentTrip {
                    Section(header: Text("Who Paid?")) {
                        ForEach(trip.participants) { participant in
                            HStack {
                                Text(participant.name)
                                Spacer()
                                if selectedPayer?.id == participant.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPayer = participant
                            }
                        }
                    }
                    
                    Section(header: Text("Split Among")) {
                        ForEach(trip.participants) { participant in
                            HStack {
                                Text(participant.name)
                                Spacer()
                                if selectedParticipants.contains(participant.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedParticipants.contains(participant.id) {
                                    selectedParticipants.remove(participant.id)
                                } else {
                                    selectedParticipants.insert(participant.id)
                                }
                            }
                        }
                        
                        Button("Select All") {
                            selectedParticipants = Set(trip.participants.map { $0.id })
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(!canSaveExpense)
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            ReceiptScannerView(isPresented: $showingScanner) { receiptData in
                processScannedReceipt(receiptData)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(isPresented: $showingImagePicker, selectedImage: $receiptImage)
                .onChange(of: receiptImage) { image in
                    if let image = image {
                        receiptImageData = image.jpegData(compressionQuality: 0.8)
                    }
                }
        }
        .onAppear {
            if let trip = tripManager.currentTrip {
                selectedParticipants = Set(trip.participants.map { $0.id })
            }
        }
    }
    
    private var canSaveExpense: Bool {
        !title.isEmpty &&
        !amount.isEmpty &&
        Double(amount) != nil &&
        selectedPayer != nil &&
        !selectedParticipants.isEmpty
    }
    
    private func processScannedReceipt(_ receiptData: ReceiptData) {
        receiptImage = receiptData.image
        receiptImageData = receiptData.image.jpegData(compressionQuality: 0.8)
        
        if receiptData.totalAmount > 0 {
            amount = String(format: "%.0f", receiptData.totalAmount)
        }
        
        if !receiptData.merchantName.isEmpty && title.isEmpty {
            title = receiptData.merchantName
        }
    }
    
    private func saveExpense() {
        guard let trip = tripManager.currentTrip,
              let payer = selectedPayer,
              let amountValue = Double(amount) else { return }
        
        let participants = trip.participants.filter { selectedParticipants.contains($0.id) }
        
        let expense = Expense(
            title: title,
            amount: amountValue,
            paidBy: payer,
            splitAmong: participants,
            date: Date(),
            category: selectedCategory,
            receiptImageData: receiptImageData,
            notes: notes.isEmpty ? nil : notes
        )
        
        tripManager.addExpense(expense)
        presentationMode.wrappedValue.dismiss()
    }
}
