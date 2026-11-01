# Native binaries

Release packaging places one `bliss-guidance-library-signals` binary per
supported Lyrion platform in this directory. They are built from
[`bliss-guidance-library-signals`](https://github.com/chrober/bliss-guidance-library-signals)
and are intentionally not committed to this plugin repository.

- Native release: `v0.3.2`
- Native commit: `f95b480ae664d4388128afc108cd7f5aee7a504d`

The provider checks the binary's `version --json` metadata before it exposes a
usable native SPI configuration to a host.
