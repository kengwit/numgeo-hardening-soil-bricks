# Components

Three self-contained programs are shipped, each built from the same constitutive module
(`numgeo_hardening_soil_MN_bricks_.f90`) plus the small compatibility layer
(`compatibility_numgeo_.f90`, `precision_.f90`) it depends on. Nothing in the constitutive model
differs between them — only the surrounding code that calls it does.

| Component | Purpose | Source folder | Built by |
|-----------|---------|----------------|----------|
| [Incremental driver](incremental-driver.md) | Single-element simulations (oedometer, triaxial, ...) | `src/incremental-driver/` + shared `src/numgeo-hs-bricks/` | `VisualStudio/IncrementalDriver/` |
| [Calibration tool](calibration.md) | Calibrates the internal constants `alpha` and `Hpp` | `src/numgeo-hs-bricks-calibration/` + shared `src/numgeo-hs-bricks/` | `VisualStudio/numgeo-hs-bricks-calibration/` |
| [UMAT (Abaqus) interface](umat.md) | Plugs the model into an Abaqus user-material build | `src/hs-bricks-umat/` + shared `src/numgeo-hs-bricks/` | Abaqus itself (`abaqus job=... user=user.for`); see the [UMAT page](umat.md) for the required compiler setting |

All three read/write the same 16-entry `props` array and 73-entry `statev` array — see
[Model parameters](../parameters.md) for the full layout, which applies identically to all three
components below.

<div class="hsb-grid" markdown>

<div class="hsb-card" markdown>
### :material-play-box-outline: Incremental driver
A ready-to-use build of A. Niemunis' **incrementalDriver**: reads a material name, parameters and
initial conditions from plain-text input files and drives a single element through a prescribed
loading path — the quickest way to check a parameter set or reproduce a laboratory test. <br>
[:octicons-arrow-right-16: Details](incremental-driver.md)
</div>

<div class="hsb-card" markdown>
### :material-tune-variant: Calibration tool
`alpha` and `Hpp` are internal cap constants, not free physical parameters. This tool runs the
model's own virtual-oedometer calibration once and prints the result — most useful when preparing
a parameter set for Abaqus, where the UMAT interface cannot calibrate them on the fly. <br>
[:octicons-arrow-right-16: Details](calibration.md)
</div>

<div class="hsb-card" markdown>
### :material-cube-outline: UMAT (Abaqus) interface
A minimal `subroutine umat(...)` implementing the standard Abaqus user-material interface, with
no dependency on the driver or example infrastructure — copy it straight into an Abaqus job
directory. <br>
[:octicons-arrow-right-16: Details](umat.md)
</div>

</div>

!!! tip "Building"
    The incremental driver and the calibration tool ship with ready-to-use Visual Studio project
    files — see [Building the code](../building.md). The UMAT interface is built by Abaqus itself
    as part of a job, not with a separate Visual Studio project — see the
    [UMAT page](umat.md) for the (one-off) compiler setting it needs.
