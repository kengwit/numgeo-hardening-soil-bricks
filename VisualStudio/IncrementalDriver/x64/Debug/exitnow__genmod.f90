        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE EXITNOW__genmod
          INTERFACE 
            FUNCTION EXITNOW(COND,STRESS,STRAN,STATEV,NSTATV)
              INTEGER(KIND=4), INTENT(IN) :: NSTATV
              CHARACTER(LEN=40), INTENT(IN) :: COND
              REAL(KIND=8), INTENT(IN) :: STRESS(6)
              REAL(KIND=8), INTENT(IN) :: STRAN(6)
              REAL(KIND=8), INTENT(IN) :: STATEV(NSTATV)
              LOGICAL(KIND=4) :: EXITNOW
            END FUNCTION EXITNOW
          END INTERFACE 
        END MODULE EXITNOW__genmod
