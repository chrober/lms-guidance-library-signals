# Artist and album listening-history guidance

Status: **implementation in progress**, 11 November 2026. The native provider,
provider settings and both hosts have local, uncommitted aggregate-signal
changes. They have not been released or deployed. Better Call Bliss's separate
repeat-identity default alignment is already implemented, as noted below.

Implementation is in progress across the native provider, the shared guidance
host, the optimizer, Lab and this plugin; it is not ready for deployment. Lab
currently gives its native guidance session 500 ms. On a synthetic 200,000-track
in-memory catalogue, a local debug build took about 785 ms to aggregate the
whole catalogue and 48 ms for the groups of 20 candidates, excluding process
startup. The native prototype uses candidate-scoped aggregation, and its
percentile distribution is over candidate-represented groups for all pool
sizes. Large group sets fall back to scanning the catalogue while retaining
that same distribution. This is not a Raspberry Pi benchmark and the complete
DSTM session still needs measurement. The native provider and optimizer test
suites and selected Perl host tests pass, including isolated Perl tests on the
Pi. An ARM64 native provider test against 20 tracks sampled across that Pi's
actual library completed in approximately 331 ms using Lyrion history and
368 ms using APC. This is a read-only provider session, not a live DSTM result;
other candidate distributions and concurrent load may take longer.
The native prototype can group exact Bliss credits using read-only Bliss and
host identity-snapshot databases, with Better Call Bliss passing its existing
snapshot. The exact-credit implementation currently scans the catalogue: on
the same local synthetic 200,000-track fixture it initially took 1.36 seconds
in a release build for 20 candidate tracks. A revised join measured about
365 ms to 1.12 s across local release-build runs before the latest selective
join. For a 20-candidate fixture with 200,000 tracks, the selective join
subsequently measured 330 ms locally. These timings exclude process startup
and hash verification, and are not Pi measurements. Consequently it is deliberately neutral
for hosts with a real-time budget, including Lab, and warns instead of blocking
or silently using another identity. Further performance work, broader Pi
timing and live end-to-end verification remain open.
On the same Pi, a read-only exact-credit session for 20 sampled tracks took
about 3.5 seconds, and computing the 59.5 MiB identity snapshot's hash took
another 1.2 seconds. Exact-credit aggregation is therefore not suitable for
Lab's current 500 ms budget without a different reuse/validation approach.
Exact-credit album aggregation also falls back to a filtered catalogue scan
when the selected albums exceed the safe SQLite parameter batch size; a
regression test covers this with an artificially reduced SQLite limit.
If multiple Bliss files map to one Lyrion track with conflicting normalized
credits, its artist identity and contribution remain unknown; its album
history remains usable. Matching credits contribute the track only once.

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

Bliss Mixer Lab owns a repeat-identity setting with shared artist, primary
artist and exact Bliss credit choices. Better Call Bliss retains its own
setting and per-job control. Since Better Call Bliss 0.22.16, its default is
**Follow Bliss Mixer Lab**: when Lab is enabled, the effective mode is read
from Lab when job defaults are prepared; when Lab is unavailable or its value
is missing or invalid, the effective mode falls back to **Any shared artist**.
An explicit Better Call Bliss setting or per-job choice can override the
default. A one-time migration switches the existing Better Call Bliss setting
to follow Lab, including previously explicit settings; choices made after that
migration are preserved. Saved Extras profiles and previous jobs remain
separate from this setting.

This is a repeat-window policy. The in-progress Library Signals implementation
resolves its separate aggregation policy as follows:

- Library Signals has its own identity setting. Its default is **Follow Bliss
  Mixer Lab** when Lab is available; users may explicitly select another policy.
- Show **Follow Bliss Mixer Lab** only while Lab is installed and enabled. If a
  saved follow preference later becomes unavailable, retain that preference,
  use **Any shared artist** as the effective fallback, and resume following Lab
  when it becomes available again. Show the effective source and fallback.
- Without Lab, the common default is **Any shared artist**. Explicit host,
  provider and per-run overrides may intentionally produce different effective
  settings; only the default is shared.

The provider remains host-neutral and works without either host. The common
default and preference resolution do not require Lab. Exact Bliss credit uses
trusted Bliss and identity-snapshot inputs when available; it is deliberately
not applied to Lab's time-limited real-time selection until a sufficiently fast
path has been verified. The provider warns and leaves artist guidance neutral
instead of silently substituting another identity. Album and track signals
remain available. Collaborations, missing identities, compilation attribution
and partial coverage must remain explicit in results and diagnostics.

The Better Call Bliss implementation and regression coverage are in
[`Defaults.pm`](https://github.com/chrober/lms-better-call-bliss/blob/main/BetterCallBliss/Defaults.pm),
[`JobOptions.pm`](https://github.com/chrober/lms-better-call-bliss/blob/main/BetterCallBliss/JobOptions.pm),
[`artist_identity_migration.t`](https://github.com/chrober/lms-better-call-bliss/blob/main/tests/artist_identity_migration.t)
and [`job_options.t`](https://github.com/chrober/lms-better-call-bliss/blob/main/tests/job_options.t).
The exact-credit path checks the host identity snapshot's hash before use;
inheriting the same default does not require provider and host overrides to
match. Real-time snapshot reuse and performance still require verification.

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

The prototype ranks summed plays against the groups represented in the frozen
candidate inventory; it does not divide by album size. Last-played signals use
the existing saturation horizon. Partial groups reduce confidence in proportion
to known track values. Reported totals remain actual sums of supplied track
values, not estimates of independent listening events.
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
- Lab available, absent, disabled and re-enabled: verify the proposed provider
  follow option's visibility, saved preference and fallback, plus provider and
  host overrides. Verify defaults do not drift; retain regression coverage for
  the already implemented Better Call Bliss migration and fallback.
- Each signed influence independently supports negative, zero and positive;
  combinations are bounded and missing signals do not manufacture evidence.
  Existing settings with new influences disabled preserve prior behaviour.
- Both hosts receive and display provider settings through the shared host UI,
  respect their overrides and hard repeat rules, and expose truthful guidance
  provenance. Existing Lab log formats are regression-tested.
- Test large libraries, partial data, library rescan and changed listening
  history; measure end-to-end resource use on a Raspberry Pi as well as native
  unit, integration and host contract tests.
