        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE GET_JACOBIAN_ROT__genmod
          INTERFACE 
            SUBROUTINE GET_JACOBIAN_ROT(A,P,Q,C,S,N)
              INTEGER(KIND=4), INTENT(IN) :: N
              REAL(KIND=8), INTENT(IN) :: A(N,N)
              INTEGER(KIND=4), INTENT(OUT) :: P
              INTEGER(KIND=4), INTENT(OUT) :: Q
              REAL(KIND=8), INTENT(OUT) :: C
              REAL(KIND=8), INTENT(OUT) :: S
            END SUBROUTINE GET_JACOBIAN_ROT
          END INTERFACE 
        END MODULE GET_JACOBIAN_ROT__genmod
