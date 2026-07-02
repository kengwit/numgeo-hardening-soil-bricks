!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
!                                          numgeo
!                          Copyright (C) 2026 Jan Machacek
!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
!
! PROGRAM: calibrate_hs_bricks
!
!> author: Jan Machacek, jan-machacek@outlook.com
!> date: 02.07.2026
!
! DESCRIPTION:
!> Small standalone tool whose only task is to calibrate the internal cap constants alpha
!> (props(13)) and Hpp (props(14)) of the Hardening-Soil-MN-Bricks model from the primary
!> material parameters, using the model's own calibration routine
!> optimize_hs_bricks_internal_constants (a virtual oedometer test, see README).
!>
!> The program prompts for the path of a parameter file at the start, reads props(1:16) from
!> it, runs the calibration, and prints alpha and Hpp back to the user. It does not write any
!> output file: the calibrated constants are only meant to be copied by hand into props(13) and
!> props(14) of the real parameter file used for the analysis.
!>
!> The expected parameter file has exactly the format of example/parameters.inp:
!>
!>   <cmname>            free text, not evaluated
!>   16                  nprops, must be 16 for Hardening-Soil-MN-Bricks
!>   E50
!>   Eoed
!>   Eur
!>   m
!>   c
!>   phi
!>   psi
!>   nu
!>   pref
!>   K0nc
!>   Rf
!>   Ei
!>   alpha               ignored - overwritten by the calibration
!>   Hpp                 ignored - overwritten by the calibration
!>   gamma07
!>   G0
!>
!> so an existing parameters.inp (with alpha = 0, Hpp = 0, as used to request automatic
!> calibration from numgeo/the UMAT wrapper) can be pointed to directly. Trailing text on a
!> value's line (as in the "set 0.0 for automatic calibration" comments of the example file) is
!> harmless: each value is read with a list-directed read of its own line, exactly as in
!> incrementalDriver.f, so anything after the number is simply ignored.
!>
!> gamma07 and G0 (props(15), props(16)) do not influence the calibrated alpha/Hpp (the
!> calibration is performed with the small-strain hardening enhancement fixed at H_i = 1, see
!> objective_function in numgeo_hardening_soil_MN_bricks_.f90), but material_collect_properties
!> still validates them (G0 >= Gur_ref, gamma07 > 0), so both must be present and consistent with
!> the other parameters or the run will stop with a diagnostic message.
!
!>### History
!>* 02.07.2026, J. Machacek - Initial version
!
!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
program calibrate_hs_bricks

  use precision_, only: rk, ik
  use material_hardening_soil_MN_bricks_, only: optimize_hs_bricks_internal_constants

  implicit none

  integer(ik), parameter :: NPROPS_REQUIRED = 16

  character(len=256) :: filename
  character(len=256) :: cmname
  integer(ik) :: nprops, i, iu, ios
  real(rk), allocatable :: props(:)

  write(*,'(a)') 'Hardening-Soil-MN-Bricks - calibration of alpha and Hpp'
  write(*,'(a)') '========================================================='
  write(*,'(a)') 'This tool only calibrates the internal cap constants alpha and Hpp.'
  write(*,'(a)') ' '
  write(*,'(a)') 'Enter the path of the parameter file (same format as example/parameters.inp):'
  read(*,'(a)') filename
  filename = adjustl(filename)

  open(newunit=iu, file=trim(filename), status='old', action='read', iostat=ios)
  if (ios /= 0) then
    write(*,'(a)') 'Error: could not open file "'//trim(filename)//'"'
    stop 1
  end if

  read(iu,'(a)',iostat=ios) cmname
  if (ios /= 0) then
    write(*,'(a)') 'Error: could not read the material name (first line) from the parameter file'
    stop 1
  end if

  read(iu,*,iostat=ios) nprops
  if (ios /= 0) then
    write(*,'(a)') 'Error: could not read nprops (second line) from the parameter file'
    stop 1
  end if

  if (nprops /= NPROPS_REQUIRED) then
    write(*,'(a,i0,a,i0,a)') 'Error: the parameter file specifies nprops = ', nprops, &
                              ', but the Hardening-Soil-MN-Bricks model requires nprops = ', NPROPS_REQUIRED, &
                              ' (props(15) = gamma07, props(16) = G0ref must be present).'
    stop 1
  end if

  allocate(props(nprops))

  do i = 1, nprops
    read(iu,*,iostat=ios) props(i)
    if (ios /= 0) then
      write(*,'(a,i0,a)') 'Error: could not read props(', i, ') from the parameter file'
      stop 1
    end if
  end do

  close(iu)

  write(*,'(a)') ' '
  write(*,'(a)') 'Parameters read successfully. Running the calibration (virtual oedometer test)...'

  call optimize_hs_bricks_internal_constants(props, nprops)

  write(*,'(a)') ' '
  write(*,'(a)') 'Calibration complete:'
  write(*,'(a,es16.8)') '  alpha (props(13)) = ', props(13)
  write(*,'(a,es16.8)') '  Hpp   (props(14)) = ', props(14)
  write(*,'(a)') ' '
  write(*,'(a)') 'Copy these two values into props(13) and props(14) of your Hardening-Soil-MN-Bricks input.'

  deallocate(props)

end program calibrate_hs_bricks
