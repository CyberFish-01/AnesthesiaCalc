import Foundation

// MARK: - PediatricStatus

public enum PediatricStatus: Equatable {
    /// Neither condition met — standard adult dosing
    case inactive
    /// One of two conditions met — ambiguous, prompt clinician
    case prompt
    /// Both conditions met (age < 12 AND weight < 35 kg) — full pediatric mode
    case active
}

// MARK: - PediatricLogic

/// Pure-logic pediatric patient classifier.
///
/// Clinical thresholds:
/// - Age  < 12 years
/// - Weight < 35 kg
///
/// Both → `.active` (pediatric protocol)
/// One  → `.prompt` (show confirmation button)
/// None → `.inactive`
public enum PediatricLogic {

    public static func assess(age: Int, weightKg: Double) -> PediatricStatus {
        let ageFlag    = age < 12
        let weightFlag = weightKg < 35

        if ageFlag && weightFlag { return .active }
        if ageFlag || weightFlag { return .prompt }
        return .inactive
    }
}
