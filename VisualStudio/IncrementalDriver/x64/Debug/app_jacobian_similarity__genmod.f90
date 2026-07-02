        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE APP_JACOBIAN_SIMILARITY__genmod
          INTERFACE 
            SUBROUTINE APP_JACOBIAN_SIMILARITY(A,P,Q,C,S,N)
              INTEGER(KIND=4), INTENT(IN) :: N
              REAL(KIND=8), INTENT(INOUT) :: A(N,N)
              INTEGER(KIND=4), INTENT(IN) :: P
              INTEGER(KIND=4), INTENT(IN) :: Q
              REAL(KIND=8), INTENT(IN) :: C
              REAL(KIND=8), INTENT(IN) :: S
            END SUBROUTINE APP_JACOBIAN_SIMILARITY
          END INTERFACE 
        END MODULE APP_JACOBIAN_SIMILARITY__genmod
