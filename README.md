# numgeo-hardening-soil-bricks

Hardening Soil (Matsuoka-Nakai, Bricks) — a standalone Fortran implementation of the Hardening
Soil model with a Matsuoka–Nakai failure surface and the BRICK small-strain stiffness extension
(Cudny &amp; Truty 2020), extracted from [numgeo](https://www.numgeo.de/) and packaged three ways:
an [incrementalDriver](https://j-machacek.github.io/numgeo-hardening-soil-bricks/components/incremental-driver.html)
build for element tests, a standalone
[calibration tool](https://j-machacek.github.io/numgeo-hardening-soil-bricks/components/calibration.html)
for the internal constants `alpha`/`Hpp`, and a minimal
[UMAT interface](https://j-machacek.github.io/numgeo-hardening-soil-bricks/components/umat.html)
for Abaqus.

**Full documentation:** <https://j-machacek.github.io/numgeo-hardening-soil-bricks/>
*(replace with the actual published URL if this is hosted elsewhere)*

Developed by Jan Machaček, Leonardo José Cocco and Marcin Cudny for numgeo. See
[About &amp; contact](https://j-machacek.github.io/numgeo-hardening-soil-bricks/about.html) in the
documentation for details, credits and how to get in touch.

## Building the documentation locally

The documentation source lives in `docs/` and `zensical.toml` at the repository root, built with
[Zensical](https://pypi.org/project/zensical/):

```bash
pip install zensical
zensical build     # writes ./site/
zensical serve     # or preview locally with live-reload
```

## Building the code

See [Building the code](https://j-machacek.github.io/numgeo-hardening-soil-bricks/building.html)
in the documentation — either the provided Visual Studio projects (`VisualStudio/`) or a plain
`gfortran` command line.
