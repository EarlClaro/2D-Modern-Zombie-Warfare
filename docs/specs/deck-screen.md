# Deck screen with card pictures (increment D.1)

Status: **built 2026-10-18; waits for the user's manual check (look, scrolling, arrow keys).** Source: user request "improve the UI interface for player to pick or edit his card deck, show the cards instead of just text, and show all the cards but greyed out as locked". Extends the deck editor of docs/specs/progression.md (5.4); the rules in `DeckBuilder` are unchanged.

## Behaviour
- **All cards are shown.** The left grid ("Cards", `Owned`) lists every card of the game (31 today): the cards the player owns first (deckable ones cheapest first then by name, then the doctrines), then the locked ones in the same order. Owned cards are in full colour; cards the player does not own yet are **locked**: drawn in grey with a padlock, still readable (name, cost, picture) so the player sees what there is to win. The heading counts them ("Cards 14 / 31 unlocked").
- **Cards, not text.** Each card is a small portrait card like the one in the hand (kind colour, cost badge, picture, name banner). An owned card shows `copies in deck / copies allowed`; the chosen doctrine shows "ON". The right grid (`Deck`) shows one card per distinct card in the deck with its count ("x3"), cheapest first.
- **Selecting** a card (click, or arrow keys with Tab to switch grid) shows it at 2x with its details on the right. A locked card shows its description and "Locked: win <mission> to have it offered as a reward" (the first mission of the campaign whose reward pool holds it) and its Add button reads "Locked" and is disabled. Upgrades are shown for owned cards only.
- **Editing** is as before: Add / Remove buttons, Enter or double-click on a card adds (left grid) or removes (right grid), "Starter deck", Back/Esc. Every change goes through `DeckBuilder` (a refusal says why in the status line) and is saved at once.

## Files
- `ui/card_face.gd` (`CardFace`): one portrait card as a Control; owned / locked, badge text, selected; click and double-click signals; the grey look is a shared shader material (`CardFace.grey_material()`).
- `ui/card_grid.gd` (`CardGrid`): a scrolling grid of faces with one selected card, arrow-key movement, scroll-to-selected.
- `ui/deck_screen.gd`: uses two `CardGrid`s instead of the two lists.
- `scripts/progression/deck_builder.gd`: `catalog(db)` (every card id in display order). `scripts/progression/campaign_definition.gd`: `mission_offering(card_id)`.

## Acceptance
- The left grid holds one face per card in the database; faces of cards not in the collection are locked, the others are not.
- Add/remove/doctrine/reset/upgrade flows behave as before (existing deck-editor tests, adapted to the grids).
- Locked card: Add disabled, details name the mission that can offer it.
- Manual: look and feel at 1920 x 1080 (grey legibility, grid size, scrolling, keyboard).
