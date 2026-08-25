# UMAT (Abaqus) vs. numgeo

The two previous validations check the constitutive routine itself against external references.
This one checks something different: that the **Abaqus UMAT interface reproduces the results of
the parent code, numgeo**, from which it was extracted — i.e. that `user.for`/`umat.f90`/`sdvini.f90`
correctly translate Abaqus' calling convention into the same constitutive routine numgeo calls
directly, without introducing any transcription error along the way.

## Test

The [shipped UMAT example](../examples.md#umat-example) (`examples/umat/triax-hs-bricks.inp`) —
a single axisymmetric element, drained triaxial compression to $-10\,\%$ axial strain, glacial
till parameters with the BRICK extension active — run two ways: once through Abaqus/UMAT, once
through native numgeo, with identical material parameters and loading path.

<figure class="hsb-fig-wrap" markdown>
![Abaqus UMAT vs. native numgeo](../assets/figures/hs-mn-bricks-umat-vs-numgeo.png){ .hsb-fig }
<figcaption>
Drained triaxial compression to -10% axial strain: Abaqus (via the UMAT interface) against
native numgeo, for identical parameters and loading.
</figcaption>
</figure>

Over the full loading range, the deviatoric stress $q$ agrees to a mean absolute difference of
$0.9$&nbsp;kPa and a maximum of $8.6$&nbsp;kPa (about $2\,\%$ of the peak $q$), concentrated in the
first $0.2\,\%$ of axial strain where $q$ is changing most rapidly and the two runs' increment
sizes differ; the volumetric strain $\varepsilon_v$ agrees to within $0.05$ percentage points
throughout. At the end of loading the two paths agree almost exactly: $\Delta q = 0.02$&nbsp;kPa
and $\Delta\varepsilon_v = 0.04$ percentage points.

!!! info "What this does and doesn't validate"
    This comparison isolates the **UMAT translation layer** — it says nothing new about the
    constitutive model itself (that's what the [Benz](hs-mn-benz.md) and
    [ZSoil](hs-mn-bricks-zsoil.md) comparisons are for), but it is the direct evidence that using
    the model through Abaqus gives the same physics as using it through numgeo or the
    [incremental driver](../components/incremental-driver.md), not an independently-behaving
    reimplementation.

## Boundary-value verification

The same interface has additionally been exercised in a spatially non-uniform finite-element
problem. The [axisymmetric circular shallow-foundation benchmark](circular-shallow-foundation.md)
compares the complete pressure-settlement response obtained with native numgeo and Abaqus/UMAT
for the same geometry, material parameters and loading history.

