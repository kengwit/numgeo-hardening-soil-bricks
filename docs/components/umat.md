# UMAT (Abaqus) interface

<span class="hsb-badge">Abaqus</span>

A minimal, self-contained Abaqus **UMAT** library for the Hardening-Soil-MN-Bricks model.
Deliberately small: just the four files needed to compile the model into a UMAT build, with no
dependency on the incremental driver, the calibration tool, or the example infrastructure.

## Source & build

| | |
|---|---|
| Source folder | `src/hs-bricks-umat/` |
| Files | `umat_hardening_soil_MN_bricks_.f90` (the `subroutine umat(...)`) · `numgeo_hardening_soil_MN_bricks_.f90` · `compatibility_numgeo_.f90` · `precision_.f90` |
| Visual Studio project | `VisualStudio/umat/` (builds a dynamic library) |
| Output | `umat.dll` |

No file in this folder depends on anything outside these four — it can be dropped into any
UMAT-based build on its own. See [Building the code](../building.md) for compiling it yourself.

## Using it in Abaqus

- **Material name (`cmname`)**: `Hardening-Soil-MN-Bricks`, matched as an exact, whitespace-delimited
  token — see [Model parameters](../parameters.md#model-identifier).
- **`nprops = 16`**, **`ndepvar = 73`** (Abaqus' `*DEPVAR`) — see
  [Model parameters](../parameters.md).
- Compile `umat_hardening_soil_MN_bricks_.f90`, `numgeo_hardening_soil_MN_bricks_.f90`,
  `compatibility_numgeo_.f90` and `precision_.f90` together as your Abaqus user subroutine (e.g.
  `abaqus job=... user=umat_hardening_soil_MN_bricks_.f90 ...`, or link the pre-built `umat.dll`
  depending on your Abaqus/compiler setup).

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
