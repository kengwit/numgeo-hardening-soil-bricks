# UMAT (Abaqus) interface

<span class="hsb-badge">Abaqus</span>

A minimal Abaqus **UMAT** library for the Hardening-Soil-MN-Bricks model. Deliberately small: two
files of its own (`umat.f90`, `user.for`), plus the same three shared files used by the other two
components, with no dependency on the incremental driver, the calibration tool, or the example
infrastructure beyond that.

## Source & build

| | |
|---|---|
| Source folder | `src/hs-bricks-umat/` (`umat.f90`, `user.for`) + `src/numgeo-hs-bricks/` (shared: `numgeo_hardening_soil_MN_bricks_.f90`, `compatibility_numgeo_.f90`, `precision_.f90`) |
| File to hand to Abaqus | `user.for` |

`user.for` is a thin wrapper that pulls in the other three files via `INCLUDE` statements at
compile time:

```fortran
include './numgeo-hs-bricks/precision_.f90'
include './numgeo-hs-bricks/compatibility_numgeo_.f90'
include './numgeo-hs-bricks/numgeo_hardening_soil_MN_bricks_.f90'
include './umat.f90'
```

so it acts as a small library for all of them — `user.for` is the only file you point Abaqus at.

!!! warning "Copy the folder structure, not just the files"
    Because of the `INCLUDE` paths above, `user.for` only compiles if a subfolder literally named
    `numgeo-hs-bricks` sits right next to it. Copy **both** `umat.f90` and `user.for` from
    `src/hs-bricks-umat/`, **together with the entire `src/numgeo-hs-bricks/` folder**, into the
    directory where you run the Abaqus job — keeping `numgeo-hs-bricks` as a subfolder of that
    directory (do not flatten it):

    ```
    your-abaqus-working-directory/
    ├── user.for
    ├── umat.f90
    └── numgeo-hs-bricks/
        ├── precision_.f90
        ├── compatibility_numgeo_.f90
        └── numgeo_hardening_soil_MN_bricks_.f90
    ```

    Run the job with `abaqus job=... user=user.for ...` (or select `user.for` as the user
    subroutine file in Abaqus/CAE).

## Abaqus compiler settings: free-form Fortran

`user.for`, despite its `.for` extension, is free-form Fortran source (the module it includes
uses long lines and modern syntax) — Abaqus/Intel Fortran must be told to compile it in free-form
mode, otherwise it will not compile correctly. Add the `/free` flag to the Fortran compiler
options in your Abaqus environment file, or add the equivalent compiler directive to the code.

Abaqus reads compiler/linker settings from an environment file named `abaqus_v6.env` (or
`custom_v6.env` for site- or user-specific overrides) in `<solver_install_dir>/<os>/SMA/site/`.
The exact default location depends on your Abaqus version, for example:

| Abaqus version | Typical default location |
|---|---|
| 6.14 (hf4 shown; other hotfixes analogous) | `.../Simulia/Abaqus/6.14-4/SMA/site/abaqus_v6.env` |
| 2016–2019 (2016 shown; other years analogous) | `Program Files/Dassault Systemes/SimulationServices/V6R2016x/win_b64/SMA/site/custom_v6.env` |
| 2020 | `C:/SIMULIA/EstProducts/2020/win_b64/SMA/site/custom_v6.env` |

!!! example "Abaqus 2017 (tested)"
    On Abaqus 2017, the relevant compiler flags are not in `abaqus_v6.env`/`custom_v6.env`
    directly but in `win86_64.env`, in the same directory — add `/free` to the Fortran compiler
    flags there.

    Locations and file names shift between Abaqus versions (and between "system-wide" and
    "site/user override" files); if in doubt, search your installation for `abaqus_v6.env` and
    check the neighbouring `win86_64.env`/`linux86_64.env`.

## Using it in Abaqus

- **Material name (`cmname`)**: `Hardening-Soil-MN-Bricks`, matched as an exact,
  whitespace-delimited token, case-insensitively converted to upper case internally (Abaqus itself
  upper-cases material names before passing them to `UMAT`) — see
  [Model parameters](../parameters.md#model-identifier).
- **`nprops = 16`**, **`*Depvar` = `73`** — see [Model parameters](../parameters.md).
- A worked, complete `*.inp` example (single `CAX4` element, geostatic step followed by a drained
  triaxial compression step) is shipped in `examples/umat/triax-hs-bricks.inp` — see
  [Examples](../examples.md#umat-example).

!!! danger "alpha and Hpp are NOT calibrated automatically here"
    Unlike the [incremental driver](incremental-driver.md), this UMAT interface does **not** fall
    back to calling `optimize_hs_bricks_internal_constants` automatically when `alpha`/`Hpp` are
    zero. If it is called with `props(13) <= 1e-6` and `props(14) <= 1e-6`, it prints a message
    telling you to use the [calibration tool](calibration.md) and **stops the analysis**:

    ```
    Hardening-Soil-MN-Bricks model internal constants alpha and Hpp are zero. We suggest to
    use the small executable numgeo-hs-bricks-calibration also shipped with this code to
    calibrate the parameters beforehand and pass them via the props array
    ```

    **Why:** the calibration is a small Newton iteration that is only meant to run once per
    parameter set. In the incremental driver — a single, serial process — running it once at the
    very first increment is harmless. In Abaqus, `UMAT` is called from every integration point,
    potentially in parallel, with no well-defined single "first call" at which it would be safe
    (or efficient) to silently run an iterative solve. Rather than build in an Abaqus-specific
    workaround (e.g. driving the calibration through `UEXTERNALDB`, or caching the result in a
    state variable), the safer and simpler choice was made: **calibrate once, beforehand**, with
    the [standalone calibration tool](calibration.md) — remember to
    [start it from the command prompt](calibration.md), or the printed result will vanish with
    the closing console window — and pass the resulting `alpha`/`Hpp` in as ordinary, fixed
    material properties.

## Acknowledgements

This UMAT wrapper follows the same interface conventions as the [incremental driver's](incremental-driver.md)
UMAT wrapper, adapted for standalone, dependency-free use. See [About &amp; contact](../about.md)
for full credits.

!!! danger "alpha and Hpp are NOT calibrated automatically here"
    Unlike the [incremental driver](incremental-driver.md), this UMAT interface does **not** fall
    back to calling `optimize_hs_bricks_internal_constants` automatically when `alpha`/`Hpp` are
    zero. If it is called with `props(13) <= 1e-6` and `props(14) <= 1e-6`, it prints a message
    telling you to use the [calibration tool](calibration.md) and **stops the analysis**:

    ```
    Hardening-Soil-MN-Bricks model internal constants alpha and Hpp are zero. We suggest to
    use the small executable numgeo-hs-bricks-calibration also shipped with this code to
    calibrate the parameters beforehand and pass them via the props array
    ```

    **Why:** the calibration is a small Newton iteration that is only meant to run once per
    parameter set. In the incremental driver — a single, serial process — running it once at the
    very first increment is harmless. In Abaqus, `UMAT` is called from every integration point,
    potentially in parallel, with no well-defined single "first call" at which it would be safe
    (or efficient) to silently run an iterative solve. Rather than build in an Abaqus-specific
    workaround (e.g. driving the calibration through `UEXTERNALDB`, or caching the result in a
    state variable), the safer and simpler choice was made: **calibrate once, beforehand**, with
    the [standalone calibration tool](calibration.md) — remember to
    [start it from the command prompt](calibration.md), or the printed result will vanish with
    the closing console window — and pass the resulting `alpha`/`Hpp` in as ordinary, fixed
    material properties.

## Acknowledgements

This UMAT wrapper follows the same interface conventions as the [incremental driver's](incremental-driver.md)
UMAT wrapper, adapted for standalone, dependency-free use. See [About &amp; contact](../about.md)
for full credits.
