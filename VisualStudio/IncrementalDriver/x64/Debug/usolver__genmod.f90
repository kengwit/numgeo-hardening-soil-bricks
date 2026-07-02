        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE USOLVER__genmod
          INTERFACE 
            SUBROUTINE USOLVER(KK,U,RHS,IS,NTENS)
              INTEGER(KIND=4), INTENT(IN) :: NTENS
              REAL(KIND=8), INTENT(IN) :: KK(1:NTENS,1:NTENS)
              REAL(KIND=8), INTENT(INOUT) :: U(1:NTENS)
              REAL(KIND=8), INTENT(INOUT) :: RHS(1:NTENS)
              INTEGER(KIND=4), INTENT(IN) :: IS(1:NTENS)
            END SUBROUTINE USOLVER
          END INTERFACE 
        END MODULE USOLVER__genmod
