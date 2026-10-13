# Native binaries

Release packaging places one `bliss-guidance-library-signals` binary per
supported Lyrion platform in this directory. They are built from
[`bliss-guidance-library-signals`](https://github.com/chrober/bliss-guidance-library-signals)
and are intentionally not committed to this plugin repository.

- Native release: `v0.3.0`
- Native commit: `487a9e869408ef7ebd0071cbf8e9526f091a6a0e`

The provider checks the binary's `version --json` metadata before it exposes a
usable native SPI configuration to a host.
