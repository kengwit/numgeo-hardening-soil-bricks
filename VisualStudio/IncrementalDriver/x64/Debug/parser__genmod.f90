        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE PARSER__genmod
          INTERFACE 
            SUBROUTINE PARSER(INPUTLINE,MT,ME,MB)
              CHARACTER(LEN=260), INTENT(IN) :: INPUTLINE(6)
              REAL(KIND=8), INTENT(OUT) :: MT(6,6)
              REAL(KIND=8), INTENT(OUT) :: ME(6,6)
              REAL(KIND=8), INTENT(OUT) :: MB(6)
            END SUBROUTINE PARSER
          END INTERFACE 
        END MODULE PARSER__genmod
