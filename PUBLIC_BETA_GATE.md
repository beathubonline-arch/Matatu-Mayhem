# Matatu Mayhem — Public Beta Build Gate

## Milestone 1 — Street King retention loop
- Rotating Nairobi shifts with escalating targets and KSh/REP rewards.
- Route mastery 1–10.
- Persistent lifetime driver stats.
- Street King career summit.
- First-run onboarding.

## Milestone 2 — Rival Heat
- Named route rivals.
- Rival target times.
- Win/loss persistence and rival win streaks.
- Rival victories feed shifts, mastery, hype and reputation.

## Milestone 3 — Nganya Dream
- Purchasable rank-gated nganyas.
- Vehicle-specific performance profiles.
- Engine, brake and capacity upgrades.
- Garage shows current cash, next dream nganya and exact money gap.

## Milestone 4 — Crew Challenge
- Route result card.
- Copy-to-clipboard driver challenge for sharing.
- Touch controls remain available.
- Broken Web radio controls are hidden until Web long-form audio is repaired.

## Milestone 5 — Public Beta hardening
- Two routes available on a fresh save.
- Waiyaki and Thika remain progression unlocks.
- Corridor district order matches corridor order.
- Save schema includes all Street King progression fields.
- Web export preset remains the release target.

## Runtime acceptance test (must be performed on the actual exported build)
1. Fresh save: choose Ngong or Mombasa and understand the objective without external explanation.
2. Complete outbound service, board/alight passengers, receive fares and route reward.
3. Start return trip and arrive back at CBD.
4. Complete enough runs/passengers/rival wins to finish CBD HUSTLE; verify KSh 15,000 and REP reward.
5. Start another route; verify next shift rotates to STAGE PRESSURE.
6. Verify route mastery persists after reload.
7. Win then lose rival battles; verify streak increments then resets.
8. Buy an upgrade; reload and verify it persists.
9. Buy/select an available nganya and verify its handling/performance profile loads.
10. Finish a route and use COPY CHALLENGE; verify clipboard contains driver stats.
11. Test touch controls on Android browser in landscape.
12. Confirm there are no red runtime errors during two complete CBD round trips.

Web radio is deliberately not a Public Beta blocker. It remains a separate known issue until long-form Web audio is repaired.
