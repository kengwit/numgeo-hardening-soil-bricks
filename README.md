![numgeoACT](./docs/assets/numgeo-logo.png)

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

Developed by Jan Machaček, Leonardo José Cocco and Marcin Cudny for numgeo. See
[About &amp; contact](https://j-machacek.github.io/numgeo-hardening-soil-bricks/about.html) in the
documentation for details, credits and how to get in touch.