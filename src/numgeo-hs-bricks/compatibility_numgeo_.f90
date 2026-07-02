!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
!                                          numgeo
!                          Copyright (C) 2026 Jan Machacek
!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
!
! MODULE: compatibility_numgeo_
!
!> author: Jan Machacek, jan-machacek@outlook.com
!> date: 01.06.2026
!
! DESCRIPTION:
!> Compatibility layer extracted from the larger numgeo code base. It provides the
!> helper constants, stress-invariant routines and matrix-inversion utilities that are
!> required by the standalone Hardening Soil (Matsuoka-Nakai) material implementation
!> `material_hardening_soil_MN_`.
!>
!> This is a trimmed version of the full numgeo compatibility module: it contains ONLY
!> the routines used by the Hardening Soil model. All tensor/Voigt machinery that was
!> needed solely by the hypoplasticity models has been removed.
!
!> The following functionality is provided:
!>* constants pi and sq3
!>* cartesian_to_principal_stress_analytical - principal stresses from a Voigt stress vector
!>* roscoe_pq_voigt                          - Roscoe invariants p, q from a Voigt stress vector
!>* invariant_J2                             - second deviatoric stress invariant J2
!>* invariants_J2_J3                         - second and third deviatoric stress invariants J2, J3
!>* matinv4x4                                - inverse of a 4x4 matrix (analytic)
!>* matinv6x6_gauss_jordan                   - inverse of a 6x6 matrix (Gauss-Jordan, partial pivoting)
!>* get_eye                                  - identity matrix of arbitrary order
!
!>### History
!>* 01.06.2026, J. Machacek - Trimmed for the standalone Hardening Soil release; only the routines
!                            required by material_hardening_soil_MN_ are retained, everything
!                            solely related to the hypoplasticity models has been removed.
!=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
module compatibility_numgeo_
  use precision_, only: rk, ik

  implicit none

  private

  public :: pi, sq3
  public :: cartesian_to_principal_stress_analytical
  public :: roscoe_pq_voigt
  public :: invariant_J2, invariants_J2_J3
  public :: matinv4x4, matinv6x6_gauss_jordan
  public :: get_eye

  !
  ! some constants
  !
  real(rk), parameter :: pi  = 3.14159265358979311599796346854_rk
  real(rk), parameter :: sq3 = 1.7320508075688772935274463415059_rk

  !
  ! interfaces
  !
  interface matinv4x4
    module procedure :: matinv4x4_r8
  end interface

  contains

  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 24.10.2024
  !
  !> Calculates the principal stresses from a cartesian (Voigt) stress vector using the
  !> analytical (Lode-angle) solution. Based on the Eig_3 routine (Anura3D/Plaxis).
  !> Principal stresses are returned in descending order (S(1) >= S(2) >= S(3)).
  !>
  !> Voigt ordering used by numgeo: [xx, yy, zz, xy, xz, yz]
  !
  !>### History
  !>* 24.10.2024, J. Machacek - Initial version
  !>* 01.06.2026, J. Machacek - Extracted into the standalone compatibility layer (HS release)
  !
  pure function cartesian_to_principal_stress_analytical(ntens,stress) result(S)
    use precision_, only: rk, ik
    implicit none

    integer(ik), intent(in) :: ntens      ! Number of stress components (4 for plane, 6 for 3D)
    real(rk), intent(in) :: stress(ntens) ! Stress vector [sig_xx, sig_yy, sig_zz, tau_xy, (tau_xz, tau_yz)]
    real(rk) :: S(3)                      ! Principal stresses in descending order

    real(rk) :: I1, J2, J3, p, s1, s2, s3
    real(rk) :: sin3lode, lode, sqJ2
    real(rk) :: two_pi_thirds, two_over_sqrt3, sin3lode_factor

    S = 0.0_rk
    if ( all(abs(stress) < 1e-12_rk) ) return

    ! Constants (pi and sq3=sqrt(3) are inherited from the parent module)
    two_pi_thirds = 2.0_rk * pi / 3.0_rk
    two_over_sqrt3 = 2.0_rk / sq3
    sin3lode_factor = 1.5_rk * sq3

    ! First invariant and mean stress
    I1 = stress(1) + stress(2) + stress(3)
    p = I1 / 3.0_rk

    ! Deviatoric normal stresses
    s1 = stress(1) - p
    s2 = stress(2) - p
    s3 = stress(3) - p

    if (ntens == 4) then
      ! Plane case
      J2 = 0.5_rk * (s1*s1 + s2*s2 + s3*s3) + stress(4)*stress(4)
      J3 = (s1*s1*s1 + s2*s2*s2 + s3*s3*s3 + 3.0_rk*stress(4)*stress(4)*(s1 + s2)) / 3.0_rk
    else
      ! General 3D
      J2 = 0.5_rk * (s1*s1 + s2*s2 + s3*s3) + stress(4)*stress(4) + stress(5)*stress(5) + stress(6)*stress(6)
      J3 = (s1*s1*s1 + s2*s2*s2 + s3*s3*s3 + 6.0_rk*stress(4)*stress(5)*stress(6) + 3.0_rk*(s1*(stress(4)*stress(4) + stress(5)*stress(5)) &
            + s2*(stress(4)*stress(4) + stress(6)*stress(6)) + s3*(stress(5)*stress(5) + stress(6)*stress(6)))) / 3.0_rk
    end if

    ! Near-hydrostatic state
    if (J2 < 1.0e-30_rk * I1*I1) then
      S(1) = max(stress(1), stress(2), stress(3))
      S(3) = min(stress(1), stress(2), stress(3))
      S(2) = I1 - S(1) - S(3)
      return
    end if

    ! Lode angle from sin(3*lode) = -3*sqrt(3)/2 * J3 / J2^(3/2)
    sin3lode = -sin3lode_factor * J3 / (J2 * sqrt(J2))
    sin3lode = max(-1.0_rk, min(1.0_rk, sin3lode))
    lode = asin(sin3lode) / 3.0_rk

    ! Principal stresses (descending order for lode in [-pi/6, pi/6])
    sqJ2 = two_over_sqrt3 * sqrt(J2)
    S(1) = sqJ2 * sin(lode + two_pi_thirds) + p
    S(2) = sqJ2 * sin(lode) + p
    S(3) = sqJ2 * sin(lode - two_pi_thirds) + p

  end function cartesian_to_principal_stress_analytical


  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 23.12.2025
  !
  !> Returns the Roscoe invariants of the Voigt stress vector `stress`:
  !>   p = -(s_11 + s_22 + s_33)/3   (mean stress, compression-positive Roscoe convention)
  !>   q = sqrt(3 * J2)              (deviatoric stress)
  !> Voigt ordering: [11, 22, 33, 12, 13, 23]
  !
  !>### History
  !>* 23.12.2025, J. Machacek - Initial version
  !>* 01.06.2026, J. Machacek - Extracted into the standalone compatibility layer (HS release)
  !
  subroutine roscoe_pq_voigt(ntens,stress,p,q)
    use precision_, only: rk, ik
    implicit none

    integer(ik), intent(in) :: ntens
    real(rk), intent(in) :: stress(ntens)
    real(rk), intent(out) :: p
    real(rk), intent(out) :: q

    real(rk) :: J2, dev(3)

    ! Mean stress (compression positive Roscoe convention)
    p = -(stress(1) + stress(2) + stress(3)) / 3.0_rk

    ! Deviatoric normal stresses
    dev(1) = stress(1) + p
    dev(2) = stress(2) + p
    dev(3) = stress(3) + p

    ! J2 = (1/2) * s_ij * s_ij (factor 2 on shear from tensor symmetry)
    if (ntens == 6) then
      J2 = 0.5_rk * (dev(1)**2 + dev(2)**2 + dev(3)**2) + stress(4)**2 + stress(5)**2 + stress(6)**2
    else  ! ntens == 4 (plane strain / axisymmetric)
      J2 = 0.5_rk * (dev(1)**2 + dev(2)**2 + dev(3)**2) + stress(4)**2
    end if

    ! Deviatoric stress
    q = sqrt(3.0_rk * J2)

  end subroutine roscoe_pq_voigt


  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 23.12.2025
  !
  !> Returns the second deviatoric stress invariant J2 = (1/2) * s_ij * s_ij of the
  !> Voigt stress vector `stress`. Voigt ordering: [11, 22, 33, 12, 13, 23]
  !
  !>### History
  !>* 23.12.2025, J. Machacek - Initial version
  !>* 01.06.2026, J. Machacek - Extracted into the standalone compatibility layer (HS release)
  !
  pure function invariant_J2(stress, ntens) result(J2)
    use precision_, only: rk, ik
    implicit none

    integer(ik), intent(in) :: ntens
    real(rk), intent(in) :: stress(ntens)
    real(rk) :: J2

    real(rk) :: s1, s2, s3, mean

    ! Mean normal stress
    mean = (stress(1) + stress(2) + stress(3)) / 3.0_rk

    ! Deviatoric normal stresses
    s1 = stress(1) - mean
    s2 = stress(2) - mean
    s3 = stress(3) - mean

    ! J2 = (1/2) * s_ij * s_ij
    if (ntens == 6) then
      J2 = 0.5_rk * (s1*s1 + s2*s2 + s3*s3) + stress(4)*stress(4) + stress(5)*stress(5) + stress(6)*stress(6)
    else  ! ntens == 4
      J2 = 0.5_rk * (s1*s1 + s2*s2 + s3*s3) + stress(4)*stress(4)
    end if

  end function invariant_J2


  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 23.12.2025
  !
  !> Returns the second and third deviatoric stress invariants J2 and J3 of the Voigt
  !> stress vector `stress`. Voigt ordering: [11, 22, 33, 12, 13, 23]
  !>   J2 = (1/2) * s_ij * s_ij
  !>   J3 = det(s_ij)
  !
  !>### History
  !>* 23.12.2025, J. Machacek - Initial version
  !>* 01.06.2026, J. Machacek - Extracted into the standalone compatibility layer (HS release)
  !
  pure subroutine invariants_J2_J3(stress, ntens, J2, J3)
    use precision_, only: rk, ik
    implicit none

    integer(ik), intent(in) :: ntens
    real(rk), intent(in) :: stress(ntens)
    real(rk), intent(out) :: J2
    real(rk), intent(out) :: J3

    real(rk) :: s1, s2, s3, s12, s13, s23, mean

    ! Mean normal stress
    mean = (stress(1) + stress(2) + stress(3)) / 3.0_rk

    ! Deviatoric normal stresses
    s1 = stress(1) - mean
    s2 = stress(2) - mean
    s3 = stress(3) - mean

    s12 = stress(4)

    if (ntens == 6) then
      s13 = stress(5)
      s23 = stress(6)
      J2 = 0.5_rk * (s1*s1 + s2*s2 + s3*s3) + s12*s12 + s13*s13 + s23*s23
      J3 = s1*s2*s3 + 2.0_rk*s12*s13*s23 - s1*s23*s23 - s2*s13*s13 - s3*s12*s12
    else  ! ntens == 4 (plane strain / axisymmetric), s13 = s23 = 0
      J2 = 0.5_rk * (s1*s1 + s2*s2 + s3*s3) + s12*s12
      J3 = s1*s2*s3 - s3*s12*s12
    end if

  end subroutine invariants_J2_J3


  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 24.11.2018
  !
  !> Performs a direct calculation of the inverse of a 4x4 matrix in double precision.
  !
  !>### History
  !>* 24.11.2018, J. Machacek - Initial version
  !>* 01.06.2026, J. Machacek - Retained in the standalone compatibility layer (HS release)
  !
  pure function matinv4x4_r8(A) result(B)
    use precision_, only: r8
    implicit none
    real(r8), intent(in) :: A(4,4)   !! Matrix
    real(r8)             :: B(4,4)   !! Inverse matrix
    real(r8)             :: detinv

    ! Inverse determinant of the matrix
    detinv = &
      1.0_r8 / ( A(1,1)*(A(2,2)*(A(3,3)*A(4,4)-A(3,4)*A(4,3))+A(2,3)*(A(3,4)*A(4,2) &
                         -A(3,2)*A(4,4))+A(2,4)*(A(3,2)*A(4,3)-A(3,3)*A(4,2)))      &
               - A(1,2)*(A(2,1)*(A(3,3)*A(4,4)-A(3,4)*A(4,3))+A(2,3)*(A(3,4)*A(4,1) &
                         -A(3,1)*A(4,4))+A(2,4)*(A(3,1)*A(4,3)-A(3,3)*A(4,1)))      &
               + A(1,3)*(A(2,1)*(A(3,2)*A(4,4)-A(3,4)*A(4,2))+A(2,2)*(A(3,4)*A(4,1) &
                         -A(3,1)*A(4,4))+A(2,4)*(A(3,1)*A(4,2)-A(3,2)*A(4,1)))      &
               - A(1,4)*(A(2,1)*(A(3,2)*A(4,3)-A(3,3)*A(4,2))+A(2,2)*(A(3,3)*A(4,1) &
                         -A(3,1)*A(4,3))+A(2,3)*(A(3,1)*A(4,2)-A(3,2)*A(4,1))) )

    ! Inverse of the matrix
    B(1,1) = A(2,2)*(A(3,3)*A(4,4)-A(3,4)*A(4,3))+A(2,3)*(A(3,4)*A(4,2)-A(3,2)*A(4,4))+A(2,4)*(A(3,2)*A(4,3)-A(3,3)*A(4,2))
    B(2,1) = A(2,1)*(A(3,4)*A(4,3)-A(3,3)*A(4,4))+A(2,3)*(A(3,1)*A(4,4)-A(3,4)*A(4,1))+A(2,4)*(A(3,3)*A(4,1)-A(3,1)*A(4,3))
    B(3,1) = A(2,1)*(A(3,2)*A(4,4)-A(3,4)*A(4,2))+A(2,2)*(A(3,4)*A(4,1)-A(3,1)*A(4,4))+A(2,4)*(A(3,1)*A(4,2)-A(3,2)*A(4,1))
    B(4,1) = A(2,1)*(A(3,3)*A(4,2)-A(3,2)*A(4,3))+A(2,2)*(A(3,1)*A(4,3)-A(3,3)*A(4,1))+A(2,3)*(A(3,2)*A(4,1)-A(3,1)*A(4,2))
    B(1,2) = A(1,2)*(A(3,4)*A(4,3)-A(3,3)*A(4,4))+A(1,3)*(A(3,2)*A(4,4)-A(3,4)*A(4,2))+A(1,4)*(A(3,3)*A(4,2)-A(3,2)*A(4,3))
    B(2,2) = A(1,1)*(A(3,3)*A(4,4)-A(3,4)*A(4,3))+A(1,3)*(A(3,4)*A(4,1)-A(3,1)*A(4,4))+A(1,4)*(A(3,1)*A(4,3)-A(3,3)*A(4,1))
    B(3,2) = A(1,1)*(A(3,4)*A(4,2)-A(3,2)*A(4,4))+A(1,2)*(A(3,1)*A(4,4)-A(3,4)*A(4,1))+A(1,4)*(A(3,2)*A(4,1)-A(3,1)*A(4,2))
    B(4,2) = A(1,1)*(A(3,2)*A(4,3)-A(3,3)*A(4,2))+A(1,2)*(A(3,3)*A(4,1)-A(3,1)*A(4,3))+A(1,3)*(A(3,1)*A(4,2)-A(3,2)*A(4,1))
    B(1,3) = A(1,2)*(A(2,3)*A(4,4)-A(2,4)*A(4,3))+A(1,3)*(A(2,4)*A(4,2)-A(2,2)*A(4,4))+A(1,4)*(A(2,2)*A(4,3)-A(2,3)*A(4,2))
    B(2,3) = A(1,1)*(A(2,4)*A(4,3)-A(2,3)*A(4,4))+A(1,3)*(A(2,1)*A(4,4)-A(2,4)*A(4,1))+A(1,4)*(A(2,3)*A(4,1)-A(2,1)*A(4,3))
    B(3,3) = A(1,1)*(A(2,2)*A(4,4)-A(2,4)*A(4,2))+A(1,2)*(A(2,4)*A(4,1)-A(2,1)*A(4,4))+A(1,4)*(A(2,1)*A(4,2)-A(2,2)*A(4,1))
    B(4,3) = A(1,1)*(A(2,3)*A(4,2)-A(2,2)*A(4,3))+A(1,2)*(A(2,1)*A(4,3)-A(2,3)*A(4,1))+A(1,3)*(A(2,2)*A(4,1)-A(2,1)*A(4,2))
    B(1,4) = A(1,2)*(A(2,4)*A(3,3)-A(2,3)*A(3,4))+A(1,3)*(A(2,2)*A(3,4)-A(2,4)*A(3,2))+A(1,4)*(A(2,3)*A(3,2)-A(2,2)*A(3,3))
    B(2,4) = A(1,1)*(A(2,3)*A(3,4)-A(2,4)*A(3,3))+A(1,3)*(A(2,4)*A(3,1)-A(2,1)*A(3,4))+A(1,4)*(A(2,1)*A(3,3)-A(2,3)*A(3,1))
    B(3,4) = A(1,1)*(A(2,4)*A(3,2)-A(2,2)*A(3,4))+A(1,2)*(A(2,1)*A(3,4)-A(2,4)*A(3,1))+A(1,4)*(A(2,2)*A(3,1)-A(2,1)*A(3,2))
    B(4,4) = A(1,1)*(A(2,2)*A(3,3)-A(2,3)*A(3,2))+A(1,2)*(A(2,3)*A(3,1)-A(2,1)*A(3,3))+A(1,3)*(A(2,1)*A(3,2)-A(2,2)*A(3,1))
    B = detinv * B

  end function matinv4x4_r8


  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 01.06.2026
  !
  !> Inverse of a 6x6 matrix by Gauss-Jordan elimination with partial (row) pivoting.
  !> The matrix inverse is unique, so the result is identical (up to round-off) to any
  !> other correct inversion routine.
  !
  !>### History
  !>* 01.06.2026, J. Machacek - Standalone implementation for the HS release
  !
  function matinv6x6_gauss_jordan(A) result(B)
    use precision_, only: rk, ik
    implicit none
    real(rk), intent(in) :: A(6,6)   !! Matrix
    real(rk)             :: B(6,6)   !! Inverse matrix

    integer(ik), parameter :: n = 6
    real(rk) :: M(n,n), row(n), pivot, factor
    integer(ik) :: i, k, prow

    ! Working copy of A and identity in B
    M = A
    B = 0.0_rk
    do i = 1, n
      B(i,i) = 1.0_rk
    end do

    do k = 1, n
      ! Partial pivoting: largest magnitude entry in column k, on or below the diagonal
      prow = k
      pivot = abs(M(k,k))
      do i = k+1, n
        if (abs(M(i,k)) > pivot) then
          pivot = abs(M(i,k))
          prow = i
        end if
      end do

      ! Swap rows k and prow (in both M and B)
      if (prow /= k) then
        row      = M(k,:) ; M(k,:) = M(prow,:) ; M(prow,:) = row
        row      = B(k,:) ; B(k,:) = B(prow,:) ; B(prow,:) = row
      end if

      ! Normalise the pivot row
      pivot  = M(k,k)
      M(k,:) = M(k,:) / pivot
      B(k,:) = B(k,:) / pivot

      ! Eliminate column k from all other rows
      do i = 1, n
        if (i /= k) then
          factor = M(i,k)
          M(i,:) = M(i,:) - factor * M(k,:)
          B(i,:) = B(i,:) - factor * B(k,:)
        end if
      end do
    end do

  end function matinv6x6_gauss_jordan


  !=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~~=~=~
  !
  !> author: Jan Machacek, jan-machacek@outlook.com
  !> date: 01.06.2026
  !
  !> Returns the identity matrix `eye` of order n.
  !
  !>### History
  !>* 01.06.2026, J. Machacek - Standalone implementation for the HS release
  !
  pure subroutine get_eye(n, eye)
    use precision_, only: rk, ik
    implicit none
    integer(ik), intent(in) :: n
    real(rk), intent(out) :: eye(n,n)
    integer(ik) :: i

    eye = 0.0_rk
    do i = 1, n
      eye(i,i) = 1.0_rk
    end do

  end subroutine get_eye


end module compatibility_numgeo_
