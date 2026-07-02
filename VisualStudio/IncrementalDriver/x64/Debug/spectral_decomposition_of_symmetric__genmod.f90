        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE SPECTRAL_DECOMPOSITION_OF_SYMMETRIC__genmod
          INTERFACE 
            SUBROUTINE SPECTRAL_DECOMPOSITION_OF_SYMMETRIC(A,LAM,G,N)
              INTEGER(KIND=4), INTENT(IN) :: N
              REAL(KIND=8), INTENT(IN) :: A(N,N)
              REAL(KIND=8), INTENT(OUT) :: LAM(N)
              REAL(KIND=8), INTENT(OUT) :: G(N,N)
            END SUBROUTINE SPECTRAL_DECOMPOSITION_OF_SYMMETRIC
          END INTERFACE 
        END MODULE SPECTRAL_DECOMPOSITION_OF_SYMMETRIC__genmod
