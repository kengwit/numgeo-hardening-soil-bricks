        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE SPLITALINE__genmod
          INTERFACE 
            SUBROUTINE SPLITALINE(ALINE,SEP,LEFT,RIGHT,OK)
              CHARACTER(LEN=40), INTENT(IN) :: ALINE
              CHARACTER(LEN=1), INTENT(IN) :: SEP
              CHARACTER(LEN=40), INTENT(OUT) :: LEFT
              CHARACTER(LEN=40), INTENT(OUT) :: RIGHT
              LOGICAL(KIND=4) :: OK
            END SUBROUTINE SPLITALINE
          END INTERFACE 
        END MODULE SPLITALINE__genmod
