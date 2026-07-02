!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
!                                          numgeo
!                Copyright (C) 2018-2022 Jan Machacek, Patrick Staubach
!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
!
! MODULE: kind_parameter
!
!> author: Jan Machacek, jan-machacek@outlook.com
!> date: 11.11.2017
!
! DESCRIPTION:
!> Contains the kind values of a real, an integer and a character data type
!
!>### History
!>* 24.07.2017, Jan Machacek - Initial version
!
!>@todo
!! Remove rk and ik from all subroutines and replace by the precisions r* and i*
!>@endtodo
!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
module precision_
  use iso_c_binding, only: c_float, c_double

  implicit none

  private

  public :: precision_initialize

  ! Kind parameters
  integer, parameter, public  :: r8  = c_double
  integer, parameter, public  :: r4  = c_float

  integer, parameter, public  :: i8 = selected_int_kind(18)               !< Range \([-2^{63},+2^{63} - 1]\), 19 digits plus sign; 64 bits.
  integer, parameter, public  :: i4 = selected_int_kind(9)                !< Range \([-2^{31},+2^{31} - 1]\), 10 digits plus sign; 32 bits.
  integer, parameter, public  :: i2 = selected_int_kind(4)                !< Range \([-2^{15},+2^{15} - 1]\), 5  digits plus sign; 16 bits.
  integer, parameter, public  :: i1 = selected_int_kind(2)                !< Range \([-2^{7} ,+2^{7}  - 1]\), 3  digits plus sign; 8  bits.

  integer, parameter, public  :: rk = r8                                  !< Default real precision
  integer, parameter, public  :: ik = i4                                  !< Default integer precision
  integer, parameter, public  :: ck = selected_char_kind('default')       !< Default character precision

  ! Smallest number E of kind "rk" such that 1 + E > 1
  real(rk), parameter, public :: machine_precision = 2*epsilon(1.0_rk)

  ! Bits/bytes memory requirements of integers
  integer(i8), parameter, public :: i8Bytes = bit_size(huge(1_i8))/8_i8      !< Number of bytes of kind=i8 integer
  integer(i4), parameter, public :: i4Bytes = bit_size(huge(1_i4))/8_i4      !< Number of bytes of kind=i4 integer

  ! Bits/bytes memory requirements of real - must be calculated during runtime -
  integer(i1)           , public :: r8Bits                                   !< Number of bytes of kind=r8 real
  integer(i1)           , public :: r4Bits                                   !< Number of bytes of kind=r4 real
  integer(i1)           , public :: r8Bytes                                  !< Number of bytes of kind=r8 real
  integer(i1)           , public :: r4Bytes                                  !< Number of bytes of kind=r4 real

  contains

    subroutine precision_initialize()
      implicit none

      !r8Bits = huge(1._r8)
      !r4Bits = huge(1._r4)

      !r8Bytes = bit_size(r8Bits) / 8_i1
      !r4Bytes = bit_size(r4Bits) / 8_i1

    end subroutine precision_initialize



end module precision_
