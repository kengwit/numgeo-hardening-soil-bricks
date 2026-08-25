# Validation

The verification suite combines three element-test comparisons with one axisymmetric
boundary-value benchmark. Two element tests compare the constitutive response against published
external references, while the remaining examples cross-check the Abaqus UMAT interface against
the parent code, numgeo, first at material-point level and then in a spatially non-uniform finite-element analysis.

<div class="hsb-grid" markdown>

<div class="hsb-card" markdown>
### :material-chart-bell-curve: Base model vs. Benz (2007)
Three drained and three undrained triaxial compression tests at different initial mean effective
stresses, back-calculated from Benz's dissertation, with the BRICK extension deactivated
($\gamma_{0.7}$ set negligibly small) to isolate the base mechanism. <br>
[:octicons-arrow-right-16: Details](hs-mn-benz.md)
</div>

<div class="hsb-card" markdown>
### :material-cube-scan: BRICK extension vs. ZSoil
Drained triaxial compression with a small unloading&ndash;reloading loop, compared against the
published ZSoil HS-MC-Bricks reference result — and, in the same figure, direct evidence that the
BRICK extension does not overshoot. <br>
[:octicons-arrow-right-16: Details](hs-mn-bricks-zsoil.md)
</div>

<div class="hsb-card" markdown>
### :material-compare: UMAT (Abaqus) vs. numgeo
The same test run through Abaqus/UMAT and through native numgeo: confirms the UMAT interface
reproduces the parent code's results rather than behaving as an independent reimplementation. <br>
[:octicons-arrow-right-16: Details](umat-vs-numgeo.md)
</div>

<div class="hsb-card" markdown>
### :material-foundation: Circular shallow foundation
Axisymmetric $10\,\mathrm{m}\times10\,\mathrm{m}$ boundary-value problem with a $1\,\mathrm{m}$ footing
radius: compares the complete pressure-settlement path from native numgeo and Abaqus/UMAT. <br>
[:octicons-arrow-right-16: Details](circular-shallow-foundation.md)
</div>

</div>

!!! info "Same parameter set for both external-reference checks"
    Both the drained/undrained comparison against Benz and the BRICK comparison against Cudny
    &amp; Truty / ZSoil use the same dense Hostun sand / glacial till parameter sets already
    validated in the literature this implementation builds on — see
    [Model parameters](../parameters.md) and [References](../references.md).
