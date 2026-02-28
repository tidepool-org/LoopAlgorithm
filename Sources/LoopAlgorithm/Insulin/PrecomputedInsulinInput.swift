// PrecomputedInsulinInput.swift
//
// An optimized input type for callers that evaluate many consecutive
// predictions sharing the same dose history (e.g., historical back-testing).
//
// The bottleneck in a dense prediction sweep is `doses.annotated(with: basal)`,
// which walks the entire dose + basal timeline on every call.  Between
// adjacent evaluation steps (typically 5 min apart) the annotated dose list
// changes only at its edges: the oldest doses age out of the lookback window
// and a tiny slice of new scheduled-basal fills in at the front.  Everything
// in between is identical.
//
// `PrecomputedInsulinInput` lets the caller perform annotation ONCE for the
// full pre-fetched window, then pass the already-annotated slice into
// `generatePrediction(start:precomputedInsulin:...)`.  Inside the algorithm
// this bypasses the `annotated(with:)` call entirely, saving ~O(n_doses) work
// per step.
//
// Additionally, the full `[GlucoseEffect]` insulin-effect timeline can be
// pre-computed for the entire sweep window and sliced per step — avoiding the
// O(n_doses × n_timepoints) inner loop on every call.  This is expressed as
// the optional `insulinEffects` field; when present the algorithm skips its
// own `glucoseEffects(...)` computation.
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │ Savings summary for a 7-day sweep at 5-min step (n ≈ 2016 steps)   │
// │                                                                     │
// │ annotated(with:)  O(D × B) per step  → once for the window         │
// │ glucoseEffects()  O(D × T) per step  → once (optional fast path)   │
// │ Everything else   CGM slice, RC, momentum — unchanged per step      │
// └─────────────────────────────────────────────────────────────────────┘
//
// Correctness note: callers are responsible for ensuring the annotated doses
// and (if supplied) insulin effects cover the required time range for each
// call.  See `generatePrediction(start:precomputedInsulin:...)` for details.

import Foundation

// MARK: - PrecomputedInsulinInput

/// Pre-annotated insulin data for use in multi-step prediction sweeps.
///
/// Create one instance per sweep window (typically a day or more), then pass
/// a time-sliced view into each `generatePrediction` call.
/// Note: Not `Sendable` because `BasalRelativeDose` holds `any InsulinModel`
/// (a non-Sendable existential). In practice this struct lives on a single
/// actor in evaluation sweeps, so the absence of `Sendable` is not limiting.
public struct PrecomputedInsulinInput {

    // MARK: Stored properties

    /// Doses already annotated against the scheduled basal timeline — the
    /// output of `[InsulinDose].annotated(with: basal)` for the full window.
    ///
    /// Slice this to `[t - insulinLookback, t]` (or `[t - lookback, t + 6h]`
    /// for future-insulin mode) before passing it to `generatePrediction`.
    public var annotatedDoses: [BasalRelativeDose]

    /// Pre-computed glucose-effect timeline for all `annotatedDoses`.
    ///
    /// When non-nil, `generatePrediction` clips this timeline to the needed
    /// range and skips its own `glucoseEffects(insulinSensitivityHistory:)`
    /// call.
    ///
    /// ⚠️ **Known limitation — timeline snapping:** `glucoseEffects` snaps
    /// its start date to the nearest 5-min boundary derived from the dose
    /// activity range.  When pre-building for a wide window the snap point
    /// may differ from what the per-step path computes, causing accumulated
    /// ICE differences of a few mg/dL at long horizons.  For clinical
    /// back-testing this is acceptable; for exact reproducibility leave this
    /// `nil` and rely on the annotation-only fast path.
    ///
    /// **ISF sweeps:** this cache is only valid when ISF does not change
    /// between calls.  Always set to `nil` when sweeping ISF multipliers.
    public var insulinEffects: [GlucoseEffect]?

    // MARK: Init

    public init(annotatedDoses: [BasalRelativeDose], insulinEffects: [GlucoseEffect]? = nil) {
        self.annotatedDoses = annotatedDoses
        self.insulinEffects = insulinEffects
    }
}

// MARK: - Convenience builder

extension PrecomputedInsulinInput {

    /// Annotate a full-window dose list once and, optionally, pre-compute the
    /// full insulin-effect timeline.
    ///
    /// Call this once before starting a sweep; then slice `annotatedDoses` and
    /// (if present) `insulinEffects` for each evaluation step.
    ///
    /// - Parameters:
    ///   - doses: All insulin doses for the sweep window, sorted by startDate.
    ///   - basal: Scheduled basal timeline covering the same window.
    ///   - sensitivity: ISF timeline.  Pass `nil` to skip effect pre-computation.
    ///   - effectsFrom: Start of the insulin-effect timeline (defaults to earliest dose start).
    ///   - effectsTo: End of the insulin-effect timeline (defaults to last dose end + activity duration).
    ///   - useMidAbsorptionISF: Use mid-absorption ISF for effect computation.
    /// - Returns: A `PrecomputedInsulinInput` ready to slice and pass into each step.
    public static func build<DoseType: InsulinDose>(
        doses: [DoseType],
        basal: [AbsoluteScheduleValue<Double>],
        sensitivity: [AbsoluteScheduleValue<LoopQuantity>]? = nil,
        effectsFrom: Date? = nil,
        effectsTo: Date? = nil,
        useMidAbsorptionISF: Bool = false
    ) -> PrecomputedInsulinInput {
        let annotated = doses.annotated(with: basal)

        var effects: [GlucoseEffect]? = nil
        if let sensitivity {
            if useMidAbsorptionISF {
                effects = annotated.glucoseEffectsMidAbsorptionISF(
                    insulinSensitivityHistory: sensitivity,
                    from: effectsFrom,
                    to: effectsTo
                )
            } else {
                effects = annotated.glucoseEffects(
                    insulinSensitivityHistory: sensitivity,
                    from: effectsFrom,
                    to: effectsTo
                )
            }
        }

        return PrecomputedInsulinInput(annotatedDoses: annotated, insulinEffects: effects)
    }
}
