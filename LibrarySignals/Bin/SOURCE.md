# Native binaries

Release packaging places one `bliss-guidance-library-signals` binary per
supported Lyrion platform in this directory. They are built from
[`bliss-guidance-library-signals`](https://github.com/chrober/bliss-guidance-library-signals)
and are intentionally not committed to this plugin repository.

- Native release: `v0.3.3`
- Native commit: `62bdf1326b427d7a2b7fb6b9589f9dfcb9431284`

The provider checks the binary's `version --json` metadata before it exposes a
usable native SPI configuration to a host.
