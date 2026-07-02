        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE SINV__genmod
          INTERFACE 
            SUBROUTINE SINV(STRESS,SINV1,SINV2,NDI,NSHR)
              INTEGER(KIND=4), INTENT(IN) :: NSHR
              INTEGER(KIND=4), INTENT(IN) :: NDI
              REAL(KIND=8), INTENT(IN) :: STRESS(NDI+NSHR)
              REAL(KIND=8), INTENT(OUT) :: SINV1
              REAL(KIND=8), INTENT(OUT) :: SINV2
            END SUBROUTINE SINV
          END INTERFACE 
        END MODULE SINV__genmod
