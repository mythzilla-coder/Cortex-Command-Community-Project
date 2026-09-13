# Spectator camera capture review — 2026-09-13

## Result

**Promising partial visual evidence; HOLD_FOR_VISUAL_ACCEPTANCE.**

## Capture

- Window: `Cortex Command Community Project (Debug Release)`
- Local capture: `work/native-camera-capture-2026-09-13/`
- Sample: 50 PNG frames at approximately 2 frames per second
- Frame size: 976x579
- Observed segment: end of round 28 and beginning of round 29
- Source: `e7422a9c8` (`fix: make spectator camera dependency self-contained`)
- Production mode: `AI_V2_MODE = "OFF"`

## Observations

- Active hill/valley combat remained in view across the sampled segment.
- The camera followed the main combat groups as they moved across the terrain.
- The round transition centered the airborne squad instead of holding on empty
  terrain.
- No sustained empty-terrain lock or obvious jitter was visible in these frames.

## Limits

This short capture did not establish a deliberately observed off-screen event
cut, event hold/return timing, victim deduplication, last-survivor priority, or
the required 3–5 complete-round review. Static frame sampling also cannot prove
kill attribution. The camera remains unaccepted until those gates are reviewed.

## Next gate

Review 3–5 complete rounds with deliberate attention to event response and
return behavior. Keep the conservative thresholds and `AI_V2_MODE = "OFF"`
unless the evidence supports a narrowly scoped tuning change.
