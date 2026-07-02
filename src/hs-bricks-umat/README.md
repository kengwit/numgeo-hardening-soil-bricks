# Hardening-Soil-MN-Bricks — minimal UMAT library

A minimal, self-contained Abaqus **UMAT** library for the Hardening-Soil-MN-Bricks model (Hardening
Soil with a Matsuoka–Nakai failure surface and the BRICK small-strain stiffness extension of
Cudny & Truty). This folder is deliberately small: it contains only the four files needed to
compile the model into a UMAT build, with no test driver, no example, and no calibration tool
attached.

If you want the full picture — theory, a worked triaxial example run through the
`incrementalDriver`, and a standalone calibration tool for `alpha`/`Hpp` — see the
[`numgeo-hardening-soil`](../numgeo-hardening-soil) repository instead, which this library is
extracted from. The constitutive module and compatibility layer in this folder are byte-for-byte
the same files as there.


## Contents

| File                                       | Purpose                                                                 |
|---------------------------------------------|--------------------------------------------------------------------------|
| `precision_.f90`                            | Numerical kinds (`rk`, `ik`) used throughout.                            |
| `compatibility_numgeo_.f90`                 | Stress-invariant and matrix-inversion helpers required by the model.     |
| `numgeo_hardening_soil_MN_bricks_.f90`      | The constitutive model itself (module `material_hardening_soil_MN_bricks_`), unmodified numgeo source. |
| `umat_hardening_soil_MN_bricks_.f90`        | The `subroutine umat(...)` that Abaqus (or any other UMAT-calling host) links against. |

No file in this folder depends on anything outside these four; there is nothing else to fetch.


## Building

```bash
gfortran -c -fdec-math -ffree-line-length-none \
  precision_.f90 compatibility_numgeo_.f90 numgeo_hardening_soil_MN_bricks_.f90 \
  umat_hardening_soil_MN_bricks_.f90
```

`-fdec-math` is required for the DEC-style double-precision intrinsics (`dsqrt`, `dabs`, `dexp`,
`dlog`, `dcos`, `dsin`, `dtan`, `dacos`) used throughout the constitutive routines. Link the four
resulting object files into your UMAT build together with your host solver (e.g. supply them as
the Abaqus `user=` subroutine source/objects).


## Using the model

- **Material name (`cmname`)**: `Hardening-Soil-MN-Bricks`, matched by `umat_hardening_soil_MN_bricks_.f90` as an exact, whitespace-delimited token (not a substring search — see the history note in that file for why).
- **`nprops = 16`**, **`nstatev = 73`**. `umat` stops with a diagnostic message if either is wrong.
- Parameter order, the meaning of every `props`/`statev` entry, the sign/Voigt convention, and the calibration of the internal cap constants `alpha`/`Hpp` are all documented in the [`numgeo-hardening-soil` README](../numgeo-hardening-soil/README.md) — that documentation is not repeated here to avoid the two copies drifting apart; this library uses the identical model, parameter order and state-variable layout.
- `alpha` (`props(13)`) and `Hpp` (`props(14)`) are internal calibration constants, not independent physical inputs. `umat` calls `optimize_hs_bricks_internal_constants` automatically on the first increment if both are `<= 1e-6`; alternatively, calibrate them once beforehand with the standalone tool in `numgeo-hardening-soil/tools/calibrate_hs_bricks.f90`.


## Acknowledgements and references

See the [`numgeo-hardening-soil` README](../numgeo-hardening-soil/README.md) for full credits (L. J. Cocco for the base Hardening Soil implementation, M. Cudny for the BRICK subroutines) and the reference list [1]–[6].
