!=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~
!                                          numgeo
!                Copyright (C) 2018-2026 Jan Machacek, Patrick Staubach
!=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~
!
! MODULE: material_hardening_soil_MN_bricks_
!
!> author: Jan Machacek, jan-machacek@outlook.com
!> date: 20.12.2025
!
! DESCRIPTION:
!
!> Hardening Soil model [1] with Matsuoka-Nakai failure surface [2] following the dissertation of Th. Benz
!> extended by the BRICK small-strain stiffness formulation (HS-Brick) of Cudny & Truty [5],
!> which is based on the nested strain-space yield surface concept of Simpson [6].
!
!> The current implementation builds upon the implementation by Leonardo José Cocco [4]
!> who kindly provided the original Fortran code in UMAT format, which was used as the basis for the implementation in numgeo.
!> The base subroutines of the BRICK extension (string properties and brick movement)
!> were kindly provided by M. Cudny and were refactored for the integration in numgeo.
!
!> For the integration in numgeo, the original code was refactored: 
!> ... Changed form to modern fortran, naming conventions, translated comments,
!> ... Parameters to derived type + type bound procedure 
!> ... Reduced LOC, improved readability
!> ... Added fucntions: yield_function_fs, get_elastic_jacobian, lode_shape_facators, get_mob_dilatancy_angle
!> ... Proper intent(..), minimal calling interfaces, remove LAPACK dependency
!> ... Cleaned return mapping subroutines, return cumulative elastic tangent
!> ... subincrement size depending on target strain
!> ... Speed-up compared to original version x5
!
!> HS-Brick extension (see [5]):
!> ... The hypoelastic kernel of the base model (stress-dependent Eur, constant nu) is replaced by a
!>     strain- and stress-dependent stiffness E_t = 2(1+nu)*Gref_t*fac, with Gur_ref <= Gref_t <= G0ref.
!>     The reference tangent shear modulus Gref_t is controlled by NBRICKS = 10 nested yield surfaces
!>     (bricks) in strain space, whose relative distances to the "man" (total strain) are measured by the
!>     shear strain invariant gamma = sqrt(3/2 e:e) of the strain distance (Box 1 in [5]).
!> ... The elastic predictor is sub-incremented such that the shear strain invariant of a single brick
!>     sub-increment does not exceed GAMMA_SUB_MAX = 5.0e-5 (Box 2 in [5]).
!> ... The hardening laws of the deviatoric and volumetric mechanisms are enhanced by the factor
!>     H_i = Gm**(1 + Eur_ref/(2 E50_ref)), where Gm is the minimum of Gref_t/Gur_ref over the loading
!>     history (Eqs. 22-24 in [5]). The moduli Ei and Eur entering the yield function fs remain the
!>     standard barotropic ones of the base model (Sect. 4.1 in [5]).
!> ... Additional material properties: props(15) = gamma07 (shear strain at G = 0.722 G0),
!>     props(16) = G0ref (small-strain reference shear modulus at pref). For G0ref = Eur_ref/(2(1+nu))
!>     the extension degenerates to the base Hardening Soil model.
!> ... State variables (nstatev >= 73): statev(1) reserved, statev(2) = gammapss, statev(3) = pp,
!>     statev(4) = p, statev(5) = q, statev(6) = Gm, statev(7) = number of active bricks,
!>     statev(8:13) = man strain (tensorial shear components, order 11,22,33,12,13,23),
!>     statev(14:73) = brick strains (6 components per brick, same order and convention).
!
!> History
!>* 20.12.2025, J. Machacek - Initial version
!>* 27.12.2025, J. Machacek - Further refactoring and speed-up of derivatives (2-3x faster)
!>* 06.03.2026, J. Machacek - Control parameters now in derived type
!>* 09.03.2026, J. Machacek - Avoid repeated conversions from friciton angles to sines, calculate and use sines directly
!                           - Gather all control variables in derived type, add safeguards to mobilised dilatancy angle
!                           - Precompute expensive tensor operations (x2 faster)
!>* 01.06.2026, J. Machacek - Helper functions mob_sin_phi, yield_function_fc, stiffness_factor (DRY, fewer pow)
!                           - Precompute sin_phi_cs, eta_phi, Rf_eta_phi, inv_pref_apex in mat type
!                           - Trim df_dg_cone / df_dg_cap / get_mob_dilatancy_angle interfaces
!                           - Remove dead consistent-tangent accumulator D and unused locals
!                           - H_GAMMA module constant; error stop on NaN; optimiser .or.->.and.; minor fixes
!>* 01.07.2026, J. Machacek - HS-Brick small-strain extension following Cudny & Truty [5]
!                           - hardening enhancement H_i (Eqs. 22-24 in [5]) for cone (return mappings) and cap (pre-scaled hc);
!                           - new props(15) = gamma07 and props(16) = G0ref; state variables 6-73 (Gm, n_bricks, man/brick strains)
!>* 20.07.2026, J. Machacek - Correct engineering-shear Voigt derivatives of cone and cap functions
!                           - Preserve return mapping, substepping, public interfaces and state-variable history
!>* 21.08.2026, J. Machacek - Synchronise the standalone UMAT source with the current numgeo implementation
!                           - Restore first-increment state initialisation for iinc == 1
!                           - Use standard-conforming declaration order for dummy array bounds
!
!> References
!
! [1] Schanz, T., Vermeer, P. A., Bonnier, P. G., 1999.
!     "The Hardening Soil model: formulation and verification."
!     In: Beyond 2000 in Computational Geotechnics — 10 Years of PLAXIS International. Balkema, Rotterdam, pp. 281–296.
! 
! [2] Matsuoka, H., Nakai, T., 1974.
!     "Stress-deformation and strength characteristics of soil under three different principal stresses.*"
!     Proceedings of the Japan Society of Civil Engineers 232, 59–70.
!
! [3] Benz, Thomas. 
!     „Small-Strain Stiffness of Soils and Its Numerical Consequences“. 
!     Dissertation, Inst. für Geotechnik, 2007. https://www.igs.uni-stuttgart.de/dokumente/Mitteilungen/55_Benz.pdf.
!
! [4] Cocco, L. J., und M. E. Ruiz. 
!     „Numerical Implementation of Hardening Soil Model“. 
!     In Numerical Methods in Geotechnical Engineering IX, Volume 1, 1. Aufl., von Manuel De Matos Fernandes. 
!     CRC Press, 2018. https://doi.org/10.1201/9780429446931-25.
!
! [5] Cudny, M., und A. Truty. 
!     „Refinement of the Hardening Soil model within the small strain range“. 
!     Acta Geotechnica 15 (2020) 2031–2051. https://doi.org/10.1007/s11440-020-00945-5.
!
! [6] Simpson, B., 1992.
!     "Retaining structures: displacement and design, 32nd Rankine Lecture."
!     Géotechnique 42(4), 541–576.
!
!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
module material_hardening_soil_MN_bricks_
  use precision_, only: rk, ik
  use compatibility_numgeo_, only: pi
  
  private
  public:: hardening_soil_MN_bricks, optimize_hs_bricks_internal_constants
  
  ! BRICK small-strain extension constants (added 01.07.2026, J. Machacek)
  integer(ik), parameter :: NBRICKS = 10                       ! number of bricks (nested yield surfaces in strain space)
  real(rk), parameter :: GAMMA_SUB_MAX = 5.0e-5_rk             ! max. shear strain invariant per brick sub-increment (Box 2 in [5])
  integer(ik), parameter :: NSTATEV_BRICKS = 13 + 6*NBRICKS    ! required number of state variables (= 73)
  
  type material_properties_ty_
    real(rk) :: E50
    real(rk) :: Eoed
    real(rk) :: Eur
    real(rk) :: m
    real(rk) :: c
    real(rk) :: phi
    real(rk) :: psi
    real(rk) :: nu
    real(rk) :: pref
    real(rk) :: K0nc
    real(rk) :: Rf
    real(rk) :: Ei
    real(rk) :: alpha
    real(rk) :: Hpp
    ! internal parameter
    real(rk) :: Ks
    real(rk) :: Kc
    real(rk) :: phi_mob_lim
    real(rk) :: ctan_phi
    real(rk) :: sin_phi
    real(rk) :: sin_psi
    real(rk) :: Mc
    real(rk) :: apex
    ! Precomputed constants
    real(rk) :: sin_phi_cs      ! critical-state friction (sine): (sin_phi-sin_psi)/(1-sin_phi*sin_psi)
    real(rk) :: eta_phi         ! (1-sin_phi)/sin_phi
    real(rk) :: Rf_eta_phi      ! Rf*(1-sin_phi)/sin_phi
    real(rk) :: inv_pref_apex   ! 1/(pref+apex)
    ! BRICK small-strain extension
    real(rk) :: gamma07         ! shear strain at G = 0.722 G0 (Hardin-Drnevich threshold), props(15)
    real(rk) :: G0              ! small-strain reference shear modulus at pref, props(16)
    real(rk) :: Gur_ref         ! reference unloading-reloading shear modulus: Eur_ref/(2(1+nu))
    real(rk) :: E0fac           ! 2(1+nu): converts a shear modulus into a Young's modulus (constant nu)
    real(rk) :: Gm_max          ! upper bound of the stiffness ratio Gm: G0/Gur_ref
    real(rk) :: exp_hi          ! exponent of the hardening enhancement H_i: 1 + Eur_ref/(2 E50_ref)
    real(rk) :: sl(NBRICKS)     ! string lengths of the bricks (shear strain invariant)
    real(rk) :: snbp(NBRICKS)   ! stiffness proportions of the bricks (delta omega in [5])
  contains
    procedure, pass(self) :: collect => material_collect_properties
  end type material_properties_ty_
      
  type controls_ty_
    real(rk) :: TOL = 1.0e-9_rk
    real(rk) :: TOL_phi = 1.0e-15_rk
    real(rk) :: STRESS_MIN = 0.1_rk
    real(rk) :: PHI_MOB_MAX = 0.999999_rk
    real(rk) :: PHI_MOB_MIN = 0.000001_rk
    integer(ik) :: MAXITER = 1000
  end type controls_ty_

  ! Hardening factor: dgammapss = dl * H_GAMMA, with H_GAMMA = 3/2
  real(rk), parameter :: H_GAMMA = 1.5_rk

  contains

  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 20.12.2025
  !
  !> Main driver of the Hardening Soil model with Matsuoka-Nakai yield surface and BRICK small-strain
  !> extension (HS-Brick, [5]): elastic predictor with strain-dependent stiffness degradation,
  !> return mapping (cone / cap / mixed, incl. failure) and state update.
  !
  !>### History
  !>* 20.12.2025, J. Machacek - Initial version
  !>* 01.06.2026, J. Machacek - Use helpers (mob_sin_phi/yield_function_fc/stiffness_factor) and precomputed
  !                           - mat constants; remove dead tangent D and unused locals; error stop on NaN;
  !                           - initialise state on (istep==1 .and. iinc==1) only
  !>* 01.07.2026, J. Machacek - HS-Brick extension: read/commit BRICK state; elastic predictor replaced by the
  !                           - sub-incremented brick_elastic_predictor (actual small-strain stiffness E_t);
  !                           - hardening enhancement H_i = Gm**(1+Eur_ref/(2 E50_ref)) applied to the cone
  !                           - (return mappings) and cap (pre-scaled hc, reusing fac); elastic tangent from E_t;
  !                           - commit brick state on vertex early return; extended NaN diagnostics
  !>* 03.07.2026, J. Machacek - Only auto-initialise pp0 (and gammapss0) on the first increment of an analysis
  !                           - if pp0 arrives as statev(3) <= 0 (i.e. genuinely not set by the caller).
  !>* 21.08.2026, J. Machacek - Restore first-increment state initialisation for iinc == 1 in the standalone UMAT copy
  !                           - Use standard-conforming declaration order for dummy array bounds
  !

  subroutine hardening_soil_MN_bricks(stress,statev,dds_dde,dstrain,time,dtime,ntens,nstatev,props,nprops,istep,iinc)
    use compatibility_numgeo_, only: cartesian_to_principal_stress_analytical, roscoe_pq_voigt, invariant_J2, invariants_J2_J3
    implicit none
    
    integer, intent(in) :: ntens
    integer, intent(in) :: nstatev
    integer, intent(in) :: nprops
    integer, intent(in) :: istep
    integer, intent(in) :: iinc
    real(rk), dimension(ntens), intent(inout) :: stress
    real(rk), dimension(nstatev), intent(inout) :: statev
    real(rk), dimension(ntens,ntens), intent(inout) :: dds_dde
    real(rk), dimension(ntens), intent(in) :: dstrain
    real(rk), dimension(nprops), intent(in) :: props
    real(rk), intent(in) :: time
    real(rk), intent(in) :: dtime

    real(rk) :: fs, fc, tanbeta, dstrain_sub(ntens)
                
    ! stiffness and hardening variables
    real(rk) :: Eur, Ei, hc, Mcs, chi
                
    ! stress and stress invariants
    real(rk) :: stress0(ntens), S(3), sigma3, J2, J3, p, q, p0, q0
      
    ! friction/dilatation angles (sine)
    real(rk) :: sin_psi_mob, sin_phi_mob

    ! trial state
    real(rk) :: stress_trial(ntens), p_trial, q_trial, fs_trial, fc_trial, sin_phi_mob_trial, sin_psi_mob_trial
    
    integer(ik) :: flag, k, nsub
    
    type(material_properties_ty_) :: mat
    type(controls_ty_) :: ctrl
    
    real(rk) :: gammapss0, gammapss, pp, pp0, fac

    ! BRICK small-strain state
    real(rk) :: Gm0, Gm       ! stiffness ratio Gm = min(Gref_t/Gur_ref) over the loading history (>= 1)
    real(rk) :: Gref_t        ! actual reference tangent shear modulus, Gur_ref <= Gref_t <= G0
    real(rk) :: E_t           ! actual Young's modulus of the elastic operator: 2(1+nu)*Gref_t*fac
    real(rk) :: H_i           ! hardening enhancement factor H_i = Gm**exp_hi (Eq. 24 in [5])
    real(rk) :: sn0(6), sn(6)                     ! man strain (tensorial shear components)
    real(rk) :: snb0(6,NBRICKS), snb(6,NBRICKS)   ! brick strains (tensorial shear components)
    integer(ik) :: n_bricks                       ! number of active (dragged) bricks

    ! stress state at the start of the increment
    stress0 = stress
    
    ! read in the material constants
    call mat%collect(props,nprops)
    
    gammapss0 = statev(2)
    pp0 = statev(3)

    ! read (or initialise) the BRICK small-strain state and create working copies
    call read_brick_state(statev, nstatev, mat, istep, iinc, Gm0, sn0, snb0)
    Gm = Gm0 ; sn = sn0 ; snb = snb0

    ! Stress-dependent stiffness factor at the beginning of the increment
    S = cartesian_to_principal_stress_analytical(ntens,stress)
    sigma3 = maxval((/-maxval(S),ctrl%STRESS_MIN/))
    fac = stiffness_factor(sigma3, mat)

    !
    ! Elastic predictor: trial stress at the end of the increment
    ! (BRICK stiffness degradation, sub-incremented following Box 2 in [5])
    !
    
    call brick_elastic_predictor(stress,dstrain,ntens,mat,fac,sn,snb,Gm,Gref_t,E_t,n_bricks)
    
    dds_dde = get_elastic_jacobian(E_t,mat%nu,ntens)
    
    ! Determination of invariants and stresses to evaluate the yield function
    call roscoe_pq_voigt(ntens,stress,p_trial,q_trial)
    call invariants_J2_J3(stress,ntens,J2,J3)

    ! Lode angle-dependent formulation for the Matsuoka-Nakai criterion
    call lode_shape_factor(J2, J3, mat%sin_phi, chi)
            
    ! Parameter update with the stress state at the start of the increment
    call roscoe_pq_voigt(ntens,stress0,p0,q0)
    J2 = invariant_J2(stress0,ntens)
    
    if (p0 == 0.0_rk .and. q0 == 0.0_rk) then
      stress0 = stress
      call roscoe_pq_voigt(ntens,stress0,p0,q0)
      J2 = invariant_J2(stress0,ntens)
    end if
    
    S = cartesian_to_principal_stress_analytical(ntens,stress0)

    ! mobilised friciton angle, clamped to an upper and lower bound
    sin_phi_mob_trial = mob_sin_phi(p_trial, q_trial, chi, mat%apex)
    if (dabs(sin_phi_mob_trial) >= 1.0_rk) then
      sin_phi_mob_trial = ctrl%PHI_MOB_MAX
    else if (sin_phi_mob_trial > -1.0_rk .and. sin_phi_mob_trial <= 0.0_rk) then
      sin_phi_mob_trial = ctrl%PHI_MOB_MIN
    end if

    !
    ! substepping if phi_mob_trial is greater than mat%phi
    !
    
    if (sin_phi_mob_trial > mat%sin_phi) then
      
      stress = stress0
      
      ! discard the whole-increment brick trial update; the bricks are re-driven per sub-increment
      Gm = Gm0 ; sn = sn0 ; snb = snb0
      
      nsub = max(int(norm2(dstrain)/5e-6_rk),10)
      dstrain_sub = dstrain/real(nsub, kind=rk)
      
      
      substepping: do k = 1, nsub
      
         flag = 0
      
         S = cartesian_to_principal_stress_analytical(ntens,stress)
         sigma3 = maxval((/-maxval(S),ctrl%STRESS_MIN/))
         p0 = -(stress(1)+stress(2)+stress(3))/3.0_rk
         
         fac = stiffness_factor(sigma3, mat)
         Ei  = mat%Ei  * fac
         Eur = mat%Eur * fac
         
         ! Calculation of the test stress at the end of the sub-increment
         ! (BRICK stiffness degradation; at most one internal brick sub-increment for the small dstrain_sub)
         call brick_elastic_predictor(stress,dstrain_sub,ntens,mat,fac,sn,snb,Gm,Gref_t,E_t,n_bricks)
         
         dds_dde = get_elastic_jacobian(E_t,mat%nu,ntens)
         
         ! Hardening enhancement of the deviatoric and volumetric mechanisms (Eqs. 22-24 in [5])
         H_i = Gm**mat%exp_hi
         hc  = 2.0_rk*mat%Hpp * fac * (p0+mat%apex) * H_i
      
         ! Determination of invariants and stresses to evaluate the creep function
         call roscoe_pq_voigt(ntens,stress,p_trial,q_trial)
         call invariants_J2_J3(stress,ntens,J2,J3)
      
         ! Lode angle-dependent formulation for the Matsuoka-Nakai criterion
         call lode_shape_factor(J2, J3, mat%sin_phi, chi)
         Mcs = chi*mat%Mc

         ! mobilised friciton angle, clamped to an upper and lower bound
         sin_phi_mob_trial = mob_sin_phi(p_trial, q_trial, chi, mat%apex)
         if (dabs(sin_phi_mob_trial) >= 1.0_rk) then
           sin_phi_mob_trial = ctrl%PHI_MOB_MAX
         else if (sin_phi_mob_trial > -1.0_rk .and. sin_phi_mob_trial <= 0.0_rk) then
           sin_phi_mob_trial = ctrl%PHI_MOB_MIN
         end if
            
         ! mobilised friciton angle and dilatancy angle
         sin_psi_mob_trial = get_mob_dilatancy_angle(sin_phi_mob_trial, mat%sin_phi_cs, mat%apex, Mcs, p_trial, q_trial)
         
         ! Assessment of flow functions
         fs_trial = yield_function_fs(q_trial, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob_trial, gammapss0)
         fc_trial = yield_function_fc(p_trial, q_trial, pp0, chi, mat%alpha, mat%apex)
      
         ! Strategy for return to yield strength and stress calculation
      
         stress_trial = stress
      
         if (sin_psi_mob_trial > mat%sin_psi - ctrl%TOL_phi) then
           tanbeta = 6.0_rk * mat%sin_psi / (3.0_rk-mat%sin_psi)
         else
           tanbeta = 6.0_rk * sin_psi_mob_trial / (3.0_rk-sin_psi_mob_trial)
         end if
      
         ! Verification of the Vertex
      
         if ( p_trial <= -0.97_rk*(q_trial*tanbeta+mat%apex) ) then
      
           gammapss = gammapss0
           pp = pp0
      
           call enforce_vertex(p_trial,q_trial,stress,mat%apex,ntens)
           p = p_trial ; q = q_trial
           
           S = cartesian_to_principal_stress_analytical(ntens,stress)
           sigma3 = maxval((/-maxval(S),ctrl%STRESS_MIN/))
           
           fac = stiffness_factor(sigma3, mat)
           Eur = mat%Eur*fac
           E_t = mat%E0fac * Gref_t * fac
           
           dds_dde = get_elastic_jacobian(E_t,mat%nu,ntens)
           
           fs_trial = 0.0_rk
           fc_trial = 0.0_rk
           flag = 1
           
         end if
         
         elastic_or_plastic: if (fs_trial >= ctrl%TOL) then
           
           !
           ! plastic: cone violation
           !
      
           call return_mapping_yield_surface(stress_trial,ntens,fs_trial,mat,sin_phi_mob,sin_psi_mob,Eur,Ei,dds_dde,&
                                             gammapss0,gammapss,stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,sin_phi_mob_trial, &
                                             sin_psi_mob_trial,H_i)
           
           if ( sin_phi_mob > mat%sin_phi) then
           
              call return_mapping_failure_surface(stress_trial,ntens,fs_trial,mat,Eur,Ei,dds_dde,gammapss0, &
                                                  gammapss,p_trial,q_trial,stress,p,q,mat%sin_phi_cs,Mcs,fs,chi, &
                                                  sin_phi_mob,sin_psi_mob,sin_phi_mob_trial,sin_psi_mob_trial)
                    
           end if
           
           fc = yield_function_fc(p, q, pp0, chi, mat%alpha, mat%apex)
           
           pp = pp0
           
           if (fc >= ctrl%TOL) then
           
             call return_mapping_cap_surface(stress_trial,ntens,fc_trial,mat,Eur,Ei,dds_dde, &
                                             pp0,pp,p_trial,q_trial,stress,p,q,chi,Mcs,fc,hc)
             
             sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)
             
             fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss0)
             
             gammapss = gammapss0
             
             if (fs >= ctrl%TOL) then
             
               call return_mapping_mixed_surface(stress_trial,ntens,fs_trial,mat,sin_phi_mob,sin_psi_mob,Eur,Ei,dds_dde,&
                                                 gammapss0,gammapss,stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,fc_trial,fc,pp0,&
                                                 pp,p_trial,q_trial,hc,sin_phi_mob_trial,sin_psi_mob_trial,H_i)
               
               if ( sin_phi_mob > mat%sin_phi) then
                 call return_mapping_mixed_failure_surface(stress_trial,ntens,fs_trial,mat,Eur,Ei,dds_dde,gammapss0,gammapss,&
                                                           stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,sin_phi_mob,sin_psi_mob,fc_trial,&
                                                           fc,pp0,pp,p_trial,q_trial,hc,sin_phi_mob_trial,sin_psi_mob_trial)
               end if
               
             end if
             
           end if
           
           flag = 1
           
         else if ( fc_trial >= ctrl%TOL ) then
           
           !
           ! plastic: cap violation
           !
      
           call return_mapping_cap_surface(stress_trial,ntens,fc_trial,mat,Eur,Ei,dds_dde,pp0,pp,&
                                           p_trial,q_trial,stress,p,q,chi,Mcs,fc,hc)
           
           sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)
      
           fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss0)
           
           gammapss = gammapss0
           
           if (fs >= ctrl%TOL) then
           
             call return_mapping_mixed_surface(stress_trial,ntens,fs_trial,mat,sin_phi_mob,sin_psi_mob,Eur,Ei,dds_dde,gammapss0,&
                                               gammapss,stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,fc_trial,fc,pp0,pp,p_trial,q_trial, &
                                               hc,sin_phi_mob_trial,sin_psi_mob_trial,H_i)
             
             if ( sin_phi_mob > mat%sin_phi) then
               call return_mapping_mixed_failure_surface(stress_trial,ntens,fs_trial,mat,Eur,Ei,dds_dde,gammapss0,gammapss,&
                                                        stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,sin_phi_mob,sin_psi_mob,fc_trial,&
                                                        fc,pp0,pp,p_trial,q_trial,hc,sin_phi_mob_trial,sin_psi_mob_trial)
             end if
             
           end if
           
           flag = 1
           
         else if (flag == 0) then
      
           !
           ! Elastic: plastic variables and multipliers are updated
           !
             
           gammapss = gammapss0
           pp = pp0
           p = p_trial
           q = q_trial
      
         end if elastic_or_plastic
         
         gammapss0 = gammapss
         pp0 = pp
         
         
      end do substepping

    !
    ! mob. friction angle < mat. friction angle (no substepping required)
    !
      
    else
         
       sigma3 = maxval([-maxval(S),ctrl%STRESS_MIN])
       fac = stiffness_factor(sigma3, mat)
       Ei  = mat%Ei  * fac
       Eur = mat%Eur * fac
       Mcs = chi*mat%Mc

       ! Hardening enhancement of the deviatoric and volumetric mechanisms (Eqs. 22-24 in [5])
       H_i = Gm**mat%exp_hi
       hc = 2.0_rk*mat%Hpp * fac * (p0+mat%apex) * H_i
       
       ! mobilised dilatancy angle
       sin_psi_mob_trial = get_mob_dilatancy_angle(sin_phi_mob_trial, mat%sin_phi_cs, mat%apex, Mcs, p_trial, q_trial)
       
       ! Initialise state variables. Only if pp0 (statev(3)) arrives as <= 0, i.e. genuinely unset by the caller
       if (istep == 1 .and. iinc == 1 ) then
         gammapss0 = -( -1.5_rk*q_trial/Ei + 1.5_rk*q_trial/Eur * ((1.0_rk-sin_phi_mob_trial)/sin_phi_mob_trial - &
                       mat%Rf*(1.0_rk-mat%sin_phi)/mat%sin_phi) / (1.0_rk-sin_phi_mob_trial) * sin_phi_mob_trial ) / &
                       ((1.0_rk-sin_phi_mob_trial)/sin_phi_mob_trial - mat%Rf*(1.0_rk-mat%sin_phi)/mat%sin_phi) * &
                       (1.0_rk-sin_phi_mob_trial)/sin_phi_mob_trial
         if (pp0 <= 0.0_rk) pp0 = dsqrt( q_trial**2/(chi*mat%alpha)**2 + (p_trial+mat%apex)**2 ) - mat%apex
       end if
       
       ! Assessment of yield functions
       fs_trial = yield_function_fs(q_trial, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob_trial, gammapss0)
       fc_trial = yield_function_fc(p_trial, q_trial, pp0, chi, mat%alpha, mat%apex)
       
       ! Strategy for return to yield strength and stress calculation
       
       stress_trial = stress
       
       if (sin_psi_mob_trial >= mat%sin_psi) then
         tanbeta = 6.0_rk*mat%sin_psi/(3.0_rk-mat%sin_psi)
       else
         tanbeta = 6.0_rk*sin_psi_mob_trial/(3.0_rk-sin_psi_mob_trial)
       end if
       
       ! Verification of the Vertex
       
       if (p_trial <= -0.97_rk*(q_trial*tanbeta+mat%apex)) then
       
         gammapss = gammapss0
         pp = pp0
         
         call enforce_vertex(p_trial,q_trial,stress,mat%apex,ntens)
         
         call commit_brick_state(statev,nstatev,Gm,n_bricks,sn,snb)
         statev(2) = gammapss
         statev(3) = pp
         statev(4) = p_trial
         statev(5) = q_trial
         return
       
       end if

       !
       ! Cone is violated
       ! 
       if (fs_trial >= ctrl%TOL) then
       
         call return_mapping_yield_surface(stress_trial,ntens,fs_trial,mat,sin_phi_mob,sin_psi_mob,Eur,Ei,dds_dde,gammapss0,&
                                           gammapss,stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,sin_phi_mob_trial,sin_psi_mob_trial,H_i)
         
         if ( sin_phi_mob > mat%sin_phi) then
           call return_mapping_failure_surface(stress_trial,ntens,fs_trial,mat,Eur,Ei,dds_dde,gammapss0,gammapss,p_trial,q_trial,&
                                               stress,p,q,mat%sin_phi_cs,Mcs,fs,chi,sin_phi_mob,sin_psi_mob,sin_phi_mob_trial, &
                                               sin_psi_mob_trial)  
         end if
         
         fc = yield_function_fc(p, q, pp0, chi, mat%alpha, mat%apex)
         
         pp = pp0
         
         if (fc >= ctrl%TOL) then
         
           call return_mapping_cap_surface(stress_trial,ntens,fc_trial,mat,Eur,Ei,dds_dde,pp0,&
                                           pp,p_trial,q_trial,stress,p,q,chi,Mcs,fc,hc)
           
           sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)

           fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss0)
           
           gammapss = gammapss0
           
           if (fs >= ctrl%TOL) then
            
             call return_mapping_mixed_surface(stress_trial,ntens,fs_trial,mat,sin_phi_mob,sin_psi_mob,Eur,Ei,dds_dde,gammapss0,&
                                               gammapss,stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,fc_trial,fc,pp0,pp,p_trial,q_trial, &
                                               hc,sin_phi_mob_trial,sin_psi_mob_trial,H_i)
    
             if ( sin_phi_mob > mat%sin_phi) then
               call return_mapping_mixed_failure_surface(stress_trial,ntens,fs_trial,mat,Eur,Ei,dds_dde,gammapss0,gammapss,&
                                                        stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,sin_phi_mob,sin_psi_mob,fc_trial,&
                                                        fc,pp0,pp,p_trial,q_trial,hc,sin_phi_mob_trial,sin_psi_mob_trial)
             end if
             
           end if
           
         end if

       !
       ! Cap is violated
       ! 
       else if (fc_trial >= ctrl%TOL) then
       
         call return_mapping_cap_surface (stress_trial,ntens,fc_trial,mat,Eur,Ei,dds_dde,pp0,pp,&
                                          p_trial,q_trial,stress,p,q,chi,Mcs,fc,hc)

         sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)

         fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss0)
         
         gammapss = gammapss0
         
         if (fs >= ctrl%TOL) then
         
            call return_mapping_mixed_surface(stress_trial,ntens,fs_trial,mat,sin_phi_mob,sin_psi_mob,Eur,Ei,dds_dde,gammapss0,&
                                              gammapss,stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,fc_trial,fc,pp0,pp,p_trial,q_trial,&
                                              hc,sin_phi_mob_trial,sin_psi_mob_trial,H_i)

            if ( sin_phi_mob > mat%sin_phi) then
               call return_mapping_mixed_failure_surface(stress_trial,ntens,fs_trial,mat,Eur,Ei,dds_dde,gammapss0,gammapss,&
                                                         stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,sin_phi_mob,sin_psi_mob,fc_trial,&
                                                         fc,pp0,pp,p_trial,q_trial,hc,sin_phi_mob_trial,sin_psi_mob_trial)
            end if
         
         end if

       !
       ! Elastic case, plastic variables and multipliers are updated
       ! 
       else

         gammapss = gammapss0
         pp = pp0
       
       end if
         
     end if
               
     ! Updating state variables and calculating the updated elastic matrix
    
     call roscoe_pq_voigt(ntens,stress,p,q)
     
     dds_dde = get_elastic_jacobian(E_t,mat%nu,ntens)
     
     if (any(isnan(stress))) then
       print *, "NaN detected in stress"
       print *, "Stress: ", stress
       print *, "p: ", p, " q: ", q
       print *, "gammapss: ", gammapss
       print *, "pp: ", pp
       print *, "fs: ", fs
       print *, "sin_phi_mob_trial: ", sin_phi_mob_trial
       print *, "sin_phi_mob: ", sin_phi_mob
       print *, "sin_psi_mob_trial: ", sin_psi_mob_trial
       print *, "sin_psi_mob: ", sin_psi_mob
       print *, "Gm: ", Gm, " Gref_t: ", Gref_t, " E_t: ", E_t
       ! NB: a cut-back signal (pnewdt < 1) would be preferable to a hard stop once the interface supports it
       error stop "hardening_soil_MN_bricks: NaN in stress (see diagnostics above)"
     end if
     
     call commit_brick_state(statev,nstatev,Gm,n_bricks,sn,snb)
     statev(2) = gammapss
     statev(3) = pp
     statev(4) = p
     statev(5) = q
     
  end subroutine hardening_soil_MN_bricks

         
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> return mapping to the cone (deviatoric) yield surface
  !> Original verison (RCONO) by Leonardo José Cocco
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version (refactoring, modernizing)
  !>* 09.03.2026, J. Machacek - Precompute expensive tensor operations, use sine of angles directly
  !>* 01.06.2026, J. Machacek - Use mob_sin_phi/yield_function_fc and the H_GAMMA constant; df_dg_cone interface (Rf_eta_phi)
  !                           - remove dead tangent D and unused index i
  !>* 01.07.2026, J. Machacek - Hardening enhancement H_i of the HS-Brick extension: dgammapss = dl*H_GAMMA*H_i (Eq. 22 in [5])
  !   
  subroutine return_mapping_yield_surface(stress_trial, ntens, fs_trial, mat, sin_phi_mob, sin_psi_mob, &
                                          Eur, Ei, dds_dde, gammapss0, gammapss, stress, p, q, chi, &
                                          sin_phi_cs, Mcs, fs, sin_phi_mob_trial, sin_psi_mob_trial, H_i)
    use compatibility_numgeo_, only: matinv4x4, matinv6x6_gauss_jordan, roscoe_pq_voigt, get_eye
    implicit none
    
    integer(ik), intent(in) :: ntens
    real(rk), intent(in) :: stress_trial(ntens)
    real(rk), intent(in) :: fs_trial
    type(material_properties_ty_), intent(in) :: mat
    real(rk), intent(in) :: Eur
    real(rk), intent(in) :: Ei
    real(rk), intent(in) :: dds_dde(ntens,ntens)
    real(rk), intent(in) :: gammapss0
    real(rk), intent(in) :: chi
    real(rk), intent(in) :: sin_phi_cs
    real(rk), intent(in) :: Mcs
    real(rk), intent(in) :: sin_phi_mob_trial
    real(rk), intent(in) :: sin_psi_mob_trial
    real(rk), intent(in) :: H_i   ! hardening enhancement factor of the HS-Brick extension (Eq. 24 in [5])
    
    real(rk), intent(out) :: stress(ntens)
    real(rk), intent(out) :: sin_phi_mob
    real(rk), intent(out) :: sin_psi_mob
    real(rk), intent(out) :: gammapss
    real(rk), intent(out) :: p
    real(rk), intent(out) :: q
    real(rk), intent(out) :: fs
    
    type(controls_ty_) :: ctrl
    
    ! Local variables
    real(rk) :: TOL_fs, zeta
    real(rk) :: hgam   ! H_i-enhanced hardening factor: hgam = H_GAMMA*H_i
    real(rk) :: Eye(ntens, ntens)
    real(rk) :: sigma(ntens)
    real(rk) :: dl, ddl, dgammapss
    real(rk) :: Res(ntens)
    real(rk) :: Xi(ntens, ntens)
    real(rk) :: Xiinv(ntens, ntens)
    real(rk) :: m2(ntens,ntens), m(ntens), n(ntens)
    real(rk) :: ddsdde_m(ntens)
    
    integer(ik) :: iiter
    
    ! Initialize variables and parameters
    iiter = 0
    
    call get_eye(ntens,Eye)
    
    ! Determine starting point
    TOL_fs = max(ctrl%TOL/10.0_rk, ctrl%TOL * dabs(fs_trial))
    hgam = H_GAMMA * H_i
    sigma = stress_trial
    sin_phi_mob = sin_phi_mob_trial
    sin_psi_mob = sin_psi_mob_trial
    gammapss = gammapss0
    
    call df_dg_cone(sigma, ntens, m, m2, n, zeta, mat%Rf_eta_phi, sin_psi_mob, Eur, Ei, chi, mat%apex, gammapss)

    ddsdde_m = matmul(dds_dde, m)

    dl = fs_trial / (dot_product(n, ddsdde_m) - (zeta * hgam))
    stress = stress_trial - dl * ddsdde_m
    dgammapss = dl * hgam
    gammapss = gammapss0 + dgammapss
    
    ! Determine invariants and stresses to evaluate the yield function
    call roscoe_pq_voigt(ntens,stress,p,q)
    
    ! mobilised friciton angle and dilatancy angle
    sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)
    sin_psi_mob = get_mob_dilatancy_angle(sin_phi_mob, sin_phi_cs, mat%apex, Mcs, p, q)
    
    ! Evaluate yield function
    fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss)
    
    ! Newton-Raphson iteration loop
    do while (dabs(fs) > TOL_fs .and. iiter <= ctrl%MAXITER)
    
      sigma = stress
      call df_dg_cone(sigma, ntens, m, m2, n, zeta, mat%Rf_eta_phi, sin_psi_mob, Eur, Ei, chi, mat%apex, gammapss)

      ddsdde_m = matmul(dds_dde, m)
      
      Res = stress - (stress_trial - dl * ddsdde_m)
      Xi = Eye + dl * matmul(dds_dde, m2)
      
      ! Matrix inversion
      if (ntens == 4) then
        Xiinv = matinv4x4(Xi)
      else
        Xiinv = matinv6x6_gauss_jordan(Xi)
      end if
      
      ! Update plastic multiplier and stress
      ddl = (fs - dot_product(n,matmul(Res,Xiinv))) / (dot_product(n,matmul(ddsdde_m,Xiinv)) - (zeta * hgam))
      dl = dl + ddl
      stress = stress - matmul(Res+ddl*ddsdde_m, Xiinv)
      dgammapss = dl * hgam
      gammapss = gammapss0 + dgammapss
      
      ! Determine invariants and stresses to evaluate the yield function
      call roscoe_pq_voigt(ntens,stress,p,q)

      ! mobilised friciton angle and dilatancy angle
      sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)
      sin_psi_mob = get_mob_dilatancy_angle(sin_phi_mob, sin_phi_cs, mat%apex, Mcs, p, q)
      
      ! Evaluate yield function
      fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss)
      
      iiter = iiter + 1
    
    end do
    
  end subroutine return_mapping_yield_surface      
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> return mapping to the cone yield surface at failure (phi_mob = phi)
  !> Original verison (FCONO) by Leonardo José Cocco
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version (refactoring, modernizing)
  !>* 09.03.2026, J. Machacek - Precompute expensive tensor operations, use sine of angles directly
  !>* 01.06.2026, J. Machacek - Use mob_sin_phi/yield_function_fc; df_dg_cone interface (Rf_eta_phi)
  !                           - remove dead tangent D and unused dgammapss/h/i
  ! 
  subroutine return_mapping_failure_surface(stress_trial, ntens, fs_trial, mat, Eur, Ei, dds_dde, gammapss0, &
                                            gammapss, p_trial, q_trial, stress, p, q, sin_phi_cs, Mcs, fs, chi, &
                                            sin_phi_mob, sin_psi_mob, sin_phi_mob_trial, sin_psi_mob_trial)
    use compatibility_numgeo_, only: matinv4x4, matinv6x6_gauss_jordan, roscoe_pq_voigt, get_eye
    implicit none
  
    integer, intent(in) :: ntens
    real(rk), intent(in) :: stress_trial(ntens)
    real(rk), intent(in) :: fs_trial
    type(material_properties_ty_), intent(in) :: mat
    real(rk), intent(in) :: Eur
    real(rk), intent(in) :: Ei
    real(rk), intent(in) :: dds_dde(ntens,ntens)
    real(rk), intent(in) :: gammapss0
    real(rk), intent(in) :: p_trial
    real(rk), intent(in) :: q_trial
    real(rk), intent(in) :: sin_phi_cs
    real(rk), intent(in) :: Mcs
    real(rk), intent(in) :: chi
    real(rk), intent(in) :: sin_phi_mob_trial
    real(rk), intent(in) :: sin_psi_mob_trial
  
    real(rk), intent(out) :: stress(ntens)
    real(rk), intent(out) :: gammapss
    real(rk), intent(out) :: p
    real(rk), intent(out) :: q
    real(rk), intent(out) :: fs
    real(rk), intent(out) :: sin_phi_mob
    real(rk), intent(out) :: sin_psi_mob
  
    ! Local variables
    real(rk) :: TOL_fs, zeta
    real(rk) :: Eye(ntens,ntens)
    real(rk) :: sigma(ntens)
    real(rk) :: dl, ddl
    real(rk) :: Res(ntens)
    real(rk) :: Xi(ntens,ntens)
    real(rk) :: Xiinv(ntens,ntens)
    real(rk) :: m2(ntens,ntens), m(ntens), n(ntens)
    real(rk) :: ddsdde_m(ntens)
    
    type(controls_ty_) :: ctrl
  
    integer :: iiter
  
    ! Initialize variables and parameters
    iiter = 0
  
    call get_eye(ntens,Eye)
  
    ! Determine starting point
    sin_phi_mob = sin_phi_mob_trial
    sin_psi_mob = sin_psi_mob_trial
    TOL_fs = max(ctrl%TOL/10.0_rk, ctrl%TOL * dabs(fs_trial))
    sigma = stress_trial
    gammapss = gammapss0
  
    call df_dg_cone(sigma, ntens, m, m2, n, zeta, mat%Rf_eta_phi, sin_psi_mob, Eur, Ei, chi, mat%apex, gammapss)
    
    ddsdde_m = matmul(dds_dde, m)
  
    dl = fs_trial / (dot_product(n, ddsdde_m))
    stress = stress_trial - dl * ddsdde_m
  
    ! Determine invariants and stresses to evaluate the yield function
    call roscoe_pq_voigt(ntens,stress,p,q)

    ! mobilised friciton angle and dilatancy angle
    sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)
    sin_psi_mob = get_mob_dilatancy_angle(sin_phi_mob, sin_phi_cs, mat%apex, Mcs, p, q)
  
    ! Evaluate yield function
    fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss)
  
    ! Newton-Raphson iteration loop
    do while (dabs(fs) > TOL_fs .and. iiter <= ctrl%MAXITER)
  
      sigma = stress
      call df_dg_cone(sigma, ntens, m, m2, n, zeta, mat%Rf_eta_phi, sin_psi_mob, Eur, Ei, chi, mat%apex, gammapss)

      ddsdde_m = matmul(dds_dde, m)

      Res = stress - (stress_trial - dl * ddsdde_m)
      Xi = Eye + dl * matmul(dds_dde, m2)
  
      ! Matrix inversion
      if (ntens == 4) then
        Xiinv = matinv4x4(Xi)
      else
        Xiinv = matinv6x6_gauss_jordan(Xi)
      end if
  
      ! Update plastic multiplier and stress
      ddl = (fs - dot_product(n, matmul(Res, Xiinv))) / (dot_product(n, matmul(ddsdde_m, Xiinv)))
      dl = dl + ddl
      stress = stress - matmul(Res + ddl * ddsdde_m, Xiinv)
      gammapss = gammapss0
  
      ! Determine invariants and stresses to evaluate the yield function
      call roscoe_pq_voigt(ntens,stress,p,q)

      ! mobilised friciton angle and dilatancy angle
      sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)
      sin_psi_mob = get_mob_dilatancy_angle(sin_phi_mob, sin_phi_cs, mat%apex, Mcs, p, q)
  
      ! Evaluate yield function
      fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss)
  
      iiter = iiter + 1
  
    end do
  
  end subroutine return_mapping_failure_surface 
    
                   
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> return mapping to the cap yield surface  
  !> Original verison (RTAPA) by Leonardo José Cocco
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version (refactoring, modernizing)
  !>* 09.03.2026, J. Machacek - Precompute expensive tensor operations, use sine of angles directly
  !>* 01.06.2026, J. Machacek - Use yield_function_fc; df_dg_cap interface (apex)
  !                           - remove dead tangent D and unused S/i
  ! 
  subroutine return_mapping_cap_surface(stress_trial, ntens, fc_trial, mat, Eur, Ei, dds_dde, pp0, pp, &
                                        p_trial, q_trial, stress, p, q, chi, Mcs, fc, hc)
    use compatibility_numgeo_, only: matinv4x4, matinv6x6_gauss_jordan, roscoe_pq_voigt, get_eye
    implicit none
  
    integer, intent(in) :: ntens
  
    real(rk), intent(in) :: stress_trial(ntens)
    real(rk), intent(in) :: fc_trial
    type(material_properties_ty_), intent(in) :: mat
    real(rk), intent(in) :: Eur
    real(rk), intent(in) :: Ei
    real(rk), intent(in) :: dds_dde(ntens, ntens)
    real(rk), intent(in) :: pp0
    real(rk), intent(in) :: p_trial
    real(rk), intent(in) :: q_trial
    real(rk), intent(in) :: chi
    real(rk), intent(in) :: Mcs
    real(rk), intent(in) :: hc
  
    real(rk), intent(out) :: stress(ntens)
    real(rk), intent(out) :: pp
    real(rk), intent(out) :: p
    real(rk), intent(out) :: q
    real(rk), intent(out) :: fc
  
    ! Local variables
    real(rk) :: zetac
    real(rk) :: TOL_fc
    real(rk) :: dpp
    real(rk) :: Eye(ntens, ntens)
    real(rk) :: sigma(ntens)
    real(rk) :: dlc, ddlc
    real(rk) :: Res(ntens)
    real(rk) :: Xi(ntens, ntens)
    real(rk) :: Xiinv(ntens, ntens)
    real(rk) :: w(ntens), w2(ntens, ntens), u(ntens)
    real(rk) :: ddsdde_w(ntens)
    
    type(controls_ty_) :: ctrl
  
    integer :: iiter
  
    ! Initialize variables and parameters
    iiter = 0
  
    call get_eye(ntens,Eye)
  
    ! Determine starting point
    TOL_fc = max(ctrl%TOL/10.0_rk, ctrl%TOL * dabs(fc_trial))
    sigma = stress_trial
    pp = pp0
  
    call df_dg_cap(sigma, ntens, w, w2, u, zetac, chi, mat%alpha, pp, mat%apex)

    ddsdde_w = matmul(dds_dde, w)

    dlc = fc_trial / (dot_product(u, ddsdde_w) - (zetac * hc))
    stress = stress_trial - dlc * ddsdde_w
    dpp = dlc * hc
    pp = pp0 + dpp
  
    ! Determine invariants and stresses to evaluate the yield function
    call roscoe_pq_voigt(ntens,stress,p,q)

    ! Evaluate cap yield function
    fc = yield_function_fc(p, q, pp, chi, mat%alpha, mat%apex)
  
    ! Newton-Raphson iteration loop
    do while (dabs(fc) > TOL_fc .and. iiter <= ctrl%MAXITER)
  
      sigma = stress
      call df_dg_cap(sigma, ntens, w, w2, u, zetac, chi, mat%alpha, pp, mat%apex)
      
      ddsdde_w = matmul(dds_dde, w)
    
      Res = stress - (stress_trial - dlc * ddsdde_w)
      Xi = Eye + dlc * matmul(dds_dde, w2)
  
      ! Matrix inversion
      if (ntens == 4) then
        Xiinv = matinv4x4(Xi)
      else
        Xiinv = matinv6x6_gauss_jordan(Xi)
      end if
  
      ! Update plastic multiplier and stress
      ddlc = (fc - dot_product(u, matmul(Res, Xiinv))) / (dot_product(u,matmul(ddsdde_w, Xiinv)) - (zetac * hc))
      dlc = dlc + ddlc
      stress = stress - matmul(Res + ddlc * ddsdde_w, Xiinv)
  
      ! Determine invariants and stresses to evaluate the yield function
      call roscoe_pq_voigt(ntens,stress,p,q)

      ! Update state variables
      dpp = dlc * hc
      pp = pp0 + dpp
  
      ! Evaluate cap yield function
      fc = yield_function_fc(p, q, pp, chi, mat%alpha, mat%apex)
  
      iiter = iiter + 1
  
    end do
  
  end subroutine return_mapping_cap_surface
  
                   
                   
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> Mixed return mapping to both cone and cap yield surfaces  
  !> Original verison (RMIXTO) by Leonardo José Cocco
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version (refactoring, modernizing)
  !>* 09.03.2026, J. Machacek - Precompute expensive tensor operations, use sine of angles directly
  !>* 01.06.2026, J. Machacek - Use mob_sin_phi/yield_function_fc and the H_GAMMA constant; df_dg_cone/df_dg_cap interfaces
  !                           - remove dead tangent D and unused S/i
  !>* 01.07.2026, J. Machacek - Hardening enhancement H_i of the HS-Brick extension: dgammapss = dl*H_GAMMA*H_i (Eq. 22 in [5]);
  !                           - the volumetric mechanism receives H_i via the pre-scaled hc (Eq. 23 in [5])
  ! 
  subroutine return_mapping_mixed_surface(stress_trial, ntens, fs_trial, mat, sin_phi_mob, sin_psi_mob, &
                    Eur, Ei, dds_dde, gammapss0, gammapss, stress, p, q, chi, sin_phi_cs, Mcs, fs, fc_trial, &
                    fc, pp0, pp, p_trial, q_trial, hc, sin_phi_mob_trial, sin_psi_mob_trial, H_i)
    use compatibility_numgeo_, only: matinv4x4, matinv6x6_gauss_jordan, roscoe_pq_voigt, get_eye
    implicit none
  
    integer, intent(in) :: ntens
  
    real(rk), intent(in) :: stress_trial(ntens)
    real(rk), intent(in) :: fs_trial
    type(material_properties_ty_), intent(in) :: mat
    real(rk), intent(in) :: Eur
    real(rk), intent(in) :: Ei
    real(rk), intent(in) :: dds_dde(ntens, ntens)
    real(rk), intent(in) :: gammapss0
    real(rk), intent(in) :: chi
    real(rk), intent(in) :: sin_phi_cs
    real(rk), intent(in) :: Mcs
    real(rk), intent(in) :: fc_trial
    real(rk), intent(in) :: pp0
    real(rk), intent(in) :: p_trial
    real(rk), intent(in) :: q_trial
    real(rk), intent(in) :: hc
    real(rk), intent(in) :: sin_phi_mob_trial
    real(rk), intent(in) :: sin_psi_mob_trial
    real(rk), intent(in) :: H_i   ! hardening enhancement factor of the HS-Brick extension (Eq. 24 in [5])
  
    real(rk), intent(out) :: stress(ntens)
    real(rk), intent(out) :: sin_phi_mob
    real(rk), intent(out) :: sin_psi_mob
    real(rk), intent(out) :: gammapss
    real(rk), intent(out) :: p
    real(rk), intent(out) :: q
    real(rk), intent(out) :: fs
    real(rk), intent(out) :: fc
    real(rk), intent(out) :: pp
  
    ! Local variables
    real(rk) :: zeta, zetac
    real(rk) :: TOL_fs, TOL_fc
    real(rk) :: hgam   ! H_i-enhanced hardening factor: hgam = H_GAMMA*H_i
    real(rk) :: dgammapss, dpp
    real(rk) :: Eye(ntens, ntens)
    real(rk) :: sigma(ntens)
    real(rk) :: dl, ddl, dlc, ddlc
    real(rk) :: Res(ntens)
    real(rk) :: Xi(ntens, ntens)
    real(rk) :: Xiinv(ntens, ntens)
    real(rk) :: Omega11, Omega12, Omega21, Omega22
    real(rk) :: Omegafs, Omegafc
    real(rk) :: m2(ntens,ntens), m(ntens), n(ntens)
    real(rk) :: w(ntens), w2(ntens, ntens), u(ntens)
    real(rk) :: ddsdde_m(ntens), ddsdde_w(ntens)
    
    type(controls_ty_) :: ctrl
  
    integer :: iiter
  
    ! Initialize variables and parameters
    iiter = 0
  
    call get_eye(ntens,Eye)
  
    ! Determine starting point
    TOL_fs = max(ctrl%TOL/10.0_rk, ctrl%TOL * dabs(fs_trial))
    TOL_fc = max(ctrl%TOL/10.0_rk, ctrl%TOL * dabs(fc_trial))
    hgam = H_GAMMA * H_i
    sigma = stress_trial
    sin_phi_mob = sin_phi_mob_trial
    sin_psi_mob = sin_psi_mob_trial
    gammapss = gammapss0
  
    call df_dg_cone(sigma, ntens, m, m2, n, zeta, mat%Rf_eta_phi, sin_psi_mob, Eur, Ei, chi, mat%apex, gammapss)
  
    pp = pp0
  
    call df_dg_cap(sigma, ntens, w, w2, u, zetac, chi, mat%alpha, pp, mat%apex)
  
  
    ! Compute coupling matrix components
    ddsdde_m = matmul(dds_dde, m)
    ddsdde_w = matmul(dds_dde, w)
    Omega11 = -(zeta * hgam) + dot_product(n, ddsdde_m)
    Omega12 = dot_product(n, ddsdde_w)
    Omega21 = dot_product(u, ddsdde_m)
    Omega22 = -(zetac * hc) + dot_product(u, ddsdde_w)
  
    ! Initial plastic multipliers from 2x2 system
    dl = (fs_trial * Omega22 - fc_trial * Omega12) / (Omega11 * Omega22 - Omega12 * Omega21)
    dlc = (fc_trial * Omega11 - fs_trial * Omega21) / (Omega11 * Omega22 - Omega12 * Omega21)
  
    stress = stress_trial - (dl * ddsdde_m + dlc * ddsdde_w)
    dgammapss = dl * hgam
    dpp = dlc * hc
    gammapss = gammapss0 + dgammapss
    pp = pp0 + dpp
  
    ! Determine invariants and stresses to evaluate the yield functions
    call roscoe_pq_voigt(ntens,stress,p,q)

    ! mobilised friciton angle and dilatancy angle
    sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)
    sin_psi_mob = get_mob_dilatancy_angle(sin_phi_mob, sin_phi_cs, mat%apex, Mcs, p, q)
  
    ! Evaluate yield functions
    fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss)
  
    fc = yield_function_fc(p, q, pp, chi, mat%alpha, mat%apex)
  
    ! Newton-Raphson iteration loop
    do while ((dabs(fs) > TOL_fs .or. dabs(fc) > TOL_fc) .and. iiter <= ctrl%MAXITER)
  
      sigma = stress
      call df_dg_cone(sigma, ntens, m, m2, n, zeta, mat%Rf_eta_phi, sin_psi_mob, Eur, Ei, chi, mat%apex, gammapss)
      call df_dg_cap(sigma, ntens, w, w2, u, zetac, chi, mat%alpha, pp, mat%apex)
      
      ddsdde_m = matmul(dds_dde, m)
      ddsdde_w = matmul(dds_dde, w)
  
      Res = stress - (stress_trial - dl * ddsdde_m - dlc * ddsdde_w)
      Xi = Eye + dl * matmul(dds_dde, m2) + dlc * matmul(dds_dde, w2)
  
      ! Matrix inversion
      if (ntens == 4) then
        Xiinv = matinv4x4(Xi)
      else
        Xiinv = matinv6x6_gauss_jordan(Xi)
      end if
  
      ! Compute coupling matrix components
      Omega11 = dot_product(n, matmul(ddsdde_m, Xiinv)) - (zeta * hgam)
      Omega12 = dot_product(n, matmul(ddsdde_w, Xiinv))
      Omega21 = dot_product(u, matmul(ddsdde_m, Xiinv))
      Omega22 = dot_product(u, matmul(ddsdde_w, Xiinv)) - (zetac * hc)
  
      Omegafs = fs - dot_product(Res, matmul(Xiinv, n))
      Omegafc = fc - dot_product(Res, matmul(Xiinv, u))
  
      ! Update plastic multipliers from 2x2 system
      ddl = (Omegafs * Omega22 - Omegafc * Omega12) / (Omega11 * Omega22 - Omega12 * Omega21)
      ddlc = (Omegafc * Omega11 - Omegafs * Omega21) / (Omega11 * Omega22 - Omega12 * Omega21)
      dl = dl + ddl
      dlc = dlc + ddlc
      stress = stress - matmul(Res + ddl*ddsdde_m + ddlc*ddsdde_w, Xiinv)
  
      ! Determine invariants and stresses to evaluate the yield functions
      call roscoe_pq_voigt(ntens,stress,p,q)

      ! mobilised friciton angle and dilatancy angle
      sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)
      sin_psi_mob = get_mob_dilatancy_angle(sin_phi_mob, sin_phi_cs, mat%apex, Mcs, p, q)
    
      ! Update state variables
      dgammapss = dl * hgam
      dpp = dlc * hc
      gammapss = gammapss0 + dgammapss
      pp = pp0 + dpp
  
      ! Evaluate yield functions
      fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss)
  
      fc = yield_function_fc(p, q, pp, chi, mat%alpha, mat%apex)
  
      iiter = iiter + 1
  
    end do
  
  end subroutine return_mapping_mixed_surface
          
                   
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> Mixed return mapping to both yield surfaces at failure (phi_mob = mat%phi) 
  !> Original verison (FTAPA) by Leonardo José Cocco
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version (refactoring, modernizing)
  !>* 09.03.2026, J. Machacek - Precompute expensive tensor operations, use sine of angles directly
  !>* 01.06.2026, J. Machacek - Use mob_sin_phi/yield_function_fc; df_dg_cone/df_dg_cap interfaces
  !                           - remove dead tangent D and unused dgammapss/h/S/i
  ! 
  subroutine return_mapping_mixed_failure_surface(stress_trial, ntens, fs_trial, mat, Eur, Ei, &
                   dds_dde, gammapss0, gammapss, stress, p, q, chi, sin_phi_cs, Mcs, fs, sin_phi_mob, sin_psi_mob, &
                   fc_trial, fc, pp0, pp, p_trial, q_trial, hc, sin_phi_mob_trial, sin_psi_mob_trial)
    use compatibility_numgeo_, only: matinv4x4, matinv6x6_gauss_jordan, roscoe_pq_voigt, get_eye
    implicit none
  
    integer(ik), intent(in) :: ntens
  
    real(rk), intent(in) :: stress_trial(ntens)
    real(rk), intent(in) :: fs_trial
    type(material_properties_ty_), intent(in) :: mat
    real(rk), intent(in) :: Eur
    real(rk), intent(in) :: Ei
    real(rk), intent(in) :: dds_dde(ntens, ntens)
    real(rk), intent(in) :: gammapss0
    real(rk), intent(in) :: chi
    real(rk), intent(in) :: sin_phi_cs
    real(rk), intent(in) :: Mcs
    real(rk), intent(in) :: fc_trial
    real(rk), intent(in) :: pp0
    real(rk), intent(in) :: p_trial
    real(rk), intent(in) :: q_trial
    real(rk), intent(in) :: hc
    real(rk), intent(in) :: sin_phi_mob_trial
    real(rk), intent(in) :: sin_psi_mob_trial
  
    real(rk), intent(out) :: stress(ntens)
    real(rk), intent(out) :: gammapss
    real(rk), intent(out) :: p
    real(rk), intent(out) :: q
    real(rk), intent(out) :: fs
    real(rk), intent(out) :: sin_phi_mob
    real(rk), intent(out) :: sin_psi_mob
    real(rk), intent(out) :: fc
    real(rk), intent(out) :: pp
  
    ! Local variables
    real(rk) :: zeta, zetac
    real(rk) :: TOL_fs, TOL_fc
    real(rk) :: dpp
    real(rk) :: Eye(ntens, ntens)
    real(rk) :: sigma(ntens)
    real(rk) :: dl, ddl, dlc, ddlc
    real(rk) :: Res(ntens)
    real(rk) :: Xi(ntens, ntens)
    real(rk) :: Xiinv(ntens, ntens)
    real(rk) :: Omega11, Omega12, Omega21, Omega22
    real(rk) :: Omegafs, Omegafc
    real(rk) :: m2(ntens,ntens), m(ntens), n(ntens)
    real(rk) :: w(ntens), w2(ntens, ntens), u(ntens)
    real(rk) :: ddsdde_m(ntens), ddsdde_w(ntens)
    
    type(controls_ty_) :: ctrl
  
    integer(ik) :: iiter
  
    ! Initialize variables and parameters
    iiter = 0
  
    call get_eye(ntens,Eye)
  
    ! Determine starting point
    TOL_fs = max(ctrl%TOL/10.0_rk, ctrl%TOL * dabs(fs_trial))
    TOL_fc = max(ctrl%TOL/10.0_rk, ctrl%TOL * dabs(fc_trial))
    sin_phi_mob = sin_phi_mob_trial
    sin_psi_mob = sin_psi_mob_trial
    sigma = stress_trial
    gammapss = gammapss0
  
    call df_dg_cone(sigma, ntens, m, m2, n, zeta, mat%Rf_eta_phi, sin_psi_mob, Eur, Ei, chi, mat%apex, gammapss)
  
    pp = pp0
  
    call df_dg_cap(sigma, ntens, w, w2, u, zetac, chi, mat%alpha, pp, mat%apex)
  
    ! Compute coupling matrix components (no hardening term for cone at failure)
    ddsdde_m = matmul(dds_dde, m)
    ddsdde_w = matmul(dds_dde, w)
    Omega11 = dot_product(n, ddsdde_m)
    Omega12 = dot_product(n, ddsdde_w)
    Omega21 = dot_product(u, ddsdde_m)
    Omega22 = -(zetac * hc) + dot_product(u, ddsdde_w)
  
    ! Initial plastic multipliers from 2x2 system
    dl = (fs_trial * Omega22 - fc_trial * Omega12) / (Omega11 * Omega22 - Omega12 * Omega21)
    dlc = (fc_trial * Omega11 - fs_trial * Omega21) / (Omega11 * Omega22 - Omega12 * Omega21)
  
    stress = stress_trial - (dl * ddsdde_m + dlc * ddsdde_w)
    dpp = dlc * hc
    pp = pp0 + dpp
  
    ! Determine invariants and stresses to evaluate the yield functions
    call roscoe_pq_voigt(ntens,stress,p,q)
    
    ! mobilised friciton angle and dilatancy angle
    sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)
    sin_psi_mob = get_mob_dilatancy_angle(sin_phi_mob, sin_phi_cs, mat%apex, Mcs, p, q)
  
    ! Evaluate yield functions
    fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss)
    fc = yield_function_fc(p, q, pp, chi, mat%alpha, mat%apex)
  
    ! Newton-Raphson iteration loop
    do while ((dabs(fs) > TOL_fs .or. dabs(fc) > TOL_fc) .and. iiter <= ctrl%MAXITER)
  
      sigma = stress
      call df_dg_cone(sigma, ntens, m, m2, n, zeta, mat%Rf_eta_phi, sin_psi_mob, Eur, Ei, chi, mat%apex, gammapss)
      call df_dg_cap(sigma, ntens, w, w2, u, zetac, chi, mat%alpha, pp, mat%apex)
  
      ddsdde_m = matmul(dds_dde, m)
      ddsdde_w = matmul(dds_dde, w)
    
      Res = stress - (stress_trial - dl * ddsdde_m - dlc * ddsdde_w)
      Xi = Eye + dl * matmul(dds_dde, m2) + dlc * matmul(dds_dde, w2)
  
      ! Matrix inversion
      if (ntens == 4) then
        Xiinv = matinv4x4(Xi)
      else
        Xiinv = matinv6x6_gauss_jordan(Xi)
      end if

      ! Compute coupling matrix components (no hardening term for cone at failure)
      Omega11 = dot_product(n, matmul(ddsdde_m, Xiinv))
      Omega12 = dot_product(n, matmul(ddsdde_w, Xiinv))
      Omega21 = dot_product(u, matmul(ddsdde_m, Xiinv))
      Omega22 = dot_product(u, matmul(ddsdde_w, Xiinv)) - (zetac * hc)
  
      Omegafs = fs - dot_product(Res, matmul(Xiinv, n))
      Omegafc = fc - dot_product(Res, matmul(Xiinv, u))
  
      ! Update plastic multipliers from 2x2 system
      ddl = (Omegafs * Omega22 - Omegafc * Omega12) / (Omega11 * Omega22 - Omega12 * Omega21)
      ddlc = (Omegafc * Omega11 - Omegafs * Omega21) / (Omega11 * Omega22 - Omega12 * Omega21)
      dl = dl + ddl
      dlc = dlc + ddlc
      stress = stress - matmul(Res + ddl * ddsdde_m + ddlc * ddsdde_w, Xiinv)
  
      ! Determine invariants and stresses to evaluate the yield functions
      call roscoe_pq_voigt(ntens,stress,p,q)
      
      ! mobilised friciton angle and dilatancy angle
      sin_phi_mob = mob_sin_phi(p, q, chi, mat%apex)
      sin_psi_mob = get_mob_dilatancy_angle(sin_phi_mob, sin_phi_cs, mat%apex, Mcs, p, q)
  
      ! Update state variables (gammapss remains constant at failure)
      dpp = dlc * hc
      gammapss = gammapss0
      pp = pp0 + dpp
  
      ! Evaluate yield functions
      fs = yield_function_fs(q, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob, gammapss)
      fc = yield_function_fc(p, q, pp, chi, mat%alpha, mat%apex)
  
      iiter = iiter + 1
  
    end do
  
  end subroutine return_mapping_mixed_failure_surface

  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> Calculate HS yield function for the Matsuoka-Nakai yield function (Eq. 7.54 in Benz [3])
  !> The present implementation differs from the Equation provided in [3] in that it 
  !> the whole yield function is multiplied by the inverse of the mobilisation factor. 
  !> The mobilisation factor entails a singularity in its definition, multiplication by its inverse
  !> has proven to be a robust countermeasure [4]
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version
  !
  function yield_function_fs(q, Ei, Eur, Rf, sin_phi, sin_phi_mob, gammapss0) result(fs)
    implicit none
    real(rk), intent(in) :: q
    real(rk), intent(in) :: Ei
    real(rk), intent(in) :: Eur
    real(rk), intent(in) :: Rf
    real(rk), intent(in) :: sin_phi
    real(rk), intent(in) :: sin_phi_mob
    real(rk), intent(in) :: gammapss0
    real(rk) :: fs

    real(rk) :: eta_phi, eta_phi_mob
    real(rk) :: mobilization_factor
  
    ! Stress ratio terms: (1 - sin(angle)) / sin(angle)
    eta_phi  = (1.0_rk - sin_phi)  / sin_phi
    eta_phi_mob = (1.0_rk - sin_phi_mob) / sin_phi_mob
    mobilization_factor = (eta_phi_mob - Rf * eta_phi) * sin_phi_mob / (1.0_rk - sin_phi_mob)
  
    fs = 1.5_rk * q / Ei - (1.5_rk * q / Eur + gammapss0) * mobilization_factor
  
  end function yield_function_fs


  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 01.06.2026
  !
  !> Mobilised friction angle (sine) from the Roscoe invariants p, q and the
  !> Lode-dependent shape factor chi: sin(phi_mob) = 3 q / (6 chi (p+apex) + q)
  !
  !>### History
  !>* 01.06.2026, J. Machacek - Initial version (extracted from repeated inline expression)
  !
  pure function mob_sin_phi(p, q, chi, apex) result(sin_phi_mob)
    implicit none
    real(rk), intent(in) :: p
    real(rk), intent(in) :: q
    real(rk), intent(in) :: chi
    real(rk), intent(in) :: apex
    real(rk) :: sin_phi_mob

    sin_phi_mob = 3.0_rk * q / (6.0_rk * chi * (p + apex) + q)

  end function mob_sin_phi


  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 01.06.2026
  !
  !> Cap yield function of the Hardening Soil model (Matsuoka-Nakai).
  !> Companion to yield_function_fs: fc = (q/(chi*alpha))^2 + (p+apex)^2 - (pp+apex)^2
  !
  !>### History
  !>* 01.06.2026, J. Machacek - Initial version (extracted from repeated inline expression)
  !
  pure function yield_function_fc(p, q, pp, chi, alpha, apex) result(fc)
    implicit none
    real(rk), intent(in) :: p
    real(rk), intent(in) :: q
    real(rk), intent(in) :: pp
    real(rk), intent(in) :: chi
    real(rk), intent(in) :: alpha
    real(rk), intent(in) :: apex
    real(rk) :: fc

    fc = (q / (chi*alpha))**2 + (p + apex)**2 - (pp + apex)**2

  end function yield_function_fc


  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 01.06.2026
  !
  !> Stress-dependent stiffness factor ((sigma3+apex)/(pref+apex))**m.
  !> Evaluated once per stress point and reused for Ei, Eur and hc, so that the
  !> expensive power is computed a single time instead of two or three times.
  !
  !>### History
  !>* 01.06.2026, J. Machacek - Initial version
  !
  pure function stiffness_factor(sigma3, mat) result(fac)
    implicit none
    real(rk), intent(in) :: sigma3
    type(material_properties_ty_), intent(in) :: mat
    real(rk) :: fac

    fac = ((sigma3 + mat%apex) * mat%inv_pref_apex) ** mat%m

  end function stiffness_factor
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 27.12.2025
  !
  !> Returns the elastic tangent operator 
  !
  !>### History
  !>* 27.12.2025, J. Machacek - Initial version
  !>* 09.03.2026, J. Machacek - Interface takes apex as argument
  !
  subroutine enforce_vertex(p,q,stress,apex,ntens)
    implicit none
    
    integer, intent(in) :: ntens
    real(rk), intent(inout) :: p
    real(rk), intent(inout) :: q
    real(rk), intent(inout) :: stress(ntens)
    real(rk), intent(in) :: apex
    
    p = -apex
    q = 0.0_rk
    stress = 0.0_rk
    stress(1:3) = -p
           
  end subroutine enforce_vertex
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> Returns the elastic tangent operator 
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version
  !
  function get_elastic_jacobian(E,nu,ntens) result(dds_dde)
    implicit none
    
    real(rk), intent(in) :: E
    real(rk), intent(in) :: nu
    integer(ik), intent(in) :: ntens
    real(rk), dimension(ntens,ntens) :: dds_dde
    
    real(rk) :: lambda, mu
    integer(ik) :: i, j
    
    dds_dde = 0.0_rk
    
    lambda = E*nu / ((1.0_rk - 2.0_rk*nu)*(1.0_rk + nu))
    mu = E / (2.0_rk*(1.0_rk + nu))
    
    do i = 1, 3
      do j = 1, 3
        dds_dde(j,i) = lambda
      end do
      dds_dde(i,i) = lambda + 2.0_rk*mu
    end do
    
    do i = 4, ntens
      dds_dde(i,i) = mu
    end do
      
  end function get_elastic_jacobian

  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 23.12.2025
  !
  !> Calculates the Lode angle dependent shape factor chi for deviatoric yield surface rounding.
  !
  !>### History
  !>* 23.12.2025, J. Machacek - Initial version
  !>* 06.03.2026, J. Machacek - Add safeguards for acos argument to avoid NaN
  !
  pure subroutine lode_shape_factor(J2, J3, sin_phi, chi)
    use precision_, only: rk
    implicit none
    
    real(rk), intent(in) :: J2          ! Second deviatoric stress invariant
    real(rk), intent(in) :: J3          ! Third deviatoric stress invariant
    real(rk), intent(in) :: sin_phi     ! Friction angle (sine)
    real(rk), intent(out) :: chi        ! Lode angle dependent shape factor
    
    real(rk) :: sin3theta, delta2, denom, acos_arg
    real(rk) :: sqrt3, pi_third, one_sixth, delta, theta, upsilon
    
    ! Constants
    sqrt3 = sqrt(3.0_rk)
    pi_third = pi / 3.0_rk
    one_sixth = 1.0_rk / 6.0_rk
    
    ! Lode angle from sin(3*theta) = -3*sqrt(3)/2 * J3 / J2^(3/2)
    if (abs(J2) <= 1.0e-6_rk) then
      theta = 0.0_rk
    else
      sin3theta = -1.5_rk * sqrt3 * J3 / (J2 * sqrt(J2))
      ! Clamp to [-1, 1] to avoid NaN from asin
      if (sin3theta >= 1.0_rk) then
        theta = pi / 6.0_rk  ! asin(1)/3
      else if (sin3theta <= -1.0_rk) then
        theta = -pi / 6.0_rk  ! asin(-1)/3
      else
        theta = asin(sin3theta) / 3.0_rk
      end if
    end if
    
    ! Shape parameter delta from friction angle
    delta = (3.0_rk - sin_phi) / (3.0_rk + sin_phi)
    
    ! Precompute delta^2 and denominator term
    delta2 = delta * delta
    denom = delta2 - delta + 1.0_rk
    
    ! Argument for acos in upsilon calculation
    acos_arg = -1.0_rk + 13.5_rk * delta2 * (1.0_rk - delta)**2 / (denom * denom * denom) * sin(3.0_rk * theta)**2
    
    ! Clamp acos argument to [-1, 1]
    acos_arg = max(-1.0_rk, min(1.0_rk, acos_arg))
    
    ! Upsilon calculation (different branches for theta <= 0 and theta > 0)
    if (theta <= 0.0_rk) then
      upsilon = one_sixth * acos(acos_arg)
    else
      upsilon = pi_third - one_sixth * acos(acos_arg)
    end if
    
    ! Lode angle dependent shape factor chi
    chi = sqrt3 * delta / (2.0_rk * sqrt(denom) * cos(upsilon))
    
  end subroutine lode_shape_factor
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 23.12.2025
  !
  !> Calculate mobilized dilatancy angle
  !
  !>### History
  !>* 23.12.2025, J. Machacek - Initial version
  !>* 09.03.2026, J. Machacek - Add safeguards (limit to [-1,1])
  !>* 01.06.2026, J. Machacek - Interface: pass precomputed apex instead of (phi, c) - removes a dtan per call
  !
  pure function get_mob_dilatancy_angle(sin_phi_mob, sin_phi_cs, apex, Mcs, p, q) result(sin_psi_mob)
    implicit none
    real(rk), intent(in) :: sin_phi_mob
    real(rk), intent(in) :: sin_phi_cs
    real(rk), intent(in) :: apex
    real(rk), intent(in) :: Mcs
    real(rk), intent(in) :: p
    real(rk), intent(in) :: q

    real(rk) :: sin_psi_mob
    
    real(rk) :: eta
    real(rk) :: pcsp
    real(rk) :: denom
    real(rk), parameter :: LIM = 1.0_rk - 1e-12_rk
    
    if (sin_phi_mob - sin_phi_cs >= 0.0_rk) then
      
      denom = 1.0_rk - sin_phi_mob * sin_phi_cs
      if (abs(denom) < 1.0e-12_rk) denom = sign(1.0e-12_rk, denom)
      sin_psi_mob = (sin_phi_mob - sin_phi_cs) / denom
      
    else
      
      eta = dabs(q / (p + apex))
      denom = Mcs * sin_phi_mob * (1.0_rk - sin_phi_cs)
      if (abs(denom) < 1.0e-12_rk) denom = sign(1.0e-12_rk, denom)
      
      ! Protect dlog from negative inputs during extreme trial overshoots
      pcsp = abs((eta * sin_phi_cs * (1.0_rk - sin_phi_mob)) / denom)
      pcsp = max(1.0e-12_rk, pcsp)
      
      sin_psi_mob = -1.0_rk/10.0_rk * ( Mcs * dexp(1.0_rk/15.0_rk*dlog(pcsp)) - eta )
      
    end if
    
    ! Prevent the flow potential from inverting in df_dg_cone
    sin_psi_mob = max(-LIM, min(LIM, sin_psi_mob))
    
  end function get_mob_dilatancy_angle
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek
  !> date: 13.08.2022
  !
  !> Pass material properties into derived type mat
  !
  !>### History
  !>* 13.08.2022, J. Machacek - Initial version
  !>* 01.06.2026, J. Machacek - Precompute sin_phi_cs, eta_phi, Rf_eta_phi, inv_pref_apex; reuse eta_phi in phi_mob_lim
  !>* 01.07.2026, J. Machacek - HS-Brick: read gamma07/G0ref (props 15/16), precompute Gur_ref, E0fac, Gm_max, exp_hi
  !                           - and the brick string properties; guard nprops, G0ref >= Gur_ref and gamma07 > 0
  !
  subroutine material_collect_properties(self,props,nprops)
    use precision_, only: rk, ik
    use compatibility_numgeo_, only: pi
    implicit none
  
    integer(ik), intent(in) :: nprops
    real(rk), dimension(nprops), intent(in) :: props
    class(material_properties_ty_), intent(inout) :: self
    
    if (nprops < 16) then
      error stop "hardening_soil_MN_bricks: at least 16 material properties required (props(15)=gamma07, props(16)=G0ref)"
    end if
     
    self%E50 = props(1)
    self%Eoed = props(2)
    self%Eur = props(3)
    self%m = props(4)
    self%c = props(5)
    self%phi = props(6)*pi/180.0_rk
    self%psi = props(7)*pi/180.0_rk
    self%nu = props(8)
    self%pref = props(9)
    self%K0nc = props(10)
    self%Rf = props(11)
    self%Ei = props(12)
    self%alpha = props(13)
    self%Hpp = props(14)
    self%gamma07 = props(15)
    self%G0 = props(16)
    
    self%ctan_phi = (1.0_rk/dtan(self%phi))
    self%sin_phi = dsin(self%phi)
    self%sin_psi = dsin(self%psi)
    self%Mc = 6.0_rk*self%sin_phi/(3.0_rk-self%sin_phi)
    
    self%apex = self%c * self%ctan_phi
    
    ! Precomputed constants used in the hot loops (added 01.06.2026, J. Machacek)
    self%sin_phi_cs    = (self%sin_phi - self%sin_psi) / (1.0_rk - self%sin_phi*self%sin_psi)
    self%eta_phi       = (1.0_rk - self%sin_phi) / self%sin_phi
    self%Rf_eta_phi    = self%Rf * self%eta_phi
    self%inv_pref_apex = 1.0_rk / (self%pref + self%apex)
    
    self%Ks = self%Eur/(3.0_rk*(1.0_rk-2.0_rk*self%nu))
    self%Kc = self%Eoed/(3.0_rk*(1.0_rk-2.0_rk*self%nu))
    
    ! limit mobilised friciton angle
    self%phi_mob_lim = 1.0_rk / (1.0_rk + self%Rf_eta_phi)
    
    ! BRICK small-strain extension (added 01.07.2026, J. Machacek)
    self%E0fac   = 2.0_rk*(1.0_rk + self%nu)
    self%Gur_ref = self%Eur / self%E0fac
    
    if (self%G0 < self%Gur_ref) then
      error stop "hardening_soil_MN_bricks: G0ref (props(16)) must not be smaller than Gur_ref = Eur_ref/(2(1+nu))"
    end if
    if (self%G0 > self%Gur_ref .and. self%gamma07 <= 0.0_rk) then
      error stop "hardening_soil_MN_bricks: gamma07 (props(15)) must be positive"
    end if
    
    self%Gm_max = self%G0 / self%Gur_ref
    self%exp_hi = 1.0_rk + self%Eur / (2.0_rk*self%E50)
    
    call brick_string_properties(self%gamma07, self%G0, self%Gur_ref, self%sl, self%snbp)
  
  end subroutine material_collect_properties
  
  
  !  
  ! BRICK small-strain extension (HS-Brick, Cudny & Truty [5])
  !
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 01.07.2026
  !
  !> Compute string lengths sl and stiffness proportions snbp of the NBRICKS bricks. The discretisation
  !> is automatic, based on the Santos & Correia / Hardin-Drnevich S-curve with the HSS parameters
  !> gamma07 and G0ref (see Fig. 4 in [5]): the stiffness range (G0-Gur)/G0 is split into NBRICKS equal
  !> steps and the string length of each brick is the shear strain invariant at the mid-height of its step.
  !> For G0 = Gur all string lengths and stiffness proportions vanish (degeneration to the base HS model).
  !> Original verison (StringProps_SC) kindly provided by M. Cudny
  !
  !>### History
  !>* 01.07.2026, J. Machacek - Initial version (refactoring, modernizing)
  !
  subroutine brick_string_properties(gamma07, G0, Gur, sl, snbp)
    implicit none
    
    real(rk), intent(in) :: gamma07       ! shear strain at G = 0.722 G0
    real(rk), intent(in) :: G0            ! small-strain reference shear modulus
    real(rk), intent(in) :: Gur           ! minimal reference shear modulus (all bricks active)
    real(rk), intent(out) :: sl(NBRICKS)  ! string lengths
    real(rk), intent(out) :: snbp(NBRICKS)! stiffness proportions (delta omega in [5])
    
    real(rk) :: rng, drng, gGmax, h1
    integer(ik) :: jb
    
    rng  = (G0 - Gur) / G0
    drng = rng / real(NBRICKS, kind=rk)
    
    ! string lengths from the inverted S-curve at the mid-height of each stiffness step
    h1 = 7.0_rk/3.0_rk * gamma07
    gGmax = 1.0_rk
    do jb = 1, NBRICKS
      gGmax = gGmax - drng
      sl(jb) = h1 * (dsqrt(1.0_rk/(gGmax + 0.5_rk*drng)) - 1.0_rk)
    end do
    
    ! stiffness proportions of the bricks, here constant
    snbp = drng
    
  end subroutine brick_string_properties
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 01.07.2026
  !
  !> Shear strain invariant gamma = sqrt(3/2 e:e) of a strain tensor in Voigt notation with
  !> tensorial shear components (order 11,22,33,12,13,23, no engineering gammas). The invariant is
  !> insensitive to the volumetric part of eps (projection onto the deviatoric plane in strain space).
  !> Original verison (gam_inv) kindly provided by M. Cudny
  !
  !>### History
  !>* 01.07.2026, J. Machacek - Initial version (refactoring, modernizing; clamp radicand at zero)
  !
  pure function strain_gamma_invariant(eps) result(gam)
    implicit none
    
    real(rk), intent(in) :: eps(6)
    real(rk) :: gam
    
    real(rk) :: h1
    
    h1 = eps(1)**2 + eps(2)**2 + eps(3)**2 - eps(1)*eps(2) - eps(2)*eps(3) - eps(1)*eps(3) &
         + 3.0_rk*(eps(4)**2 + eps(5)**2 + eps(6)**2)
    
    gam = dsqrt(max(h1, 0.0_rk))
    
  end function strain_gamma_invariant
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 01.07.2026
  !
  !> Bricks strain history update for a single (sub-)increment dsn (Box 1 in [5]): the man strain sn is
  !> advanced by dsn; every brick whose strain distance to the man (measured by the shear strain invariant)
  !> exceeds its string length is dragged along the relative distance vector until the string is taut again.
  !> Returns the actual reference tangent shear modulus Gref_t = G0*(1 - sum of active stiffness proportions)
  !> valid after application of dsn, and the number of active (dragged) bricks.
  !> Original verison (G_Brick_Gam) kindly provided by M. Cudny
  !
  !>### History
  !>* 01.07.2026, J. Machacek - Initial version (refactoring, modernizing)
  !
  subroutine update_bricks(sn, snb, dsn, mat, Gref_t, n_bricks)
    implicit none
    
    real(rk), intent(inout) :: sn(6)              ! man strain (tensorial shear components)
    real(rk), intent(inout) :: snb(6,NBRICKS)     ! brick strains (tensorial shear components)
    real(rk), intent(in) :: dsn(6)                ! strain (sub-)increment of the man
    type(material_properties_ty_), intent(in) :: mat
    real(rk), intent(out) :: Gref_t               ! actual reference tangent shear modulus
    integer(ik), intent(out) :: n_bricks          ! number of active (dragged) bricks
    
    real(rk) :: snt(6), mb(6)
    real(rk) :: dist, rel, omega
    integer(ik) :: jb
    
    n_bricks = 0
    omega = 0.0_rk
    
    snt = sn + dsn
    
    do jb = 1, NBRICKS
      
      mb = snt - snb(:,jb)
      dist = strain_gamma_invariant(mb)
      
      if (dist > mat%sl(jb)) then
        ! string is taut: drag the brick along the relative distance vector
        n_bricks = n_bricks + 1
        rel = (dist - mat%sl(jb)) / dist
        snb(:,jb) = snb(:,jb) + rel * mb
        omega = omega + mat%snbp(jb)
      end if
      
    end do
    
    sn = snt
    Gref_t = mat%G0 * (1.0_rk - omega)
    
  end subroutine update_bricks
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 01.07.2026
  !
  !> Elastic stress predictor with BRICK small-strain stiffness degradation (Box 2 in [5]).
  !> The strain increment dstrain (Voigt notation, engineering shear strains) is converted to tensorial
  !> shear components and split into sub-increments such that the shear strain invariant per sub-increment
  !> does not exceed GAMMA_SUB_MAX. For each sub-increment, the bricks are moved first (update_bricks) and
  !> the stress is then integrated with the resulting actual stiffness E_t = 2(1+nu)*Gref_t*fac, i.e. the
  !> piecewise constant incremental tangent of the stepwise S-curve. The stiffness ratio Gm (minimum of
  !> Gref_t/Gur_ref over the loading history) is updated per sub-increment.
  !> Note that the barotropy factor fac is frozen at the stress state passed in by the caller.
  !
  !>### History
  !>* 01.07.2026, J. Machacek - Initial version
  !
  subroutine brick_elastic_predictor(stress, dstrain, ntens, mat, fac, sn, snb, Gm, Gref_t, E_t, n_bricks)
    implicit none
    
    integer(ik), intent(in) :: ntens
    real(rk), intent(inout) :: stress(ntens)      ! in: stress at increment start, out: trial stress
    real(rk), intent(in) :: dstrain(ntens)        ! strain increment (Voigt, engineering shear strains)
    type(material_properties_ty_), intent(in) :: mat
    real(rk), intent(in) :: fac                   ! stress-dependent stiffness factor (frozen)
    real(rk), intent(inout) :: sn(6)              ! man strain (tensorial shear components)
    real(rk), intent(inout) :: snb(6,NBRICKS)     ! brick strains (tensorial shear components)
    real(rk), intent(inout) :: Gm                 ! stiffness ratio Gm (monotonically non-increasing)
    real(rk), intent(out) :: Gref_t               ! actual reference tangent shear modulus (last sub-increment)
    real(rk), intent(out) :: E_t                  ! actual Young's modulus (last sub-increment)
    integer(ik), intent(out) :: n_bricks          ! number of active bricks (last sub-increment)
    
    real(rk) :: dsn_total(6), dsn_sub(6), dstrain_sub(ntens)
    real(rk) :: dds_dde_sub(ntens,ntens)
    real(rk) :: gam_inc
    integer(ik) :: k, nsub
    
    ! strain increment with tensorial shear components (out-of-plane shears vanish for ntens = 4)
    dsn_total = 0.0_rk
    dsn_total(1:3) = dstrain(1:3)
    dsn_total(4) = 0.5_rk*dstrain(4)
    if (ntens == 6) then
      dsn_total(5) = 0.5_rk*dstrain(5)
      dsn_total(6) = 0.5_rk*dstrain(6)
    end if
    
    ! sub-incrementation: shear strain invariant per sub-increment limited to GAMMA_SUB_MAX
    gam_inc = strain_gamma_invariant(dsn_total)
    nsub = max(1_ik, ceiling(gam_inc/GAMMA_SUB_MAX, kind=ik))
    
    dsn_sub = dsn_total/real(nsub, kind=rk)
    dstrain_sub = dstrain/real(nsub, kind=rk)
    
    do k = 1, nsub
      
      ! move the bricks and obtain the tangent stiffness valid for this sub-increment
      call update_bricks(sn, snb, dsn_sub, mat, Gref_t, n_bricks)
      
      ! stiffness ratio: minimum over the loading history (Sect. 3.1 in [5])
      Gm = min(Gm, Gref_t/mat%Gur_ref)
      
      ! actual Young's modulus (strain- and stress-dependent) and stress integration
      E_t = mat%E0fac * Gref_t * fac
      
      dds_dde_sub = get_elastic_jacobian(E_t,mat%nu,ntens)
      stress = stress + matmul(dds_dde_sub,dstrain_sub)
      
    end do
    
  end subroutine brick_elastic_predictor
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 01.07.2026
  !
  !> Read the BRICK state from the state variable array (see module header for the layout).
  !> On the first call (istep == 1 .and. iinc == 1) the state is initialised to the virgin state:
  !> all strings slack, man and brick strains at zero, Gm at its upper bound Gm_max (no degradation
  !> recorded yet). An uninitialised state read back from the array (Gm < 1) is treated likewise.
  !
  !>### History
  !>* 01.07.2026, J. Machacek - Initial version
  !
  subroutine read_brick_state(statev, nstatev, mat, istep, iinc, Gm, sn, snb)
    implicit none
    
    integer, intent(in) :: nstatev
    real(rk), intent(in) :: statev(nstatev)
    type(material_properties_ty_), intent(in) :: mat
    integer, intent(in) :: istep
    integer, intent(in) :: iinc
    real(rk), intent(out) :: Gm                   ! stiffness ratio Gm
    real(rk), intent(out) :: sn(6)                ! man strain (tensorial shear components)
    real(rk), intent(out) :: snb(6,NBRICKS)       ! brick strains (tensorial shear components)
    
    integer(ik) :: jb, i0
    
    if (nstatev < NSTATEV_BRICKS) then
      error stop "hardening_soil_MN_bricks: nstatev < 73 (13 + 6*NBRICKS state variables required)"
    end if
    
    ! Initialise state variables
    if (istep == 1 .and. iinc == 1) then
      Gm = mat%Gm_max
      sn = 0.0_rk
      snb = 0.0_rk
      return
    end if
    
    Gm = statev(6)
    sn = statev(8:13)
    do jb = 1, NBRICKS
      i0 = 14 + 6*(jb-1)
      snb(:,jb) = statev(i0:i0+5)
    end do
    
    ! Gm >= 1 holds by construction; an uninitialised state (Gm < 1) is reset to the virgin state
    if (Gm < 1.0_rk) then
      Gm = mat%Gm_max
      sn = 0.0_rk
      snb = 0.0_rk
    end if
    
  end subroutine read_brick_state
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 01.07.2026
  !
  !> Commit the BRICK state to the state variable array (see module header for the layout).
  !
  !>### History
  !>* 01.07.2026, J. Machacek - Initial version
  !
  subroutine commit_brick_state(statev, nstatev, Gm, n_bricks, sn, snb)
    implicit none
    
    integer, intent(in) :: nstatev
    real(rk), intent(inout) :: statev(nstatev)
    real(rk), intent(in) :: Gm                    ! stiffness ratio Gm
    integer(ik), intent(in) :: n_bricks           ! number of active bricks
    real(rk), intent(in) :: sn(6)                 ! man strain (tensorial shear components)
    real(rk), intent(in) :: snb(6,NBRICKS)        ! brick strains (tensorial shear components)
    
    integer(ik) :: jb, i0
    
    statev(6) = Gm
    statev(7) = real(n_bricks, kind=rk)
    statev(8:13) = sn
    do jb = 1, NBRICKS
      i0 = 14 + 6*(jb-1)
      statev(i0:i0+5) = snb(:,jb)
    end do
    
  end subroutine commit_brick_state
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> Compute derivatives of the plastic potential and yield function for the MN cone 
  !> Original verison (DERIV) by Leonardo José Cocco
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version (refactoring, modernizing)
  !>* 27.12.2025, J. Machacek - Simplification and speed-up (2-3x faster)
  !>* 03.03.2025, J. Machacek - Further simplification and some speed-up
  !>* 01.06.2026, J. Machacek - Interface: pass precomputed Rf_eta_phi instead of (sin_phi, Rf), remove dead Mc3 store
  !>* 20.07.2026, J. Machacek - Correct cone derivatives for engineering-shear Voigt coordinates
  !
  subroutine df_dg_cone(stress, ntens, m, m2, n, zeta, Rf_eta_phi, sin_psi_mob, Eur, Ei, chi, apex, gammapss)
    implicit none
  
    integer(ik), intent(in)  :: ntens
    real(rk), intent(in)  :: stress(ntens)
    real(rk), intent(in)  :: Rf_eta_phi, sin_psi_mob, Eur, Ei, chi, apex, gammapss
    real(rk), intent(out) :: m(ntens), m2(ntens,ntens), n(ntens), zeta
  
    ! Stress components
    real(rk) :: S1, S2, S3, S12, S13, S23
    real(rk) :: S1sq, S2sq, S3sq, S12sq, S13sq, S23sq
    real(rk) :: S1S2, S2S3, S1S3
  
    ! Stress invariant building blocks
    real(rk) :: I1          ! = S1+S2+S3
    real(rk) :: qsq         ! = 3*J2 = q^2
    real(rk) :: q           ! = sqrt(qsq)
    real(rk) :: q3          ! = q^3
  
    ! Matsuoka-Nakai mapped quantities
    real(rk) :: sin_psi     ! = sin(psi_mob)
  
    ! Yield function intermediate quantities
    real(rk) :: Dphi        ! = 6*chi*pa + q 
    real(rk) :: G           ! = distance to failure
    real(rk) :: F           ! = (1/3)*G*Dphi/q − Rf_eta_phi
    real(rk) :: m_vol       ! volumetric part of plastic potential gradient
  
    ! Reciprocals and powers
    real(rk) :: inv_q, inv_q3         ! 1/q, 1/q^3
    real(rk) :: inv_Dphi, inv_Dphi2   ! 1/Dphi, 1/Dphi^2
    real(rk) :: inv_G, inv_G2         ! 1/G, 1/G^2
    real(rk) :: inv_Eur, inv_Ei       ! 1/Eur, 1/Ei
  
    ! Chain-rule subexpressions for dn/dsig
    real(rk) :: dDphi_iso   ! dDphi/dsig_ii contribution  = −2chi + I1/q  (isotropic part)
    real(rk) :: dG_iso      ! dG/dsig_ii (isotropic)
    real(rk) :: dG_dev      ! dG/d(deviatoric direction) = coefficient of −1.5*(Sj+Sk)/q
    real(rk) :: dF_iso      ! dF/dsig_ii (isotropic)
    real(rk) :: dF_dev      ! dF/d(deviatoric direction)
  
    ! Final assembled coefficients for n = n_iso*delta + n_dev*sig_off
    real(rk) :: n_iso       ! isotropic part of yield gradient
    real(rk) :: n_dev       ! deviatoric coefficient
     
    ! Stress components
    S1 = stress(1) ; S2 = stress(2) ; S3 = stress(3) ; S12 = stress(4)
    S13 = 0.0_rk ; S23 = 0.0_rk
    if (ntens == 6) then
      S13 = stress(5) ; S23 = stress(6)
    end if
    
    S1sq = S1*S1 ; S2sq = S2*S2 ; S3sq = S3*S3
    S12sq = S12*S12 ; S13sq = S13*S13 ; S23sq = S23*S23
    S1S2 = S1*S2 ; S2S3 = S2*S3 ; S1S3 = S1*S3

    !
    ! Common invariants
    !
    
    I1 = S1 + S2 + S3
    qsq = S1sq + S2sq + S3sq - S1S2 - S1S3 - S2S3 + 3.0_rk * (S12sq + S13sq + S23sq)
    qsq = max( qsq , 1.0e-20_rk )
    q = sqrt(qsq)
    q3 = qsq * q
    inv_q = 1.0_rk / q
    inv_q3 = 1.0_rk / q3
    
    !
    ! Trigonometric and material quantities
    !
    
    sin_psi = sin_psi_mob
  
    !
    ! Plastic potential: m and m2
    ! g = q + M(psi_mob)*I1  ->  m = dg/dsig ; volumetric part m_vol uses sin(psi_mob) directly
    !
    
    m_vol = (-3.0_rk*I1 + I1*sin_psi - 2.0_rk*sin_psi*q) / (q * (-3.0_rk + sin_psi))
    m(1) = m_vol - 1.5_rk * inv_q * (S2 + S3)
    m(2) = m_vol - 1.5_rk * inv_q * (S1 + S3)
    m(3) = m_vol - 1.5_rk * inv_q * (S1 + S2)
    m(4) = 3.0_rk * inv_q * S12
    if (ntens == 6) then
      m(5) = 3.0_rk * inv_q * S13
      m(6) = 3.0_rk * inv_q * S23
    end if
    
    !
    ! m2: Hessian
    ! m2 = d^2g/dsig^2 = (3/2)*(I_dev/q − (9/4)*s⊗s/q^3)
    ! restrucutred as: m2(i,j) = (3/4)/q^3 * H(i,j) where H encodes the deviatoric projection.
    !
    
    m2(1,1) =  0.75_rk * inv_q3 * (-2.0_rk*S2S3 + 4.0_rk*S12sq + S2sq + S3sq + 4.0_rk*(S13sq + S23sq))
    m2(1,2) = -0.75_rk * inv_q3 * (S1S2 - S1S3 - S2S3 + 2.0_rk*S12sq + S3sq + 2.0_rk*(S13sq + S23sq))
    m2(1,3) =  0.75_rk * inv_q3 * (S1S2 - S1S3 + S2S3 - 2.0_rk*S12sq - S2sq - 2.0_rk*(S13sq + S23sq))
    m2(1,4) = -1.5_rk * inv_q3 * (2.0_rk*S1 - S2 - S3) * S12
    
    m2(2,1) = m2(1,2)
    m2(2,2) =  0.75_rk * inv_q3 * (-2.0_rk*S1S3 + 4.0_rk*S12sq + S1sq + S3sq + 4.0_rk*(S13sq + S23sq))
    m2(2,3) = -0.75_rk * inv_q3 * (-S1S2 - S1S3 + S2S3 + 2.0_rk*S12sq + S1sq + 2.0_rk*(S13sq + S23sq))
    m2(2,4) =  1.5_rk * inv_q3 * (S1 - 2.0_rk*S2 + S3) * S12
    
    m2(3,1) = m2(1,3)
    m2(3,2) = m2(2,3)
    m2(3,3) =  0.75_rk * inv_q3 * (-2.0_rk*S1S2 + 4.0_rk*S12sq + S1sq + S2sq + 4.0_rk*(S13sq + S23sq))
    m2(3,4) =  1.5_rk * inv_q3 * (S1 + S2 - 2.0_rk*S3) * S12
    
    m2(4,1) = m2(1,4) ; m2(4,2) = m2(2,4) ; m2(4,3) = m2(3,4)
    m2(4,4) = 3.0_rk*inv_q - 9.0_rk*S12sq*inv_q3
  
    if (ntens == 6) then
      m2(1,5) = -1.5_rk * inv_q3 * (2.0_rk*S1 - S2 - S3) * S13
      m2(1,6) = -1.5_rk * inv_q3 * (2.0_rk*S1 - S2 - S3) * S23
      m2(2,5) =  1.5_rk * inv_q3 * (S1 - 2.0_rk*S2 + S3) * S13
      m2(2,6) =  1.5_rk * inv_q3 * (S1 - 2.0_rk*S2 + S3) * S23
      m2(3,5) =  1.5_rk * inv_q3 * (S1 + S2 - 2.0_rk*S3) * S13
      m2(3,6) =  1.5_rk * inv_q3 * (S1 + S2 - 2.0_rk*S3) * S23
      m2(5,1) = m2(1,5) ; m2(5,2) = m2(2,5) ; m2(5,3) = m2(3,5)
      m2(6,1) = m2(1,6) ; m2(6,2) = m2(2,6) ; m2(6,3) = m2(3,6)
      m2(4,5) = -9.0_rk * inv_q3 * S12 * S13
      m2(4,6) = -9.0_rk * inv_q3 * S12 * S23
      m2(5,4) = m2(4,5) ; m2(6,4) = m2(4,6)
      m2(5,5) = 3.0_rk*inv_q - 9.0_rk*S13sq*inv_q3
      m2(5,6) = -9.0_rk * inv_q3 * S13 * S23
      m2(6,5) = m2(5,6)
      m2(6,6) = 3.0_rk*inv_q - 9.0_rk*S23sq*inv_q3
    end if
  
    ! 
    ! Yield function gradient: n
    !
  
    ! Precompute reciprocals
    inv_Ei = 1.0_rk / Ei
    inv_Eur = 1.0_rk / Eur
  
    Dphi = 6.0_rk * chi * (-I1 / 3.0_rk + apex) + q
    if (Dphi <= 1.0e-8_rk) Dphi = 1.0e-8_rk
    inv_Dphi = 1.0_rk / Dphi
    inv_Dphi2 = inv_Dphi * inv_Dphi
  
    G = 1.0_rk - 3.0_rk * q * inv_Dphi
    if (G <= 1.0e-8_rk) G = 1.0e-8_rk
    inv_G  = 1.0_rk / G
    inv_G2 = inv_G * inv_G
    F = (1.0_rk / 3.0_rk) * G * inv_q * Dphi - Rf_eta_phi
  
    dDphi_iso = -2.0_rk * chi + I1 * inv_q
  
    dG_iso = -3.0_rk * inv_q * inv_Dphi * I1 +  3.0_rk * q * inv_Dphi2 * dDphi_iso
    dG_dev = 4.5_rk * inv_q * inv_Dphi - 4.5_rk * inv_Dphi2
  
    ! dF/dsig_ii|_iso: from the CAS form
    dF_iso = (1.0_rk/3.0_rk) * ( dG_iso * Dphi * inv_q - G * Dphi * I1 * inv_q3 + G * dDphi_iso * inv_q )
  
    ! dF/d(deviatoric part): coefficient of (Sj+Sk)
    dF_dev = (1.0_rk/3.0_rk) * dG_dev * Dphi * inv_q + 0.5_rk * G * (Dphi * inv_q3 - 1.0_rk / qsq)
  
    ! Assemble n_iso and n_dev

    n_iso = 1.5_rk * inv_q * inv_Ei * I1 - 9.0_rk * I1 * F * inv_Eur * inv_G * inv_Dphi &               
            - 4.5_rk * qsq * inv_Eur * dF_iso * inv_G * inv_Dphi + 4.5_rk * qsq * inv_Eur * F * inv_G2 * inv_Dphi * dG_iso &    
            + 4.5_rk * qsq * inv_Eur * F * inv_G * inv_Dphi2 * dDphi_iso &
            - 3.0_rk * gammapss * dF_iso * q * inv_G * inv_Dphi &
            + 3.0_rk * gammapss * F * q * inv_G2 * inv_Dphi * dG_iso - 3.0_rk * gammapss * F * inv_q * inv_G * inv_Dphi * I1 &      
            + 3.0_rk * gammapss * F * q * inv_G * inv_Dphi2 * dDphi_iso    
  
    ! n_dev: coefficient of (S2+S3), (S1+S3), (S1+S2), or −S12
    n_dev = -9.0_rk / 4.0_rk * inv_q * inv_Ei + 27.0_rk / 2.0_rk * inv_Eur * F * inv_G * inv_Dphi &        
            - 4.5_rk * qsq * inv_Eur * dF_dev * inv_G * inv_Dphi + 4.5_rk * qsq * inv_Eur * F * inv_G2 * inv_Dphi * dG_dev &  
            - 27.0_rk / 4.0_rk * q * inv_Eur * F * inv_G * inv_Dphi2 - 3.0_rk * gammapss * dF_dev * q * inv_G * inv_Dphi &        
            + 3.0_rk * gammapss * F * q * inv_G2 * inv_Dphi * dG_dev + 4.5_rk * gammapss * F * inv_q * inv_G * inv_Dphi &         
            - 4.5_rk * gammapss * F * inv_G * inv_Dphi2                  
  
    ! Assemble n vector
    n(1) = n_iso + n_dev * (S2 + S3)
    n(2) = n_iso + n_dev * (S1 + S3)
    n(3) = n_iso + n_dev * (S1 + S2)
    n(4) = -2.0_rk * n_dev * S12
    if (ntens == 6) then
      n(5) = -2.0_rk * n_dev * S13
      n(6) = -2.0_rk * n_dev * S23
    end if
  
    ! 
    ! Hardening derivative: zeta
    ! 
  
    zeta = -3.0_rk * F * q * inv_G * inv_Dphi
  
  end subroutine df_dg_cone
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> Dompute derivatives of the plastic potential and yield function for the cap 
  !> Original verison (DERIV1) by Leonardo José Docco
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version (refactoring, modernizing, speed-up)
  !>* 03.03.2025, J. Machacek - Fix bug of missing coupling terms in m2, further simplification
  !>* 01.06.2026, J. Machacek - Interface: pass precomputed apex instead of (c, phi) - removes two dtan per call
  !                           - rename local scalar D -> coef3
  !>* 20.07.2026, J. Machacek - Correct cap derivatives for engineering-shear Voigt coordinates
  ! 
  subroutine df_dg_cap(stress, ntens, w, w2, u, zetac, chi, alpha, pp, apex)
    implicit none
  
    integer(ik), intent(in) :: ntens
    real(rk), intent(in) :: stress(ntens)
    real(rk), intent(in) :: chi
    real(rk), intent(in) :: alpha
    real(rk), intent(in) :: pp
    real(rk), intent(in) :: apex
    real(rk), intent(out) :: w(ntens)
    real(rk), intent(out) :: w2(ntens,ntens)
    real(rk), intent(out) :: u(ntens)
    real(rk), intent(out) :: zetac
    
    real(rk) :: A, B, coef3, H2, inv

    ! initialise
    w = 0.0_rk ; w2 = 0.0_rk ; u = 0.0_rk ; zetac = 0.0_rk
    
    ! Only ntens = 4 or 6 supported currently
    if (ntens /= 4 .and. ntens /= 6) return

    !
    ! Precompute constants
    !
    
    H2 = (chi * alpha) * (chi * alpha)
    
    ! Basic safety: if chi*alpha is (near) zero, derivatives are undefined
    if (H2 <= tiny(1.0_rk)) return
    
    inv = 1.0_rk / H2                           ! 1/(chi^2 * alpha^2)
    coef3 = 3.0_rk * inv                        ! 3/(chi^2 * alpha^2)
    B = (2.0_rk/9.0_rk) * (9.0_rk + H2) * inv   ! 2/9*(9+chi^2*alpha^2)/(chi^2*alpha^2)
    
    A = B * sum(stress(1:3)) - (2.0_rk/3.0_rk) * apex
    
    !
    ! First derivatives
    !
    
    w(1) = A - coef3 * (stress(2) + stress(3))
    w(2) = A - coef3 * (stress(1) + stress(3))
    w(3) = A - coef3 * (stress(1) + stress(2))
    w(4) = 2.0_rk * coef3 * stress(4)
    if (ntens == 6) then
      w(5) = 2.0_rk * coef3 * stress(5)
      w(6) = 2.0_rk * coef3 * stress(6)
    end if
    
    u = w
    
    ! Derivative w.r.t. state variable
    zetac = -2.0_rk * (pp + apex)

    !
    ! Second derivatives (Hessian)
    !
    
    ! Normal block
    w2(1,1) = B ; w2(2,2) = B ; w2(3,3) = B
    
    ! coupling terms
    w2(1,2) = B - coef3 ; w2(2,1) = w2(1,2)
    w2(1,3) = B - coef3 ; w2(3,1) = w2(1,3)
    w2(2,3) = B - coef3 ; w2(3,2) = w2(2,3)

    ! Shear diagonal
    w2(4,4) = 2.0_rk * coef3
    if (ntens == 6) then
      w2(5,5) = 2.0_rk * coef3 ; w2(6,6) = 2.0_rk * coef3
    end if

  end subroutine df_dg_cap
  
  
  !  
  ! Code for optimisation of "internal" parameters alpha and Hpp
  !
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> This subroutine determines the cap parameters alpha and Hpp such that the
  !> Hardening Soil model reproduces the target oedometric stiffness (Eoedref)
  !> and lateral earth pressure coefficient (K0nc). A Newton-Raphson method is
  !> employed to solve the resulting nonlinear system of two equations.
  !>
  !> The iteration continues until both relative residuals fall below the
  !> specified tolerance (1e-6).
  !
  !> The Jacobian is recomputed at every iteration by central differences
  !> (full Newton-Raphson).
  !
  !> Original verison (OPTIM) by Leonardo José Cocco
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version (refactoring, modernizing)
  !>* 28.12.2025, J. Machacek - Full Newton-Raphson, relative errors, Cramers rule to solve 2x2 system, remove common block
  !>* 01.06.2026, J. Machacek - Convergence now requires BOTH residuals (.and.); corrected stale modified-Newton doc
  !>* 08.06.2026, J. Machacek - Return abs(alpha) since only alpha^2 appears in any equation; its sign has no effect
  !>* 01.07.2026, J. Machacek - Renamed to optimize_hs_bricks_internal_constants (HS-Brick module). The optimisation itself is
  !>                            performed with the base HS model response (H_i = 1), see objective_function. Thus alpha and Hpp
  !>                            retain their base-HS meaning and the Eoedref/K0nc calibration is unaffected by the BRICK extension.
  !>* 23.08.2026, J. Machacek - Add optional CSV convergence-history output for the standalone calibration utility
  !
  subroutine optimize_hs_bricks_internal_constants(props, nprops, history_file)
    implicit none
    
    integer, intent(in) :: nprops
    real(rk), intent(inout) :: props(nprops)
    character(len=*), intent(in), optional :: history_file
    
    type(material_properties_ty_) :: mat
    
    real(rk), parameter :: TOL = 1.0e-6_rk
    real(rk), parameter :: STRESS_MIN = 1e-4_rk
    integer, parameter :: MAXITER = 10000
    
    real(rk) :: jacobian(2,2)
    real(rk) :: delta_X(2)
    real(rk) :: residual(2)
    real(rk) :: FVEC(2)
    real(rk) :: X(2)
    real(rk) :: det
    real(rk) :: relative_error(2)
    real(rk) :: error_measure
    integer :: iiter
    integer :: history_unit, history_iostat
    logical :: write_history
    
    ! Read in the material constants
    call mat%collect(props, nprops)
    
    ! Initialize solution vector with initial guess
    X(1) = 1.20_rk
    X(2) = 2.0_rk * mat%Eoed
    
    ! Evaluate objective function at initial guess
    call objective_function(mat, X, FVEC, STRESS_MIN)
    
    ! Compute initial residuals (unnormalized)
    residual(1) = mat%Eoed - FVEC(1)
    residual(2) = mat%K0nc - FVEC(2)
    
    ! Optional convergence-history output. No file I/O is performed for normal
    ! constitutive calls unless the caller explicitly supplies history_file.
    write_history = present(history_file)
    if (write_history) then
      open(newunit=history_unit, file=trim(history_file), status='replace', action='write', iostat=history_iostat)
      if (history_iostat /= 0) then
        write(*,'(a)') 'Error: could not open HS internal-constant convergence-history file: '//trim(history_file)
        error stop
      end if
      write(history_unit,'(a)') &
        'iteration,residual_Eoed,residual_K0,relative_error_Eoed,relative_error_K0,error_measure,tolerance,alpha,Hpp'
      relative_error(1) = abs(residual(1)) / mat%Eoed
      relative_error(2) = abs(residual(2)) / mat%K0nc
      error_measure = maxval(relative_error)
      write(history_unit,'(i0,8(",",es24.16))') 0, residual(1), residual(2), relative_error(1), relative_error(2), error_measure, TOL, X(1), X(2)
      flush(history_unit)
    end if
    
    ! Newton-Raphson iteration loop
    newton_loop: do iiter = 1, MAXITER
      
      ! Compute Jacobian at current point
      call numerical_differenciation(mat, X, jacobian, STRESS_MIN)
      
      ! Solve 2x2 linear system: jacobian * delta_X = residual
      ! Using Cramer's rule (more stable than manual elimination)
      det = jacobian(1,1) * jacobian(2,2) - jacobian(1,2) * jacobian(2,1)
      
      if (abs(det) < 1.0e-30_rk) then
        write(*,*) 'Subroutine optimize_hs_bricks_internal_constants suffered from singular jacobian, exit Newton loop'
        exit
      end if
      
      delta_X(1) = (residual(1) * jacobian(2,2) - residual(2) * jacobian(1,2)) / det
      delta_X(2) = (jacobian(1,1) * residual(2) - jacobian(2,1) * residual(1)) / det
      
      ! Update solution
      X = X + delta_X
      
      ! Evaluate objective function at new point
      call objective_function(mat, X, FVEC, STRESS_MIN)
      
      ! Update residuals
      residual(1) = mat%Eoed - FVEC(1)
      residual(2) = mat%K0nc - FVEC(2)
      
      if (write_history) then
        relative_error(1) = abs(residual(1)) / mat%Eoed
        relative_error(2) = abs(residual(2)) / mat%K0nc
        error_measure = maxval(relative_error)
        write(history_unit,'(i0,8(",",es24.16))') iiter, residual(1), residual(2), relative_error(1), relative_error(2), error_measure, TOL, X(1), X(2)
        flush(history_unit)
      end if
      
      if ( abs(residual(1)) <= TOL*mat%Eoed .and. abs(residual(2)) <= TOL*mat%K0nc) then
        exit newton_loop
      end if
      
    end do newton_loop
    
    if (write_history) close(history_unit)
    
    ! In this implementation alpha appears only as (chi*alpha)^2, so its sign has no effect on any result
    ! the yield function, its gradients, and the integrated stress path are identical for +/-alpha. 
    props(13) = abs(X(1))  
    
    props(14) = X(2)
    
  end subroutine optimize_hs_bricks_internal_constants
  
  
  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> Compute numerical gradient of a function (central differences)   
  !> Original verison (GRADF) by Leonardo José Cocco
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version (refactoring, modernizing)
  !>* 28.12.2025, J. Machacek - Remove common block
  !>* 01.06.2026, J. Machacek - Guard against a zero finite-difference step
  !
  subroutine numerical_differenciation(mat, X0, DifF, STRESS_MIN)
    implicit none
    
    type(material_properties_ty_), intent(in) :: mat
    real(rk), intent(in) :: X0(2)
    real(rk), intent(out) :: DifF(2,2)
    real(rk), intent(in) :: STRESS_MIN
    
    ! Local variables
    real(rk), parameter :: PERTURBATION = 0.01_rk
    real(rk) :: X_perturbed(2)
    real(rk) :: step_size
    real(rk) :: F_minus(2), F_plus(2)
    integer(ik) :: i_var, i_eq
    
    ! Compute Jacobian matrix using central differences
    ! For each input variable, perturb by +/- (PERTURBATION/2) * X(i)
    do i_var = 1, 2
      
      ! Compute absolute step size based on relative perturbation
      step_size = PERTURBATION * X0(i_var)
      if (abs(step_size) < 1.0e-12_rk) step_size = 1.0e-12_rk   ! guard against zero step (J. Machacek, 01.06.2026)
      
      ! Evaluate function at X - step/2
      X_perturbed = X0
      X_perturbed(i_var) = X0(i_var) - 0.5_rk * step_size
      call objective_function(mat, X_perturbed, F_minus, STRESS_MIN)
      
      ! Evaluate function at X + step/2
      X_perturbed = X0
      X_perturbed(i_var) = X0(i_var) + 0.5_rk * step_size
      call objective_function(mat, X_perturbed, F_plus, STRESS_MIN)
      
      ! Compute partial derivatives: d(FVEC)/d(X(i_var))
      do i_eq = 1, 2
        DifF(i_eq, i_var) = (F_plus(i_eq) - F_minus(i_eq)) / step_size
      end do
      
    end do
    
  end subroutine numerical_differenciation
  

  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 22.12.2025
  !
  !> Evaluate the objective function for alpha and Hpp optimization process   
  !> Original verison (VALUAR_F) by Leonardo José Cocco
  !
  !>### History
  !>* 22.12.2025, J. Machacek - Initial version (refactoring, modernizing)
  !>* 28.12.2025, J. Machacek - Remove common block, simplify code
  !>* 01.06.2026, J. Machacek - Use helpers and precomputed mat constants; remove dead tangent D and unused i, j, ctrl
  !>* 01.07.2026, J. Machacek - HS-Brick extension [5]: pass H_i = 1 to the return mapping. The optimisation deliberately
  !>                            reproduces the base HS oedometric response (fully degraded small-strain stiffness), so that
  !>                            alpha and Hpp keep their base-HS meaning and the Eoedref/K0nc targets remain exact.
  !
  subroutine objective_function(mat0,X,FVEC,STRESS_MIN)
    use compatibility_numgeo_, only: cartesian_to_principal_stress_analytical, pi, roscoe_pq_voigt, invariants_J2_J3
    implicit none

    type(material_properties_ty_), intent(in) :: mat0
    real(rk), intent(in) :: X(2)
    real(rk), intent(in) :: STRESS_MIN
    real(rk), intent(out) :: FVEC(2)
    
    ! Small-strain hardening factor H_i (Eq. 22/23 in [5]): the optimisation is performed with the
    ! base HS model response, i.e. H_i = 1 (Gm = 1, fully degraded small-strain stiffness)
    real(rk), parameter :: H_i = 1.0_rk
    
    
    ! Stress and strain variables
    real(rk) :: stress(4), stress0(4), stress_trial(4), Depsilon(4)
    real(rk) :: S(3), sigma3
    real(rk) :: p_trial, q_trial, p, q, J2, J3
    
    type(material_properties_ty_) :: mat       ! material properties
    
    ! Constitutive matrix
    real(rk) :: dds_dde(4,4)
    
    ! Lode angle and Matsuoka-Nakai parameters
    real(rk) :: chi, Mcs
    
    ! Mobilized friction and dilatancy angles
    real(rk) :: sin_phi_mob, sin_psi_mob, sin_phi_mob_trial, sin_psi_mob_trial
    
    ! Stiffness parametersalpha
    real(rk) :: Eur, Ei, stress_minE, hc
    real(rk) :: fac
    
    ! Yield function and hardening variables
    real(rk) :: fs_trial, fc_trial, fs, fc
    real(rk) :: gammapss0, gammapss, pp0, pp
    
    
    ! Initialize hardening variables
    gammapss0 = 0.0_rk
    pp0 = 0.0_rk
    
    ! Extract optimization variables
    mat = mat0
    mat%alpha = X(1)
    mat%Hpp = X(2)
    
    ! Initialize stress state
    stress0 = 0.0_rk
    
    ! Strain increment (oedometer loading)
    Depsilon(:) = 0.0_rk
    Depsilon(2) = -5.0e-6_rk
    
    ! Compute principal stresses
    S = cartesian_to_principal_stress_analytical(4,stress0)
    sigma3 = maxval(S)
    
    ! Stress-dependent stiffness
    stress_minE = max(-sigma3,STRESS_MIN)
    fac = stiffness_factor(stress_minE, mat)
    Eur = mat%Eur * fac
    Ei  = mat%Ei  * fac
    
    ! Build elastic constitutive matrix
    dds_dde = get_elastic_jacobian(Eur,mat%nu,4)
    
    ! Trial stress
    stress = stress0 + matmul(dds_dde,Depsilon)
    
    ! Compute principal stresses
    S = cartesian_to_principal_stress_analytical(4,stress)
    sigma3 = maxval(S)
    
    ! Determination of invariants and stresses to evaluate the creep function
    call roscoe_pq_voigt(4,stress,p_trial,q_trial)
    call invariants_J2_J3(stress,4,J2,J3)
    
    ! Lode angle dependent formulation for Matsuoka-Nakai criterion
    call lode_shape_factor(J2, J3, mat%sin_phi, chi)
    Mcs = chi * mat%Mc
    
    stress_minE = max(-sigma3,STRESS_MIN)
    hc = 2.0_rk*mat%Hpp * stiffness_factor(stress_minE, mat) * (p_trial + mat%apex)
    
    ! Critical state friction angle
    
    ! Mobilized friction angle and dilatancy angle
    sin_phi_mob_trial = mob_sin_phi(p_trial, q_trial, chi, mat%apex)
    sin_psi_mob_trial = get_mob_dilatancy_angle(sin_phi_mob_trial, mat%sin_phi_cs, mat%apex, Mcs, p_trial, q_trial)
    
    ! Shear yield function
    fs_trial = yield_function_fs(q_trial, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob_trial, gammapss0)
    
    ! Cap yield function
    fc_trial = yield_function_fc(p_trial, q_trial, pp0, chi, mat%alpha, mat%apex)
    
    ! Main loading loop (oedometer simulation)
    do while (stress(2) >= -mat%pref)
      
      stress_trial = stress
      
      call return_mapping_mixed_surface(stress_trial,4,fs_trial,mat,sin_phi_mob,sin_psi_mob,Eur,Ei,dds_dde,gammapss0,gammapss,&
                                        stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,fc_trial,fc,pp0,pp,p_trial,q_trial,hc, &
                                          sin_phi_mob_trial,&
                                        sin_psi_mob_trial,H_i)
      
      gammapss0 = gammapss
      pp0 = pp
      
      stress0 = stress
      
      ! Compute principal stresses
      S = cartesian_to_principal_stress_analytical(4,stress0)
      sigma3 = maxval(S)
      
      ! Update stress-dependent stiffness
      stress_minE = max(-sigma3,STRESS_MIN)
      fac = stiffness_factor(stress_minE, mat)
      Eur = mat%Eur * fac
      Ei  = mat%Ei  * fac
      
      ! Rebuild elastic constitutive matrix
      dds_dde = get_elastic_jacobian(Eur,mat%nu,4)
      
      ! Apply strain increment
      stress = stress0 + matmul(dds_dde,Depsilon)
      
      ! Compute principal stresses
      S = cartesian_to_principal_stress_analytical(4,stress)
      sigma3 = maxval(S)
      
      ! Determination of invariants and stresses to evaluate the creep function
      call roscoe_pq_voigt(4,stress,p_trial,q_trial)
      call invariants_J2_J3(stress,4,J2,J3)
      
      ! Lode angle dependent formulation for Matsuoka-Nakai criterion
      call lode_shape_factor(J2, J3, mat%sin_phi, chi)
      
      Mcs = chi * mat%Mc
      hc = 2.0_rk*mat%Hpp * stiffness_factor(stress_minE, mat) * (p_trial + mat%apex)
      
      ! Mobilized friction angle and dilatancy angle
      sin_phi_mob_trial = mob_sin_phi(p_trial, q_trial, chi, mat%apex)
      sin_psi_mob_trial = get_mob_dilatancy_angle(sin_phi_mob_trial, mat%sin_phi_cs, mat%apex, Mcs, p_trial, q_trial)
      
      ! Shear yield function
      fs_trial = yield_function_fs(q_trial, Ei, Eur, mat%Rf, mat%sin_phi, sin_phi_mob_trial, gammapss0)
      
      ! Cap yield function
      fc_trial = yield_function_fc(p_trial, q_trial, pp0, chi, mat%alpha, mat%apex)
      
    end do
    
    ! Final return mapping
    stress_trial = stress
    
    call return_mapping_mixed_surface(stress_trial,4,fs_trial,mat,sin_phi_mob,sin_psi_mob,Eur,Ei,dds_dde, &
                gammapss0,gammapss,stress,p,q,chi,mat%sin_phi_cs,Mcs,fs,fc_trial,fc,pp0,pp, &
                p_trial,q_trial,hc,sin_phi_mob_trial,sin_psi_mob_trial,H_i)
    
    ! Compute oedometer modulus and K0
    FVEC(1) = (stress(2) - stress0(2)) / Depsilon(2)
    FVEC(2) = (stress(1) - stress0(1)) / (stress(2) - stress0(2))
    
  end subroutine objective_function
  
  
end module material_hardening_soil_MN_bricks_
