import Foundation

/// Règles de saisie du formulaire d'intervention (opérations, règle suggérée, valeurs détectées).
enum InterventionDraft {
    /// Règle proposée après avoir coché `operation` : la règle suggérée si aucune n'est choisie et qu'elle existe.
    static func ruleKey(afterChecking operation: MaintenanceOperation, current: String, available: Set<String>) -> String {
        guard current.isEmpty, let key = operation.suggestedRuleKey, available.contains(key) else { return current }
        return key
    }

    /// Champs du formulaire concernés par « Appliquer ».
    struct Fields: Equatable {
        var date: Date
        var mileageText: String
        var amountText: String
        var operations: Set<MaintenanceOperation>
        var ruleKey: String
    }

    /// Ne remplit que les champs détectés ; les opérations détectées s'ajoutent à celles déjà cochées.
    static func apply(_ extraction: InvoiceExtraction, to fields: Fields, availableRuleKeys: Set<String>) -> Fields {
        var f = fields
        if let date = extraction.date { f.date = date }
        if let mileage = extraction.mileage { f.mileageText = String(mileage) }
        if let cents = extraction.amountCents { f.amountText = Money.editString(cents: cents) }
        for op in extraction.operations where !f.operations.contains(op) {
            f.operations.insert(op)
            f.ruleKey = ruleKey(afterChecking: op, current: f.ruleKey, available: availableRuleKeys)
        }
        return f
    }

    /// Opérations à enregistrer : « Autre » est coché exactement quand une opération libre est saisie.
    static func storedOperations(_ checked: Set<MaintenanceOperation>, custom: String) -> [MaintenanceOperation] {
        var ops = checked
        if custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { ops.remove(.autre) } else { ops.insert(.autre) }
        return MaintenanceOperation.allCases.filter { ops.contains($0) }
    }
}
