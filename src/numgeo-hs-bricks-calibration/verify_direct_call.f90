program verify_direct_call
  ! Independent cross-check of the UMAT/incrementalDriver path in example/output_CD.out.
  !
  ! This program does NOT go through umat() or incrementalDriver.f. It calls
  ! hardening_soil_MN_bricks(...) directly from numgeo_hardening_soil_MN_bricks_.f90, using the
  ! same compatibility_numgeo_.f90 / precision_.f90 files, and drives exactly the loading path
  ! described by example/test.inp and example/parameters.inp:
  !
  !   isotropic start at sigma = (-100,-100,-100,0,0,0) kPa (example/initialconditions.inp)
  !   *TriaxialE1: 1000 increments, total axial strain -0.1 (-10 %), radial stress held at
  !   -100 kPa throughout (Newton iteration on the radial strain increment per step)
  !
  ! Its only purpose is to verify that the UMAT translation layer in material_models.f90
  ! introduces no transcription error (argument order, ntens/props/statev mapping, kstep/kinc,
  ! dstran vs. stress update convention): if this program and example/output_CD.out agree, the
  ! wrapper is behaving exactly like a direct call to the constitutive routine. It is deliberately
  ! independent of the UMAT/incrementalDriver code path.
  use precision_, only: rk, ik
  use compatibility_numgeo_, only: roscoe_pq_voigt
  use material_hardening_soil_MN_bricks_, only: hardening_soil_MN_bricks
  implicit none

  integer(ik), parameter :: NTENS = 6, NSTATEV = 73, NPROPS = 16
  integer(ik), parameter :: NINC = 1000
  real(rk), parameter :: SIG_R = -100.0_rk
  real(rk), parameter :: EPS_A_TOTAL = -0.1_rk
  real(rk), parameter :: TOL_R = 1.0e-8_rk

  real(rk) :: props(NPROPS)
  real(rk) :: stress(NTENS), statev(NSTATEV), dds_dde(NTENS,NTENS), dstrain(NTENS)
  real(rk) :: stress_try(NTENS), statev_try(NSTATEV), dds_dde_try(NTENS,NTENS)
  real(rk) :: deps_a, deps_r, res, res_old, x, x_old, dresdx, time, dtime
  real(rk) :: eps_a, p, q
  integer(ik) :: iinc, iter, iu
  integer(ik), parameter :: MAXIT = 80

  ! Glacial till, Cudny & Truty (2020) Eq. (44) - identical to example/parameters.inp
  props(1)  = 8.5e3_rk    ! E50
  props(2)  = 6.15e3_rk   ! Eoed
  props(3)  = 25.75e3_rk  ! Eur
  props(4)  = 0.7_rk      ! m
  props(5)  = 6.0_rk      ! c
  props(6)  = 28.0_rk     ! phi
  props(7)  = 6.0_rk      ! psi
  props(8)  = 0.29_rk     ! nu
  props(9)  = 100.0_rk    ! pref
  props(10) = 0.8_rk      ! K0nc
  props(11) = 0.9_rk      ! Rf
  props(12) = 15.46e3_rk  ! Eiref
  props(13) = 0.515_rk    ! alpha
  props(14) = 9.866e3_rk  ! Hpp
  props(15) = 3.0e-4_rk   ! gamma07
  props(16) = 60.0e3_rk   ! G0

  stress = 0.0_rk
  stress(1:3) = SIG_R
  statev = 0.0_rk
  dds_dde = 0.0_rk
  eps_a = 0.0_rk
  deps_a = EPS_A_TOTAL / real(NINC, kind=rk)
  deps_r = -0.5_rk * deps_a   ! initial guess for the first Newton iteration
  time = 0.0_rk
  dtime = 1.0_rk / real(NINC, kind=rk)

  open(newunit=iu, file='verify_direct_call.csv', status='replace', action='write')
  write(iu,'(a)') 'eps_a,stress1,stress2,stress3,statev6_Gm,statev7_n_bricks'
  call roscoe_pq_voigt(NTENS, stress, p, q)
  write(iu,'(es16.8,5(a,es16.8))') eps_a, ',', stress(1), ',', stress(2), ',', stress(3), ',', statev(6), ',', statev(7)

  do iinc = 1, NINC

    x = deps_r
    x_old = 0.0_rk
    res_old = 0.0_rk

    do iter = 1, MAXIT
      dstrain = 0.0_rk
      dstrain(1) = deps_a
      dstrain(2) = x
      dstrain(3) = x
      stress_try = stress
      statev_try = statev
      dds_dde_try = dds_dde
      call hardening_soil_MN_bricks(stress_try,statev_try,dds_dde_try,dstrain,time,dtime, &
                                     NTENS,NSTATEV,props,NPROPS,1_ik,iinc)
      res = stress_try(2) - SIG_R
      if (dabs(res) < TOL_R) then
        stress = stress_try
        statev = statev_try
        dds_dde = dds_dde_try
        exit
      end if
      if (iter == 1) then
        dresdx = dds_dde_try(2,2) + dds_dde_try(2,3)
      else
        dresdx = (res - res_old) / (x - x_old)
        if (dabs(dresdx) < 1.0e-30_rk) dresdx = dds_dde(2,2) + dds_dde(2,3)
      end if
      x_old = x
      res_old = res
      x = x - res/dresdx
      if (iter == MAXIT) write(*,'(a,i0)') 'WARNING: radial iteration not converged at increment ', iinc
    end do

    deps_r = x
    eps_a = eps_a + deps_a

    write(iu,'(es16.8,5(a,es16.8))') eps_a, ',', stress(1), ',', stress(2), ',', stress(3), ',', statev(6), ',', statev(7)

  end do

  close(iu)

  write(*,'(a)') 'Direct-call verification complete: verify_direct_call.csv written.'
  write(*,'(a,f14.6,a,f14.6,a,f14.6)') 'Final stress: sigma_1 = ', stress(1), '  sigma_2 = ', stress(2), &
                                       '  sigma_3 = ', stress(3)
  write(*,'(a,f10.6,a,i3)') 'Final Gm = ', statev(6), '   n_bricks = ', nint(statev(7))

end program verify_direct_call
