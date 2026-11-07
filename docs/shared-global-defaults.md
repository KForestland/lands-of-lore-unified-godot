# Original shared global starting values

Fresh games now start Luther’s soul at5, Dawn’s relationship at1 and Bacatta’s relationship at1. These are the only nonzero bytes in the53-entry initial-global table extracted independently from GLOBAL.MIX entry3984507021. Earlier code implicitly used zero, which changed reward totals and would activate Bacatta57’s relationship-zero village return branch on the first visit.

`shared_global_defaults.gd` supplies these defaults to monastery initialization and missing-field reads in the Jungle, Bacatta61/65, Dawn and monastery handlers. Magic-shop initialization starts soul at5. Unknown globals still default to zero. Explicit saved values, including zero and negative values accepted by the existing state validators, remain unchanged. Missing fields use the original initial values; no attempt is made to infer unrecorded historical actions in older saves. Magic-shop offers retain their existing shared-state synchronization: an explicit monastery soul is authoritative; an absent monastery value can inherit an explicit shop value.

Reward expectations consequently change from soul0→1 to5→6, and Bacatta’s first offer changes relationship1→2. Existing story actions still explicitly set relationship to zero where specified. Native timing and other mechanics are unchanged by this correction.

Focused verification and source extraction are recorded in `shared-global-defaults-checks.json`. This change requires a new full suite, continuous campaign and demo candidate; R4 binaries retain the older defaults. Bacatta57 integration and Bob’s playtest acceptance remain separate gates.
