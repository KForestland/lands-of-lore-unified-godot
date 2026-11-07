
## Owner requests answered from the original data (no deviation)

- **2026-10-21, cave shrine blocks (report 2026-10-20 18:53, "should be able to move them").**
  - In the original the player cannot push them.
  - Each block's only script is a contact event that fires for actor38, the colonnade guard. The contact walker is at AE7D8; case 6 needs the other object to be actor 38.
  - The guard appears when the player enters region1941. When he chases the player and touches a block, both blocks slide into the side niches. The longplay shows them closed at 9:05 and open at 9:35.
  - CORRECTED 2026-10-21: the longplay at 4 fps (9:04–9:10) shows the blocks parting as the human player presses in,
    with no guard in view (Codex witness b_shrine.jpg). The port now also opens them on player contact (see the
    ledger above).
