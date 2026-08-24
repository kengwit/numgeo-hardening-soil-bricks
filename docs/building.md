# Building the code

Ready-to-use **Visual Studio** projects are provided for the incremental driver and the
calibration tool, so you can get started without setting up a build system by hand. The UMAT
interface is built by Abaqus itself as part of a job rather than with a separate project — see
[UMAT (Abaqus) interface](components/umat.md) for the one compiler setting it needs. A portable
`gfortran` command line is also given for every component, for Linux/macOS or if you simply
prefer the command line.

---

## Visual Studio projects

```
VisualStudio/
├── IncrementalDriver/               → example/driver.exe  (console application)
└── numgeo-hs-bricks-calibration/    → numgeo-hs-bricks-calibration.exe  (console application)
```

Each folder contains an Intel Fortran project (`.vfproj`) and solution (`.sln`) file. Open the
`.sln` file of the component you want in Visual Studio (with the **Intel Fortran** integration
installed — `ifort` for the Win32 configurations, `ifx` for x64), select **Debug** or **Release**
and **x64** (recommended) or **Win32**, and build.

Each project's `Source Files` filter lists exactly the files given in that component's page under
[Components](components/index.md) — nothing is hidden or auto-generated beyond the usual `.mod`/`.obj`
intermediates.

---

## Command-line build (gfortran)

Every component can equally be built with a plain `gfortran` invocation — useful on Linux/macOS,
or for scripted/CI builds. The legacy incremental-driver build retains `-fdec-math`. The shared
constitutive source and the calibration utility are standard-conforming Fortran 2008 and are also
checked with the standard 132-character free-form line limit.

=== "Incremental driver"

    ```bash
    gfortran -fdec-math -ffree-line-length-none -O2 \
      src/numgeo-hs-bricks/precision_.f90 \
      src/numgeo-hs-bricks/compatibility_numgeo_.f90 \
      src/numgeo-hs-bricks/numgeo_hardening_soil_MN_bricks_.f90 \
      src/incremental-driver/material_models.f90 \
      src/incremental-driver/incrementalDriver.f \
      -o IncrementalDriver
    ```

=== "Calibration tool"

    ```bash
    gfortran -std=f2008 -ffree-line-length-132 -Werror=line-truncation -O2 \
      src/numgeo-hs-bricks/precision_.f90 \
      src/numgeo-hs-bricks/compatibility_numgeo_.f90 \
      src/numgeo-hs-bricks/numgeo_hardening_soil_MN_bricks_.f90 \
      src/numgeo-hs-bricks-calibration/calibrate_hs_bricks.f90 \
      -o numgeo-hs-bricks-calibration
    ```


=== "Calibration regression test"

    ```bash
    gfortran -std=f2008 -ffree-line-length-132 -Werror=line-truncation -O2 \
      src/numgeo-hs-bricks/precision_.f90 \
      src/numgeo-hs-bricks/compatibility_numgeo_.f90 \
      src/numgeo-hs-bricks/numgeo_hardening_soil_MN_bricks_.f90 \
      tests/test_calibration_optimizer.f90 \
      -o test_calibration_optimizer

    ./test_calibration_optimizer
    ```

    The test checks two parameter sets, positive calibrated constants, monotonic decrease of the
    accepted-iterate merit function, convergence to the specified tolerance, and identical results
    with and without convergence-history output.

=== "UMAT (shared library)"

    ```bash
    gfortran -fdec-math -ffree-line-length-none -O2 -shared -fPIC \
      src/numgeo-hs-bricks/precision_.f90 \
      src/numgeo-hs-bricks/compatibility_numgeo_.f90 \
      src/numgeo-hs-bricks/numgeo_hardening_soil_MN_bricks_.f90 \
      src/hs-bricks-umat/umat.f90 \
      -o umat.so
    ```

    This is only useful for testing the UMAT logic standalone. For actual Abaqus use, do **not**
    build it this way — hand Abaqus `src/hs-bricks-umat/user.for` directly (with the `/free`
    compiler setting and folder layout described on the
    [UMAT (Abaqus) interface](components/umat.md) page) and let Abaqus's own build step compile
    it as part of the job.

!!! note "Compile order matters"
    In every case, `precision_.f90` must be compiled before `compatibility_numgeo_.f90`, which
    must be compiled before `numgeo_hardening_soil_MN_bricks_.f90` — each depends on the modules
    defined in the previous file. The application/driver file is always compiled last.
