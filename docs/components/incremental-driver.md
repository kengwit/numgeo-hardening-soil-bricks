# Incremental driver

<span class="hsb-badge">Element tests</span>

A single-element test driver is the fastest way to check a parameter set, reproduce a laboratory
test, or explore the model's response before committing to a full boundary-value analysis. This
repository ships a ready-to-use build of the **incrementalDriver** by **A. Niemunis** — a
widely-used, UMAT-based driver for exactly this purpose — wired up to call the
Hardening-Soil-MN-Bricks model.

!!! info "Credit"
    The incremental driver itself (`incrementalDriver.f`) is the well-known driver by
    **A. Niemunis**; it is unmodified and is fully model-agnostic. Only the UMAT wrapper
    (`material_models.f90`) that dispatches to the Hardening-Soil-MN-Bricks constitutive routine
    is specific to this repository.

## What it does

The driver reads three plain-text input files, sets up a single integration point at the
prescribed initial stress, and steps it through a prescribed strain- or stress-controlled loading
path, calling the UMAT interface at every increment. Results (strains, stresses and state
variables at every increment) are written to a single output file.

## Source & build

| | |
|---|---|
| Source folder | `src/numgeo-hs-bricks/` |
| Files | `incrementalDriver.f` (Niemunis driver, unmodified) · `material_models.f90` (UMAT wrapper) · `numgeo_hardening_soil_MN_bricks_.f90` · `compatibility_numgeo_.f90` · `precision_.f90` |
| Visual Studio project | `VisualStudio/IncrementalDriver/` |
| Executable | `IncrementalDriver.exe` |

See [Building the code](../building.md) for compiling it yourself.

## Input files

The driver expects three files with fixed names in its working directory:

`parameters.inp`
:   The material name, `nprops`, and the 16 parameter values — see
    [Model parameters](../parameters.md). Example (glacial till, Cudny &amp; Truty 2020, Eq. 44):

    ```
        Hardening-Soil-MN-Bricks     cmname
        16           nprops
        8.5d3        E50
        6.15d3       Eoed
        25.75d3      Eur
        0.7          m
        6            c
        28           phi
        6            psi
        0.29         nu
        100          pref
        0.8          K0nc
        0.9          Rf
        15.46d3      Eiref
        0.515        alpha
        9.866d3      Hpp
        3d-4         gamma_07
        60d3         G0
    ```

`initialconditions.inp`
:   `ntens`, the initial stress state, and `nstatv` (must be `73`):

    ```
     6        ntens
     -100     stress(1)
     -100     stress(2)
     -100     stress(3)
      0       stress(4)
      0       stress(5)
      0       stress(ntens)
      73      nstatv    number of state variables
    ```

`test.inp`
:   The output filename and the loading path, using the driver's own step syntax. Example — a
    drained triaxial compression test (`*TriaxialE1`), 5000 increments, target axial strain
    $-25\,\%$, radial stress held constant:

    ```
    output_CD.out
    *TriaxialE1
    5000 100 1
    -0.25
    *END
    ```

!!! note "Both `alpha`/`Hpp` and gamma07/G0 must be supplied"
    Unlike some numgeo workflows, the incremental driver does **not** run the internal
    calibration automatically unless `alpha` and `Hpp` are both left at `0` in `parameters.inp` —
    in that case `material_models.f90` calls `optimize_hs_bricks_internal_constants` once, at the
    first increment, and prints the calibrated values to the console (see
    [Model parameters](../parameters.md#the-internal-constants-alpha-and-hpp)).

## Running it

Run `IncrementalDriver.exe` from a directory containing the three input files above (see
[Examples](../examples.md) for the exact, ready-to-run example shipped in this repository). The
driver writes its results to the output file named on the first line of `test.inp` (`output_CD.out`
in the example above): one row per increment, with strain, stress and all state-variable values.

For BRICK-specific behaviour, the two columns of interest are `statev(6)` (`Gm`, the running
small-strain stiffness ratio) and `statev(7)` (`n_bricks`, the number of currently active bricks)
— see [Model parameters](../parameters.md#state-variables-statev).
