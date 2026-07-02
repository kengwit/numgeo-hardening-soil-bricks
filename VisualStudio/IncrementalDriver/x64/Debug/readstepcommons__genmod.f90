        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE READSTEPCOMMONS__genmod
          INTERFACE 
            SUBROUTINE READSTEPCOMMONS(FROM,NINC,MAXITER,DELTATIME,EVERY&
     &)
              INTEGER(KIND=4), INTENT(IN) :: FROM
              INTEGER(KIND=4), INTENT(OUT) :: NINC
              INTEGER(KIND=4), INTENT(OUT) :: MAXITER
              REAL(KIND=8), INTENT(OUT) :: DELTATIME
              INTEGER(KIND=4), INTENT(OUT) :: EVERY
            END SUBROUTINE READSTEPCOMMONS
          END INTERFACE 
        END MODULE READSTEPCOMMONS__genmod
