        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE ROTSIG__genmod
          INTERFACE 
            SUBROUTINE ROTSIG(S,R,SPRIME,LSTR,NDI,NSHR)
              INTEGER(KIND=4), INTENT(IN) :: NSHR
              INTEGER(KIND=4), INTENT(IN) :: NDI
              REAL(KIND=8), INTENT(IN) :: S(1:NDI+NSHR)
              REAL(KIND=8), INTENT(IN) :: R(3,3)
              REAL(KIND=8), INTENT(OUT) :: SPRIME(1:NDI+NSHR)
              INTEGER(KIND=4), INTENT(IN) :: LSTR
            END SUBROUTINE ROTSIG
          END INTERFACE 
        END MODULE ROTSIG__genmod
