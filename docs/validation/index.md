# Validation

Two independent element-test comparisons validate this implementation against published
reference results — one for the base Hardening Soil (Matsuoka&ndash;Nakai) mechanism with the
BRICK extension deactivated, and one for the BRICK small-strain extension itself.

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
Drained triaxial compression with small unloading&ndash;reloading loops, compared against the
published ZSoil HS-MC-Bricks reference result for the same glacial till parameters and loading
programme. <br>
[:octicons-arrow-right-16: Details](hs-mn-bricks-zsoil.md)
</div>

<div class="hsb-card" markdown>
### :material-sync-alert: Overshooting check
The same BRICK mechanism, isolated from any failure-criterion difference: an interrupted loading
path reproduces its own purely monotonic reference to within $0.16\,\%$, reproducing Cudny &amp;
Truty's own overshooting test. <br>
[:octicons-arrow-right-16: Details](hs-mn-bricks-overshoot.md)
</div>

</div>

!!! info "Same parameter set for both base-model checks"
    Both the drained/undrained comparison against Benz and the earlier
    [overshooting check](../theory.md) against Cudny &amp; Truty use the same dense Hostun sand /
    glacial till parameter sets already validated in the literature this implementation builds
    on — see [Model parameters](../parameters.md) and [References](../references.md).
