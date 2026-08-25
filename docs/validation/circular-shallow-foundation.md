# Axisymmetric circular shallow foundation

The single-element comparison in [UMAT (Abaqus) vs. numgeo](umat-vs-numgeo.md) verifies the
Abaqus calling interface under a homogeneous stress path. This benchmark extends that check to a
spatially non-uniform boundary-value problem: a uniformly loaded **circular shallow foundation**
modelled in an axisymmetric domain.

## Model

The axisymmetric soil domain extends $10\,\mathrm{m}$ in the radial direction and $10\,\mathrm{m}$
in depth. A uniformly distributed vertical pressure acts over a footing radius of $1\,\mathrm{m}$.
The Abaqus model uses a structured mesh of eight-node axisymmetric quadrilateral elements
(`CAX8`). The symmetry axis and the outer radial boundary are fixed in the radial direction; the
bottom boundary is fixed in both coordinate directions.

The analysis consists of two stages:

1. a geostatic step with gravity $g=10\,\mathrm{m/s^2}$ and the prescribed initial geostatic stress
   field;
2. a static footing-loading step in which the pressure is ramped from zero to
   $1000\,\mathrm{kPa}$.

The material is defined through the same 16-parameter `Hardening-Soil-MN-Bricks` UMAT interface
used by the element-test example. The footing-centre settlement is recorded at the node on the
axis beneath the loaded surface.

!!! note "Purpose of the benchmark"
    This is a software-verification benchmark. The constitutive model and material parameters are
    kept fixed while the same boundary-value problem is evaluated through native numgeo and the
    Abaqus UMAT. The comparison therefore tests the complete material-state transfer and repeated
    constitutive calls at spatially varying stress states, rather than providing an independent
    validation of the Hardening Soil model against experimental data.

## Result

<figure class="hsb-fig-wrap" markdown>
![Axisymmetric circular shallow foundation: numgeo vs. Abaqus](../assets/figures/hs-mn-shallow-foundation.png){ .hsb-fig }
<figcaption> Axisymmetric circular shallow-foundation benchmark. (a) Structured domain with a uniformly loaded footing radius of 1 m; (b) footing-centre settlement versus applied pressure increment for native numgeo and Abaqus/UMAT.
</figcaption>
</figure>

The pressure-settlement curves are practically coincident over the complete common loading path
up to $1000\,\mathrm{kPa}$. The agreement is retained as the response evolves from the initial
stiffness-dominated regime into the strongly nonlinear part of the loading curve. In contrast to a
single material-point test, this calculation repeatedly invokes the material routine at integration
points following different stress histories and uses the returned tangent within the global
finite-element equilibrium iterations.

## Input files

The Abaqus files for this benchmark are shipped with the repository in
`examples/umat/circular footing/circular-footing/`:

- [`input-abaqus.inp`](https://github.com/j-machacek/numgeo-hardening-soil-bricks/blob/HEAD/examples/umat/circular%20footing/circular-footing/input-abaqus.inp) - complete Abaqus axisymmetric input deck, including mesh,
  sets, material definition, initial stresses, boundary conditions and loading;
- [`run.bat`](https://github.com/j-machacek/numgeo-hardening-soil-bricks/blob/HEAD/examples/umat/circular%20footing/circular-footinge/run.bat) - convenience command for submitting the model as job `sim` with the
  supplied `user.for` UMAT bundle.

[:octicons-file-directory-16: Browse the benchmark input folder](https://github.com/j-machacek/numgeo-hardening-soil-bricks/tree/HEAD/examples/umat/circular%20footing/circular-footing){ target="_blank" }

The constitutive source and Abaqus wrapper files are the same as for the
[UMAT element-test example](../examples.md#umat-example). Follow the
[UMAT setup instructions](../components/umat.md) before running `run.bat`.
