PROGRAM test_double_exponential
  implicit none

  integer, parameter :: DP = selected_real_kind( p = 15, r = 307 )
  real(kind=DP) :: a

  a = -0.39076809909199173_DP
  write (*, '(2 (e25.17, A, b64, A))') a, ' ', transfer(a,a), ' ', exp(a), ' ', transfer(exp(a), a)

END PROGRAM
