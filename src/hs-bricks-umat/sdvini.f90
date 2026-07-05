subroutine sdvini(statev,coords,nstatv,ncrds,noel,npt,layer,kspt)
  implicit none
  
  integer, intent(in) :: nstatv, ncrds, noel, npt, layer, kspt
  real(8), intent(in) :: coords(ncrds)
  real(8), intent(inout) :: statev(nstatv)

  statev = 0.0d0

  ! initialize pop
  statev(3) = 100.0d0

end subroutine sdvini