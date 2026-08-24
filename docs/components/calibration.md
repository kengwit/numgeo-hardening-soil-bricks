# Calibration tool

<span class="hsb-badge">alpha &amp; Hpp</span>

`alpha` and `Hpp` (`props(13)`/`props(14)`) are not independent physical soil parameters — they
are internal cap constants, calibrated so the model reproduces the prescribed `Eoed` and `K0nc`
under oedometric loading (see [Model parameters](../parameters.md#the-internal-constants-alpha-and-hpp)).
This tool has exactly **one task**: read a parameter file, run that calibration, and print `alpha`
and `Hpp` back to you. In addition, it writes the accepted-iterate convergence history to
`hs_internal_constants_convergence.csv` for reproducibility and diagnostic plots.

It is especially useful when preparing a parameter set for **Abaqus**: the
[UMAT interface](umat.md) deliberately does *not* calibrate `alpha`/`Hpp` automatically (see that
page for why), so calibrating them once, beforehand, with this tool is the recommended workflow.

!!! danger "Start it from the command prompt"
    This is a console application. If you **double-click** `numgeo-hs-bricks-calibration.exe` in
    Windows Explorer, it will run, print the calibrated `alpha` and `Hpp` — and then the console
    window closes immediately, before you have a chance to read them. Always start it from a
    command prompt (`cmd.exe` or PowerShell) instead:

    ```
    cd path\to\examples\Calibration
    numgeo-hs-bricks-calibration.exe
    ```

    The window then stays open after the program finishes, so the printed values remain visible.

## What it does

The tool prompts, interactively, for the path to a parameter file, reads `props(1:16)` from it,
runs `optimize_hs_bricks_internal_constants`, and prints the resulting `alpha` and `Hpp` to the
screen. It also writes `hs_internal_constants_convergence.csv` in the current working directory.
It does **not** modify the input file — copy the printed values into `props(13)`/`props(14)` of your
real parameter file (or Abaqus material card) by hand.

The nonlinear system is solved with a globalised Newton method. The two residual equations are
scaled by their target values, while the unknowns are represented by logarithmic, dimensionless
variables. This guarantees `alpha > 0` and `Hpp > 0` and avoids poor conditioning caused by their
different numerical magnitudes. A central-difference Jacobian, an Armijo backtracking line search,
a bounded logarithmic step, and a steepest-descent fallback are used. Only accepted iterates are
written; the output is not a running-best or otherwise filtered history.

The convergence file contains one row for the initial guess (`iteration = 0`) and one row after
each accepted update. Its columns are

```text
iteration,residual_Eoed,residual_K0,relative_error_Eoed,relative_error_K0,
error_measure,tolerance,alpha,Hpp,merit_function,step_length,backtracks
```

The signed residuals are

$$
r_E=E_{\mathrm{oed}}^{\mathrm{ref}}-E_{\mathrm{oed}}^{\mathrm{sim}},
\qquad
r_K=K_0^{\mathrm{nc}}-K_0^{\mathrm{sim}},
$$

and

$$
e=\max\!\left(
\frac{|r_E|}{E_{\mathrm{oed}}^{\mathrm{ref}}},
\frac{|r_K|}{K_0^{\mathrm{nc}}}
\right),
\qquad
\Phi=\frac{1}{2}\left[
\left(\frac{r_E}{E_{\mathrm{oed}}^{\mathrm{ref}}}\right)^2+
\left(\frac{r_K}{K_0^{\mathrm{nc}}}\right)^2
\right].
$$

`error_measure` is $e$, whereas `merit_function` is $\Phi$. The iteration stops when both relative
residuals are at most `1.0e-6`. The history can be plotted with

```bash
python scripts/plot_hs_internal_optimization_history.py \
  hs_internal_constants_convergence.csv \
  --output-prefix hs_internal_constants_convergence
```

---

## Source & build

| | |
|---|---|
| Source folder | `src/numgeo-hs-bricks-calibration/` (`calibrate_hs_bricks.f90`) + `src/numgeo-hs-bricks/` (shared: `numgeo_hardening_soil_MN_bricks_.f90`, `compatibility_numgeo_.f90`, `precision_.f90`) |
| Visual Studio project | `VisualStudio/numgeo-hs-bricks-calibration/` — open the `.sln` and build; no manual compiler setup needed |
| Executable | `numgeo-hs-bricks-calibration.exe` |

See [Building the code](../building.md) if you want to build it yourself with this Visual Studio
project (or with `gfortran`), or use the ready-built executable in `examples/Calibration/`
directly (see [Examples](../examples.md#calibration-example)) — just remember it must be started
from the command prompt, not double-clicked (see the warning above).

---

## Input file format

The expected file uses exactly the format of `parameters.inp` (see
[Incremental driver](incremental-driver.md#input-files)): a material-name line, `nprops` (must be
`16`), then one value per line. `alpha`/`Hpp` may be anything — `0` is conventional — since they
are overwritten by the calibration; `gamma07`/`G0` (parameters 15/16) must still be valid, even
though they do not influence the calibrated result, because the model's own parameter validation
runs before the calibration.

---

## Example session

Using the parameter file shipped in `examples/Calibration/parameters.inp` (the same glacial-till
parameters as the [incremental-driver example](../examples.md), with `alpha = Hpp = 0`):

```
Hardening-Soil-MN-Bricks - calibration of alpha and Hpp
=========================================================
This tool only calibrates the internal cap constants alpha and Hpp.

Enter the path of the parameter file (same format as example/parameters.inp):
parameters.inp

Parameters read successfully. Running the globalised calibration (virtual oedometer test)...

Calibration complete:
  alpha (props(13)) =   5.14542433E-01
  Hpp   (props(14)) =   9.86724062E+03
  convergence history = hs_internal_constants_convergence.csv

Copy these two values into props(13) and props(14) of your Hardening-Soil-MN-Bricks input.
```

See [Examples](../examples.md#calibration-example) for how to run this yourself.
