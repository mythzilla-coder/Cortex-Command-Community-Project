# Spectator AI V2 Shadow and Tactical Coordination Design

Date: 2026-09-02  
Project: Cortex Command Community Project / Spectator Arena  
Status: Approved design; implementation plan follows user review

## Objective

Improve the 8v8 Spectator Arena AI with more independent squad intent, weapon-aware positioning, environmental reasoning, imperfect contact memory, and gradual recovery while preserving the proven V11/V11.1 combat loop.

The system must make the AI more capable at deciding where and why to fight without replacing the native actor motor that already handles how actors move, aim, fire, reload, jetpack, dig, and react locally.

## Architectural boundary

`SpectatorAIController` is an activity-level tactical coordinator above `NativeHumanAI`.

The coordinator may observe actors, maintain round-scoped state, score strategic destinations, assign squad tasks, remember uncertain contacts, and propose high-level intent.

The coordinator must not directly implement or replace:

- aiming or firing
- reload or weapon handling
- locomotion execution
- jetpack execution
- digging execution
- immediate enemy reaction
- custom controller input
- replacement pathfinding

During `OFF` and `SHADOW`, the coordinator must not mutate actor AIMode, waypoints, controllers, inventory, health, position, or combat state.

## Preservation contract

The accepted V11/V11.1 flow remains unchanged:

`SPAWN -> SENTRY -> TOUCHDOWN -> RELEASE -> ALL_RELEASED -> AI_V2_WARMUP -> TACTICAL_ACTIVE`

AI V2 may not register tactical control before the existing touchdown/release boundary. All living actors must still be individually released, and the all-released gate remains authoritative.

The current production default is `AI_V2_MODE = "OFF"`. No mode change is part of this design approval.

## Rollout modes

### OFF

The coordinator records only lifecycle-safe instrumentation. Existing V11/V11.1 behavior is authoritative and unchanged.

### SHADOW

The coordinator computes contacts, tasks, destinations, reservations, weapon/environment scores, and recovery proposals, but logs proposals without applying actor changes. SHADOW is the first behavior-analysis mode after the 50-round OFF baseline.

### TASKS

The coordinator may apply validated squad-level task and destination assignments after explicit evidence review. NativeHumanAI still executes movement and combat.

### TACTICAL

The coordinator may use the complete validated task, weapon, environment, contact, and recovery policy. It remains prohibited until TASKS evidence shows no regression in lifecycle, combat participation, stuck exposure, watchdog rate, or CPU cost.

## State model

The controller owns round-scoped state:

`Config`, `RoundGeneration`, `ActorState`, `TeamState`, `Squads`, `ContactMemory`, `TargetReservations`, `EventLog`, `Metrics`, and `Scheduler`.

Each actor state includes:

- UniqueID, team, spawn index, squad ID, and released flag
- current task, task start time, strategic target, destination, and destination score
- bounded position history and waypoint distance
- last progress time and recovery stage
- last health, fire, damage, and visible-enemy timestamps
- hard-engagement expiry
- decision and retask counters

Each contact includes enemy ID, frozen last-known position, last-seen time, confidence, source, and uncertainty. Hidden enemy positions must never be injected as direct team knowledge.

## Squad model and tasks

Each team begins with two four-actor squads. Squad membership is deterministic within a round and may be reassigned only at a controlled future boundary.

Initial task vocabulary:

- `PRESSURE`: advance toward a credible contact or strategic engagement anchor.
- `MANEUVER`: approach from a distinct alternate angle or route.
- `SEARCH`: investigate a stale last-known contact with bounded confidence.
- `REGROUP`: restore spacing and reconnect separated actors.
- `RECOVER`: resolve path delay, blockage, or prolonged lack of progress.

Every task has a reason, destination, start time, success condition, failure condition, timeout, and recovery task. Task changes use hysteresis so a small score difference does not cause churn.

## Engagement lock

An actor becomes hard-engaged after strong recent evidence such as direct line of sight, recent firing, recent damage, or close hostile proximity. The initial observation window is configurable in the controller and must be tuned from logs rather than assumed permanent.

While hard-engaged, SHADOW may continue measuring but must not propose minor waypoint replacement as an urgent decision. Future TASKS/Tactical application may override only for emergency recovery or a materially superior validated action.

## Weapon reasoning

Weapon metadata is observational first. The coordinator records broad weapon class, range tendency, ammunition/reload limitations when available, recent firing, and confidence of the classification.

Initial strategic implications:

- close-range weapons prefer flanks, cover, and shorter approach paths
- long-range weapons prefer distance, elevation, and clear sightlines
- heavy or suppression-capable weapons prefer support lanes and clustered enemy pressure
- explosives may score blocked routes, dense targets, and destructible barriers
- low ammunition or uncertain weapon state reduces confidence rather than forcing an unsafe action

The coordinator chooses destinations and tasks; NativeHumanAI remains responsible for using the weapon.

## Environment reasoning

Use bounded, transient spatial queries rather than a permanent influence map in the first implementation. A destination score may combine:

`weapon suitability + line of sight + cover/exposure + squad spacing + path reliability + strategic proximity - enemy concentration - crowding`

Queries may include terrain height, slope, LOS, path length, path status, vertical access, nearby actors, chokepoints, and recent terrain changes when supported by verified local APIs.

The coordinator must audit local API signatures before relying on development-branch assumptions. No replacement `PathFinder`, GOAP system, full influence grid, permanent cover-node database, or forced jetpack behavior is included.

## Contact memory and information limits

Contacts are timestamped and confidence-decayed. Direct observations have higher confidence than teammate reports. Shared reports include age and uncertainty. Expired contacts become search candidates or disappear from tactical consideration.

The system must never use omniscient hidden enemy positions as if an actor had seen them. This rule applies to scoring, reservations, destination selection, and telemetry labels.

## Recovery ladder

Recovery escalates only when evidence persists:

1. wait for a pending path or delayed engine response
2. re-evaluate the current destination
3. refresh the path
4. choose a nearby alternate destination
5. regroup with teammates
6. search from a new bounded position
7. apply a stronger recovery proposal only in a later validated mode

Recovery is measured separately from ordinary task changes and must not become a high-frequency retask loop.

## Telemetry and metrics

Telemetry uses the existing `SPECTATOR_EVENT` format and activity-scoped snapshot path. New fields are added only when real runtime output proves them.

Required observations before behavior activation include:

- first contact, first shot, first damage, and combat participation
- task and target churn
- hard-engagement duration
- target reservations and dogpiling
- squad spacing and separation
- position progress and stuck exposure
- path refreshes and recovery stages
- weapon classification confidence and usage context
- round duration, watchdog outcome, and CPU/UPS impact when available

Every record must identify round generation and mode. The reporting tool must ignore malformed or unrelated console noise.

## Testing strategy

Pure controller rules are tested under cached Fengari without engine construction. Tests cover:

- default mode and round reset
- stale-ID isolation
- bounded actor position history
- frozen contact memory and confidence expiry
- engagement-lock timing
- task hysteresis
- reservation expiry and dogpile limits
- progress thresholds and recovery escalation
- weapon/environment score determinism
- no hidden-position contact updates
- deterministic snapshots

Activity integration tests verify:

- V11/V11.1 release boundary remains authoritative
- OFF and SHADOW contain no tactical actor mutation
- round generation resets all AI V2 state
- telemetry fields are emitted through the existing path

Before each mode transition, run Lua tests, Python tests, `git diff --check`, Debug Release x64 build, and a runtime soak appropriate to the gate.

## Activation gates

### Gate 1: OFF baseline

- at least 50 completed rounds
- no unexplained lifecycle or touchdown regression
- reportable round durations, winners, watchdog rate, and runtime stability

### Gate 2: SHADOW review

- plausible contacts without omniscient tracking
- bounded task/target churn
- meaningful weapon/environment differentiation
- recovery proposals correlate with actual lack of progress
- no unacceptable CPU/UPS cost

### Gate 3: TASKS review

- task application does not break touchdown or native combat
- lower or equal stuck exposure
- no watchdog-rate regression
- stable squad separation and participation

### Gate 4: TACTICAL review

- repeatable improvement against the same baseline conditions
- explainable decisions in telemetry
- preserved round-loop stability
- explicit user approval before default activation

## Deferred scope

The first implementation does not include reinforcement learning, runtime LLM control, full GOAP, direct controller manipulation, custom aiming, custom firing, a replacement pathfinder, permanent cover nodes, grenade micro-management, personality simulation, or a pacing director.

## Immediate next step

Finish the 50-round OFF baseline and preserve its report. Then implement SHADOW-only contact, progress, weapon, environment, and task proposals behind an explicit mode flag. Do not enable TASKS or TACTICAL behavior until the corresponding evidence gates are reviewed.
