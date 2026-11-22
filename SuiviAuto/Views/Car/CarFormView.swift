import SwiftData
import SwiftUI

struct CarFormView: View {
    let car: Car?
    var onCreated: ((Car) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allCars: [Car]

    @State private var name = ""
    @State private var brand = ""
    @State private var modelName = ""
    @State private var plate = ""
    @State private var vin = ""
    @State private var firstRegistrationDate = Date.now
    @State private var usedPurchase = false
    @State private var purchaseDate = Date.now
    @State private var purchaseMileage: Int?
    @State private var fuel: FuelType = .essence
    @State private var colorHex = CarPalette.colors[0]
    @State private var photo: Data?
    @State private var pickingPhoto = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(car == nil ? "Nouvelle voiture" : "Modifier la voiture")
                .font(.title2.bold()).padding([.top, .horizontal])
            Form {
                Section {
                    HStack(spacing: 16) {
                        avatarPreview
                        VStack(alignment: .leading, spacing: 8) {
                            Button("Choisir une photo…") { pickingPhoto = true }
                            if photo != nil { Button("Retirer la photo", role: .destructive) { photo = nil } }
                            Text("ou glissez une image sur le cercle").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text("Couleur")
                        Spacer()
                        ForEach(Array(CarPalette.colors.enumerated()), id: \.element) { index, hex in
                            Button { colorHex = hex } label: {
                                Circle().fill(Color(hex: hex).gradient)
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().strokeBorder(.primary, lineWidth: colorHex == hex ? 2.5 : 0))
                                    .shadow(radius: 1, y: 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Couleur \(index + 1)")
                            .accessibilityAddTraits(colorHex == hex ? .isSelected : [])
                        }
                    }
                }
                Section {
                    TextField("Nom", text: $name, prompt: Text("ex. Clio de Marie"))
                    TextField("Marque", text: $brand)
                    TextField("Modèle", text: $modelName)
                    TextField("Immatriculation", text: $plate, prompt: Text("AB-123-CD"))
                    TextField("N° VIN", text: $vin)
                    DatePicker("1re immatriculation", selection: $firstRegistrationDate, displayedComponents: .date)
                    Toggle("Achetée d'occasion", isOn: $usedPurchase)
                    if usedPurchase {
                        DatePicker("Date d'achat", selection: $purchaseDate, displayedComponents: .date)
                        TextField("Km à l'achat", value: $purchaseMileage, format: .number)
                    }
                    Picker("Carburant", selection: $fuel) {
                        ForEach(FuelType.allCases) { Text($0.label).tag($0) }
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 520)
        .onAppear(perform: load)
        .fileImporter(isPresented: $pickingPhoto, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result { loadPhoto(url) }
        }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private var avatarPreview: some View {
        ZStack {
            if let photo, let image = NSImage(data: photo) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(Color(hex: colorHex).gradient)
                Image(systemName: "car.fill").font(.system(size: 30)).foregroundStyle(.white)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .shadow(color: Color(hex: colorHex).opacity(0.5), radius: 5, y: 3)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            loadPhoto(url)
            return true
        }
    }

    private func loadPhoto(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        if let data = ImageResizer.jpegData(from: url) { photo = data } else { errorMessage = "Image illisible." }
    }

    private func load() {
        guard let car else {
            colorHex = CarPalette.color(forIndex: allCars.count)
            return
        }
        name = car.name; brand = car.brand; modelName = car.modelName; plate = car.plate; vin = car.vin
        firstRegistrationDate = car.firstRegistrationDate; fuel = car.fuel; colorHex = car.colorHex; photo = car.photo
        usedPurchase = car.isUsedPurchase
        purchaseDate = car.purchaseDate ?? Date.now
        purchaseMileage = car.purchaseMileage
    }

    private func save() {
        if usedPurchase && purchaseDate < firstRegistrationDate {
            errorMessage = "La date d'achat doit être postérieure à la 1re immatriculation."
            return
        }
        let target: Car
        if let car {
            target = car
        } else {
            target = Car(name: name, firstRegistrationDate: firstRegistrationDate, colorHex: colorHex)
            context.insert(target)
            target.addDefaultRules(in: context)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.brand = brand; target.modelName = modelName; target.plate = plate.uppercased(); target.vin = vin.uppercased()
        target.firstRegistrationDate = firstRegistrationDate; target.fuel = fuel; target.colorHex = colorHex; target.photo = photo
        target.purchaseDate = usedPurchase ? purchaseDate : nil
        target.purchaseMileage = usedPurchase ? purchaseMileage : nil
        do {
            try context.save()
            if car == nil { onCreated?(target) }
            dismiss()
        } catch {
            // Annule l'insertion (voiture + règles) ou les modifications : rien de partiellement créé ne reste.
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
