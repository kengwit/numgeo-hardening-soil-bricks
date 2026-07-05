!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
!                                          numgeo
!                          Copyright (C) 2026 Jan Machacek
!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
!
!> author: Jan Machacek, jan-machacek@outlook.com
!> date: 01.06.2026
!
! DESCRIPTION:
!> Minimal Abaqus UMAT interface for the Hardening-Soil-MN-Bricks model, forming a small
!> standalone library together with precision_.f90, compatibility_numgeo_.f90 and
!> numgeo_hardening_soil_MN_bricks_.f90 (the numgeo constitutive module and its compatibility
!> layer, unmodified, see README.md in this folder). No other file in this library depends on
!> anything outside these four files: it can be dropped into any UMAT-based build (Abaqus, or any
!> other host that calls a Fortran UMAT-convention subroutine) on its own, without the
!> incrementalDriver/tools/example infrastructure of the fuller numgeo-hardening-soil repository.
!>
!> This wrapper only exposes:
!>* Hardening-Soil-MN-Bricks : Hardening Soil model with Matsuoka-Nakai yield surface and the
!>                              BRICK small-strain stiffness extension
!
!>### History
!>* 11.04.2026, J. Machacek - Initial version (as part of the numgeo-hardening-soil repository)
!>* 01.06.2026, J. Machacek - Reworked for the standalone Hardening Soil release
!>* 02.07.2026, J. Machacek - Extracted into this minimal standalone UMAT library and switched to
!                            the Hardening-Soil-MN-Bricks model (small-strain stiffness extension):
!                            nprops 14->16, nstatev 5->73, calls hardening_soil_MN_bricks /
!                            optimize_hs_bricks_internal_constants. Model identifier now matched
!                            with an exact string comparison instead of index(model,...)>0: a
!                            substring match is unsafe once another model name is a prefix of this
!                            one (as is the case here, 'Hardening-Soil-MN' is a prefix of
!                            'Hardening-Soil-MN-Bricks').
!
!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
  
!
! Abaqus user subroutine for constitutive models
!

subroutine umat(stress,statev,ddsdde,sse,spd,scd,rpl,ddsddt,drplde,drpldt, &
                stran,dstran,time,dtime,temp,dtemp,predef,dpred,cmname,&
                ndi,nshr,ntens,nstatev,props,nprops,coords,drot,pnewdt,&
                celent,dfgrd0,dfgrd1,noel,npt,layer,kspt,kstep,kinc)

  ! For compatibility with numgeo
  use precision_, only: rk, ik
  use material_hardening_soil_MN_bricks_, only: hardening_soil_MN_bricks, optimize_hs_bricks_internal_constants

  implicit none

  character*80 cmname

  integer :: ntens,nstatev,nprops,ndi,nshr,noel,npt,layer,kspt,kstep,kinc

  real(rk) :: sse,spd,scd,rpl,drpldt,dtime,temp,dtemp,pnewdt,celent

  real(rk) :: stress(ntens),statev(nstatev),ddsdde(ntens,ntens),ddsddt(ntens),drplde(ntens), &
              stran(ntens),dstran(ntens),time(2),predef(1),dpred(1), &
              props(nprops),coords(3),drot(3,3),dfgrd0(3,3),dfgrd1(3,3)

  ! For compatibility with numgeo
  character*50 :: model                     ! string for identifying the material model to be called

  integer(ik), parameter :: NPROPS_REQUIRED = 16    ! Hardening-Soil-MN-Bricks: props(15)=gamma07, props(16)=G0ref
  integer(ik), parameter :: NSTATEV_REQUIRED = 73   ! statev(6)=Gm, statev(7)=n_bricks, statev(8:73)=brick strain history

  integer(ik) :: isp                         ! position of the first blank after the model name token

  !
  ! Evaluate material model identifier and call corresponding constitutive model routine
  !
  ! Note: an exact comparison of the first whitespace-delimited token (not a substring search
  ! over the full line) is used deliberately. The cmname line in parameters.inp customarily
  ! carries a trailing descriptive label (e.g. "Hardening-Soil-MN-Bricks     cmname"), so the raw
  ! line cannot be compared as-is; and 'Hardening-Soil-MN' is itself a prefix of
  ! 'Hardening-Soil-MN-Bricks', so index(model,'Hardening-Soil-MN') > 0 would also match this
  ! model's own name (and would silently swallow every Bricks request if the base model were
  ! ever reintroduced as a second, earlier-checked branch).

  model = adjustl(cmname)
  isp = index(trim(model)//' ', ' ')     ! first blank after the (left-justified) name token
  if (isp > 1) model = model(1:isp-1)

  if (model == 'HARDENING-SOIL-MN-BRICKS') then

    !
    ! Hardening Soil model with Matsuoka-Nakai yield surface and BRICK small-strain stiffness
    !

    ! Documentation of the required properties for the Hardening Soil (MN, Bricks) model can be
    ! found in the online numgeo documentation:
    ! https://j-machacek.github.io/numgeo/

    if (nprops /= NPROPS_REQUIRED) then
      write(*,*) 'Error: nprops not correct for Hardening-Soil-MN-Bricks model. required nprops = ', NPROPS_REQUIRED
      stop
    end if

    if (nstatev /= NSTATEV_REQUIRED) then
      write(*,*) 'Error: nstatev not correct for Hardening-Soil-MN-Bricks model. required nstatev = ', NSTATEV_REQUIRED
      stop
    end if

    ! The Hardening Soil (MN, Bricks) model has no optional properties.
    ! Note: props(13) = alpha and props(14) = Hpp are internal constants; they are obtained once
    ! from the primary parameters using the routine optimize_hs_bricks_internal_constants (see
    ! README, or use the standalone calibration tool in tools/calibrate_hs_bricks.f90).
    ! The scalar model time argument is unused by the model; time(1) (step time) is passed.

    if ( props(13) <= 1e-6_rk .and. props(14) <= 1e-6_rk ) then
      ! should be executed only once at the very beginning of an analysis
      ! since Incremental driver is serial by nature, this is easily done here
      ! in Abaqus another approach will be required, e.g.
      ! 1) using statevs to store the two parameters. Then the material model needs some modification.
      ! 2) using uexternaldb to interact with abaqus before the first call of the constitutive model
      
	  ! call optimize_hs_bricks_internal_constants(props, NPROPS_REQUIRED)
      ! write(*,*) 'Hardening-Soil-MN-Bricks model determined internal constants using optimisation process: ' // &
      !           'alpha = ', props(13), ', Hpp = ', props(14), '.'

	  write(*,*) 'Hardening-Soil-MN-Bricks model internal constants alpha and Hpp are zero ' // & 
                 'We suggest to use the small executable numgeo-hs-bricks-calibration also ' // &
				 'shipped with this code to calibrate the parameters beforehand and pass ' // &
                 'them via the props array'
	  stop
    end if

    call hardening_soil_MN_bricks(stress,statev,ddsdde,dstran,time(1),dtime,ntens,nstatev,props,nprops,kstep,kinc)

  else

    write(*,*) ' '
    write(*,*) 'Error: material model identifier not correct.'
    write(*,*) ' Model passed to umat: ' // model
    write(*,*) ' '
    write(*,*) 'choose one of the following models:'
    write(*,*) 'HARDENING-SOIL-MN-BRICKS'
    stop

  end if

  return

end subroutine umat
