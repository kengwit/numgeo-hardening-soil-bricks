        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE SPRINC__genmod
          INTERFACE 
            SUBROUTINE SPRINC(S,PS,LSTR,NDI,NSHR)
              INTEGER(KIND=4), INTENT(IN) :: NSHR
              INTEGER(KIND=4), INTENT(IN) :: NDI
              REAL(KIND=8), INTENT(IN) :: S(NDI+NSHR)
              REAL(KIND=8), INTENT(OUT) :: PS(NDI+NSHR)
              INTEGER(KIND=4), INTENT(IN) :: LSTR
            END SUBROUTINE SPRINC
          END INTERFACE 
        END MODULE SPRINC__genmod
