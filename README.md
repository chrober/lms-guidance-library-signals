# Bliss Guidance: Library Signals

`lms-guidance-library-signals` is a Lyrion provider plugin in the **Bliss
Guidance** family. It contributes optional play-count, last-played, and
library-age guidance; it is not a host and does not select music by itself.

Compatible hosts discover this enabled plugin through Lyrion's plugin manager.
Each host keeps the provider disabled by default and can expose host-specific
overrides. Provider settings on this page remain the defaults when a host has
no override.

The provider invokes the native
[`bliss-guidance-library-signals`](https://github.com/chrober/bliss-guidance-library-signals)
binary. It reads Lyrion's `persist.db` read-only, uses a frozen candidate
identity artifact supplied by the host, and returns bounded guidance through
the host-neutral
[`bliss-playlist-guidance-spi`](https://github.com/chrober/bliss-playlist-guidance-spi).

## Installation

Install this plugin and the matching native binaries through the Lyrion
extension repository. Enable the plugin, then explicitly enable it in a
compatible host such as Better Call Bliss. Installing this provider never
installs or changes a host plugin automatically.
