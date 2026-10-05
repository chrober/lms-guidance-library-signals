# Bliss Guidance: Library Signals

`lms-guidance-library-signals` is a passive Lyrion guidance provider plugin in
the **Bliss Guidance** family. It contributes optional play-count, last-played,
and library-age guidance when a compatible Bliss host invokes it. It does not
select music, reorder tracks, or control playback by itself; another plugin
must discover, enable, and use it.

[Better Call Bliss](https://github.com/chrober/lms-better-call-bliss) and
[Bliss Mixer Lab](https://github.com/chrober/lms-blissmixer-lab) discover this
provider through Lyrion's plugin manager. Each host keeps it disabled by
default and can expose host-specific overrides. Provider settings on this page
remain the defaults when a host has no override.

The provider reads only the trusted, read-only `persist.db` resource supplied by
the host and uses the frozen candidate identity artifact supplied for that
invocation.

The provider invokes the native
[`bliss-guidance-library-signals`](https://github.com/chrober/lms-guidance-library-signals)
binary. It reads Lyrion's `persist.db` read-only, uses a frozen candidate
identity artifact supplied by the host, and returns bounded guidance through
the host-neutral
[`bliss-playlist-guidance-spi`](https://github.com/chrober/bliss-playlist-guidance-spi).

## Installation

Install **Bliss Guidance: Library Signals** and its matching native binaries
through [chrober's LMS Plugin Repository](https://github.com/chrober/lms-plugins),
then enable the provider in Lyrion. A compatible host such as Better Call Bliss
or Bliss Mixer Lab discovers it but keeps it disabled until you explicitly
enable it in that host's settings. Installing this provider never installs or
changes a host plugin automatically.

Configure the provider defaults on its own settings page. Hosts inherit those
values unless a host or job explicitly overrides an eligible setting.

The native protocol is owned by
[bliss-playlist-guidance-spi](https://github.com/chrober/bliss-playlist-guidance-spi).
Provider conventions and UI rules are documented in
[lms-bliss-guidance-provider-kit](https://github.com/chrober/lms-bliss-guidance-provider-kit).
