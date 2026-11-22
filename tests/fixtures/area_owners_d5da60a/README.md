# Area owner baseline

Captured before the F-16 migration on Plan1 323aec5. The three converted hosts are byte-identical to d5da60a (hashes in manifest.json). Scripted direct children preserve owner/engine interleaving; automatic node names are normalized, and the future AreaOwners node is ignored. PlayerHealth is the already-qualified Plan1 addition. Mesh exclusions record the complete `excluded_faces` dictionary; collision exclusions evaluate `include_collision_face` for every pack face. Other static mesh filters (`skipped_faces`, retired faces and the base static predicate) stay in unchanged engine code, checked by the source/scope receipt.

Each *_save.json was written by the unchanged host in a quiescent initial Classic scene. They complement the five Plan1 d5 saves; none claim earned progress. Do not regenerate during migration. Opt-in capture: LOL2_WRITE_AREA_GOLDENS=1 with area_owner_order_test, on the pinned baseline only.
