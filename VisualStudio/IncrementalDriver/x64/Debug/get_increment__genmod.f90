        !COMPILER-GENERATED INTERFACE MODULE: Thu Jul  2 21:04:07 2026
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE GET_INCREMENT__genmod
          INTERFACE 
            SUBROUTINE GET_INCREMENT(KEYWORDS,TIME,DELTATIME,IFSTRESS,  &
     &NINC,DELTALOADCIRC,PHASE0,DELTALOAD,DTIME,DDSTRESS,DSTRAN,QB33,   &
     &DFGRD0,DFGRD1,DROT)
              CHARACTER(LEN=40) :: KEYWORDS(10)
              REAL(KIND=8), INTENT(IN) :: TIME(2)
              REAL(KIND=8), INTENT(IN) :: DELTATIME
              INTEGER(KIND=4), INTENT(IN) :: IFSTRESS(6)
              INTEGER(KIND=4), INTENT(IN) :: NINC
              REAL(KIND=8), INTENT(IN) :: DELTALOADCIRC(6)
              REAL(KIND=8), INTENT(IN) :: PHASE0(6)
              REAL(KIND=8), INTENT(IN) :: DELTALOAD(9)
              REAL(KIND=8), INTENT(OUT) :: DTIME
              REAL(KIND=8), INTENT(OUT) :: DDSTRESS(6)
              REAL(KIND=8), INTENT(OUT) :: DSTRAN(6)
              REAL(KIND=8), INTENT(OUT) :: QB33(3,3)
              REAL(KIND=8), INTENT(INOUT) :: DFGRD0(3,3)
              REAL(KIND=8), INTENT(INOUT) :: DFGRD1(3,3)
              REAL(KIND=8), INTENT(INOUT) :: DROT(3,3)
            END SUBROUTINE GET_INCREMENT
          END INTERFACE 
        END MODULE GET_INCREMENT__genmod
