import Foundation

enum UnitDisplayFormatter {
    static func weightSymbol(_ unit: SettingsViewModel.WeightUnit) -> String {
        switch unit {
        case .kg: return "kg"
        case .lb: return "lb"
        }
    }

    static func distanceSymbol(_ unit: SettingsViewModel.DistanceUnit) -> String {
        switch unit {
        case .km: return "km"
        case .miles: return "mi"
        }
    }

    static func weightText(_ kilograms: Double, unit: SettingsViewModel.WeightUnit, maxFractionDigits: Int = 1) -> String {
        let value = UnitConverter.weightToDisplay(kilograms, unit: unit)
        return "\(decimalText(value, maxFractionDigits: maxFractionDigits)) \(weightSymbol(unit))"
    }

    static func volumeText(_ kilograms: Double, unit: SettingsViewModel.WeightUnit, maxFractionDigits: Int = 1) -> String {
        weightText(kilograms, unit: unit, maxFractionDigits: maxFractionDigits)
    }

    static func distanceText(_ kilometers: Double, unit: SettingsViewModel.DistanceUnit, maxFractionDigits: Int = 3) -> String {
        let value = UnitConverter.distanceToDisplay(kilometers, unit: unit)
        return "\(decimalText(value, maxFractionDigits: maxFractionDigits)) \(distanceSymbol(unit))"
    }

    static func decimalText(_ value: Double, maxFractionDigits: Int) -> String {
        let format = "%.\(maxFractionDigits)f"
        let fixed = String(format: format, value)
        let trimmed = fixed.replacingOccurrences(
            of: #"(\.\d*?[1-9])0+$|\.0+$"#,
            with: "$1",
            options: .regularExpression
        )
        return trimmed
    }
}
