# Dawn's library translation and the Dampen charm

Source: MLIB_.WOM message8 (exit request, image 0x6C0). When the player leaves the library with local `Gave_Dawn_Runes` = 1, flag192 clear and Dawn installed (same setup rules as `dawn_present`), the DLL sets flag192, plays movies 3/663–668 (664 with movie flags 0x80), gives "70-Dampen ch" after 666, sets `GV_RUNES_TRANSLATED` and `GV_DAWN_TRANSLATED_RUNES` to 1 and flag266, then returns to the hall. Otherwise (flag190 clear, Dawn present) it plays 774/775 without a grant; that branch is not staged. Dawn translating the runes is an alternative to Julian's translation. Evidence: `docs/monastery-dawn-runes-source.json` (`tools/prepare_monastery_dawn_runes.py` asserts the call sequence).

The only producer of `Gave_Dawn_Runes` (Jungle local17) is Dawn actor63's wax-runes offer (group 29704), already modelled by `jungle_dawn`. Dawn keeps that local in her own state; the monastery room bank now follows it on room entry and exit, so the library sees the offer.

The Dampen charm is GLOBAL definition72 (identity 0x43F8BC0D), use handler27 (0x979A8): it removes the held charm and sets player byte 0x23ABD bit0 (sibling handlers set bits 2/4/8 for the Control token, Lizard seal and Bestial disk). No native reader of that bit was found, so its native effect is not established. The port consumes the charm through the inventory "Use charm" button and saves `dampened` in the item-effect state (valid only after consumption). Modern adapter (lead-authorised): using it cancels a pending curse warning.

Validation: actual Jungle host and monastery rooms with supplied quest progress and Dawn's local17 (her offer itself is covered by jungle_dawn_state_test), real room exits and staged original movies, mid-sequence disk reload, inventory use and save validation.

When inventory is full, the charm is retained in the saved pending-reward list and delivered when room is available. Capacity and duplicate retry are checked independently.
