# Artist and album listening-history guidance

Status: **proposed design**, 10 November 2026. The existing provider supplies
track-level signals; the aggregate signals and shared defaults described here
are not yet implemented. This document records intended behaviour and the
remaining decisions, not a change to the released plugins.

## Purpose and boundaries

Extend Library Signals with preferences based on listening to a candidate's
album and artist, alongside the existing track play-count and last-played
preferences. These are passive, optional signals for tracks already admitted
by a Bliss host. They do not introduce candidates, override repeat windows,
select a particular album edition, or guarantee a result.

Lyrion or Alternative Play Count (APC) remains the authority for track listening
values. The provider reads and aggregates values supplied by the selected
source; it does not reconcile duplicate recordings, infer independent listening
events, or repair synchronized counters. Recording-level identity, MBID-based
history and any changes to APC or Lyrion are separate future investigations.
No recording-grouping setting is planned in Library Signals.

## Signals

| Level | Play-count signal | Last-played signal |
| --- | --- | --- |
| Track | Source's count for the track | Source's last-played value for the track |
| Album | Sum of the source's counts for the album's tracks | Most recent known last-played value among the album's tracks |
| Artist | Sum of the source's counts for tracks attributed to the artist under the chosen identity policy | Most recent known last-played value among those tracks |

An album or artist count is a **sum of track plays**, not a count of complete
album or artist listening sessions. Every source track contributes at most once
to an individual aggregate, even when it has multiple matching contributor
roles. A collaborative track may legitimately contribute to more than one
artist's aggregate. The provider does not sum Lyrion and APC together.

Where APC synchronizes counters between copies, their sums can reflect those
synchronized values rather than independent playback events; the provider
must not present the total as a deduplicated event count. Similarly, if
synchronization changes individual last-played values, album attribution is
limited by what the selected source can actually distinguish. The UI and
diagnostics should identify the source and avoid claiming otherwise.

MBIDs are optional. Library grouping must also work with Lyrion track, album
and contributor identities when no MBIDs exist. A missing value is not
automatically a confirmed zero or proof that a recording has never been heard.
Partial aggregate coverage must be visible in diagnostics; decide how a partial
aggregate affects confidence before implementation. No ambiguous title-based
recording matching is permitted.

## Artist identity and defaults

Bliss Mixer Lab already owns a repeat-identity setting with shared artist,
primary artist and exact Bliss credit choices. Better Call Bliss currently has
its own setting and per-run control. The intended default alignment is:

- Lab supplies the default repeat identity when installed and enabled.
- Better Call Bliss follows Lab by default, while preserving a per-run override.
  It must also work independently when Lab is absent or disabled.
- Library Signals has its own identity setting. Its default is **Follow Bliss
  Mixer Lab** when Lab is available; users may explicitly select another policy.
- Show **Follow Bliss Mixer Lab** only while Lab is installed and enabled. If a
  saved follow preference later becomes unavailable, retain that preference,
  use **Any shared artist** as the effective fallback, and resume following Lab
  when it becomes available again. Show the effective source and fallback.
- Without Lab, the common default is **Any shared artist**. Explicit host,
  provider and per-run overrides may intentionally produce different effective
  settings; only the default is shared.

The provider must remain host-neutral and work without either host. Define and
test the common default and preference resolution without a hard dependency on
Lab. Check whether exact Bliss credit is implementable from the trusted inputs
available to the provider; do not expose an option that cannot be honoured.
Explicitly define identity resolution for collaborations, missing contributors
and compilations, and show unresolved or partial identities in diagnostics.

For the separate repeat-identity cleanup, the owner approved a one-time
migration of existing Better Call Bliss installations to follow Lab; subsequent
explicit choices must be preserved. Saved Extras profiles and previous jobs
remain separate from this setting. Define how the provider's own identity
snapshot stays consistent for the duration of a job.

## Influence and combination

Provide separate signed influence controls for track, album and artist for
each of the two signal families. Negative play-count influence favours lower
counts; negative last-played influence favours longer-unheard music. Positive
values favour the opposite; zero disables that level. These are strengths, not
target percentages of selected tracks. Library age remains an independent
existing signal.

Avoid a second set of ratio controls: the six signed influence values also
express their relative weight within their family. A track/album/artist balance
such as 60/30/10 is an illustration, not a required sum, hard-coded hierarchy or
an instruction to replace existing values. Users can favour any level. Current
provider defaults are zero; new controls must not silently activate guidance or
change existing users' behaviour. New-user defaults and the exact migration
need a deliberate compatibility decision.

Combine the enabled levels into one **bounded contribution per signal
family**, rather than multiplying three unrestricted boosts. One candidate for
the combination rule is:

```text
combined = sum(normalized_signal_i * signed_influence_i)
           / max(1, sum(abs(signed_influence_i)))
```

Here each available signal is normalized to [-1, 1], influences are in [-1, 1],
and the sign convention must be defined consistently with the existing
provider. Omit disabled and unknown components rather than converting unknown
to zero plays. A single 20% influence must remain weaker than a single 80%
influence; enabling multiple levels must not produce an unbounded contribution.
This bound does **not** deduplicate a listening event reflected in several
signals. Verify the mapping to the hosts' actual scoring and preserve the
existing track-only result when the added controls are disabled; the formula
is a proposal until those compatibility tests establish the details.

Choose and document normalization for raw aggregate counts, including whether
and how to account for catalogue and album size. This affects ranking only;
reported totals remain actual sums of supplied track values. Apply configurable
last-played saturation consistently and define the horizons for the new levels.
Counts, source, coverage, timestamps, normalized signals and bounded
contribution should be available to host diagnostics without changing existing
Lab log formatting unexpectedly.

## Integration and performance

The provider plugin owns settings, source selection and trusted resources; the
native Library Signals provider owns efficient read-only access, aggregates and
structured signals. The shared SPI and host integration must be reviewed for
any additional channels, policy fields, trace information and trusted library
resources. Better Call Bliss and Lab remain responsible for their own
selection, repeat rules and established output formats.

Aggregate using stable Lyrion identities and batch queries or appropriately
invalidated caches; do not scan the full library for every candidate. Define
library versus virtual-library scope, behaviour during scans, snapshot
consistency, cache invalidation after listening or library changes, and
performance budgets before implementation. Keep missing values neutral and
provider failures isolated; do not block audio playback or the server UI.

## Acceptance scenarios

- Lyrion-only installation, optional APC source, APC missing records and an
  unavailable APC plugin behave according to source selection and provenance.
- Albums and artists with known, zero, missing and partially known values
  produce truthful counts, timestamps and coverage; repeated contributor roles
  do not double-count a track within one aggregate.
- MBID-free libraries work; synchronized APC counters are not described as
  deduplicated playback events. No recording grouping or automatic cross-copy
  inference is performed by this provider.
- Lab available, absent, disabled and re-enabled: follow option visibility,
  saved preference, fallback, provider/host overrides and migration are correct
  and defaults do not drift.
- Each signed influence independently supports negative, zero and positive;
  combinations are bounded and missing signals do not manufacture evidence.
  Existing settings with new influences disabled preserve prior behaviour.
- Both hosts receive and display provider settings through the shared host UI,
  respect their overrides and hard repeat rules, and expose truthful guidance
  provenance. Existing Lab log formats are regression-tested.
- Test large libraries, partial data, library rescan and changed listening
  history; measure end-to-end resource use on a Raspberry Pi as well as native
  unit, integration and host contract tests.
