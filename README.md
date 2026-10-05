# Bliss Guidance: Library Signals

`lms-guidance-library-signals` is a Lyrion provider plugin in the **Bliss
Guidance** family. It contributes optional play-count, last-played, and
library-age guidance; it is not a host and does not select music by itself.

Better Call Bliss 0.22.0 and Bliss Mixer Lab 0.10.0 discover this enabled plugin
through Lyrion's plugin manager. Each host keeps the provider disabled by
default and can expose host-specific overrides. Provider settings on this page
remain the defaults when a host has no override.

The current Lyrion provider release is 0.2.1. The native provider path is
shipped and reads only the trusted, read-only `persist.db` resource supplied by
the host; APC remains a separate future provider.

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
