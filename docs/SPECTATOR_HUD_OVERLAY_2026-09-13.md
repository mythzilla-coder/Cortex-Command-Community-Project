# Spectator HUD overlay — 2026-09-13

## Decision

Add a small stream-facing overlay using the existing Lua activity state and
screen primitive APIs. Keep the accepted engagement camera unchanged and do
not add actor tracking or gameplay behavior.

## Behavior

- Upper-left panel: team 1 faction, living count, and cumulative score.
- Upper-right panel: team 2 faction, living count, and cumulative score.
- Center header: round number and elapsed time.
- Center subheader: combat-pressure elapsed/threshold indicator.
- Round result: centered winner banner with the updated score and next-round cue.

## Verification

- Pure HUD formatter test: PASS.
- Python integration suite: 11 tests PASS.
- Camera event test: PASS.
- AI controller test: PASS.
- Lua load checks: PASS.
- `git diff --check`: PASS.
- Native Debug Release capture: 100 frames reviewed with readable corner and
  center HUD, unchanged camera framing, and a transition into round 2.
- Runtime log: `ROUND_RESULT` winner/score transition observed without Lua
  errors. The final capture window ended before a result-banner frame could be
  retained, so result rendering is supported by code and formatter coverage
  plus the runtime boundary, not claimed as a captured visual frame.

Decision: **ACCEPTED_FOR_THIS_REVIEW_BUILD**.

## Deferred camera idea

The suggested nearby-ally firing aggregation remains a future camera-v2
candidate. It should only be explored as a bounded, cooldown-gated aggregate
of recent fire events if a later visual review shows the single-shooter cue is
insufficient. No battlefield-wide tracking system is introduced here.
