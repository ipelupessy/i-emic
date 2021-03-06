!#begindoc

#ifndef WITH_UNION

#define scdematrix  anymatrix
#define scbmmatrix  anymatrix
#define csrdmatrix  anymatrix

#endif

MODULE m_schurcmpl

CONTAINS
 
SUBROUTINE schurcmpl (Nupp, A, SchTol, SC)

USE m_build
USE m_wascde
USE m_wcompr
USE m_dump

INTEGER				, INTENT(IN)            :: Nupp
TYPE (anymatrix)		, POINTER		:: A
DOUBLE PRECISION		, INTENT(IN)         	:: SchTol
TYPE (scdematrix)		, POINTER		:: SC

!     Computes an approximation of the Schur-complement of the submatrix
!     A_11 of the partitioned matrix A into the matrix SC.
!     The matrix SC will have (A%N - Nupp) rows/columns.
!     The new matrix SC will be stored in SCD format.

!     A block LDU factorisation of the partitioned matrix A, with
!             ( A_11 | A_12 )
!         A = (------+------)
!             ( A_21 | A_22 )
!     is given by
!             (        I      | 0 ) ( A_11 | 0 ) ( I  | (1/A_11)*A_12 )
!         A = (---------------+---) (------+---) (----+---------------)
!             ( A_21*(1/A_11) | I ) (   0  | S ) ( 0  |       I       )

!     where  S  is the Schur complement  S = A_22 - A_21*(1/A_11)*A_12
!     and  1/A_11  denotes the inverse of the block diagonal matrix A_11.

!     inv(1/A_11)  is stored in the (upper part of the) block diagonal.
!     The representation of the other blocks A_12,  A_21  and  A_22
!     depends on the storage type of  A.

!     Let  S  be the Schur-complement of A_11 in A, and let  Sd  the
!     block-diagonal part of  S.
!     The approximation  SCo  of  S-Sd  and the approximation
!     SCd  of  Sd  are:
!        SCo := (S-Sd) - R
!        SCd := Sd + D
!     where  R  is the rest matrix and  D  a block diagonal matrix with
!        A(i,j:: ABS(SCo(i,j)) > 0  ==>  ABS(SCo(i,j)) > SchTol) ,
!        A(i,j:: ABS(R(i,j)) <= SchTol) ,
!        A(i  :: SUM(j:: R(i,j)) = SUM(j:: D(i,j)))

!     Arguments:
!     ==========
!     A%N	i   Number of rows/columns in matrix A.
!     Nupp    	i   Numer of rows/columns in left upper block A_11 of A.
!     A      	i   Location of the descriptor of the matrix A.
!                   Each of 'A%N' and 'Nupp' should be an integer
!                   multiple of 'LkSiz'.
!     SchTol   	i   All non-zero off-diagonal elements of the Schur-
!                   complement, S, to be stored into 'SC' should be
!                   greater than 'SchTol'.
!     SC     	o   Location of descriptor for an SCD type
!                   matrix, containing the Schur-complement of
!                   A_11  in  A.
!     ier      	o   Error code:
!                   =  0  No error occurred, the subroutine constructed
!                         the Schur complement as indicated above.
!                   <  0  Some error occurred, an error message has been
!                         written to standard output.

!#enddoc

!     Local Parameters:
!     =================
CHARACTER (LEN=*), PARAMETER :: rounam = 'schurcmpl'

!     Local Variables:
!     ================

INTEGER 					:: ityp, ier
TYPE (scbmmatrix), POINTER			:: Ascbm
INTEGER 					:: Nsc, BlkSz
INTEGER 					:: maxnnz, maxoffnz
INTEGER, ALLOCATABLE, DIMENSION(:)  :: dumsp
TYPE (csrdmatrix), POINTER			:: Acsrd
INTEGER *8 :: MemAl

#ifdef DEBUG
!     TRACE INFORMATION
PRINT '(A, X, A)' , 'Entry:', rounam
#endif


ityp = A%typ

IF (ityp == csrdtp) THEN
  Acsrd => anytocsrd(A)


  Nsc = A%n - Nupp

! This is an estimate of maxnnz by its upperboud, a better and smaller estimate is possible
! maxnnz = Nsc**2
  maxnnz = EstimateFillingCsrd(Nupp,Acsrd)

! Limit the number of off-diagonal nonzeros in Schur-complement matrix  SC:
! maxoffnz = maxnnz - Nsc*Acsrd%dia%BlkSiz
  maxoffnz = maxnnz
  BlkSz=Acsrd%dia%BlkSiz
  ier=1
  DO WHILE (ier /= 0)
    MemAl=50+Nsc*(1+2*BlkSz)+3*maxoffnz
    DO WHILE (MemAl < 0) 
       maxoffnz=maxoffnz/2
       MemAl=50+Nsc*(1+2*BlkSz)+3*maxoffnz
    ENDDO

    ALLOCATE( dumsp(1:MemAl), STAT=ier )
    IF (ier /= 0) maxoffnz=maxoffnz/3
    IF (ier == 0) THEN
       DEALLOCATE( dumsp, STAT=ier )
       IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Deallocation error')
    ENDIF
  ENDDO
!     Request workspace for the SCD matrix  SC:
  CALL wascde (Nsc, Acsrd%dia%BlkSiz, maxoffnz, SC)
  
! Compute the Schur-complement in SC:
  CALL cmpsccsrd (Nupp, maxoffnz, Acsrd, SchTol, SC)
    
ELSE IF (ityp == scbmtp) THEN
  Ascbm => anytoscbm(A)

! This is an estimate of maxnnz by its upperboud, a better and smaller estimate is possible
! maxnnz = Ascbm%Nschur**2
  maxnnz=EstimateFillingScbm(Ascbm)

! Limit the number of off-diagonal nonzeros in Schur-complement matrix  SC:
  maxoffnz = maxnnz ! - Ascbm%Nschur*Ascbm%a11d%BlkSiz
  Nsc=Ascbm%Nschur
  BlkSz=Ascbm%a11d%BlkSiz
  ier=1
  DO WHILE (ier /= 0)
    ALLOCATE( dumsp(1:50+Nsc*(1+2*BlkSz)+3*maxoffnz), STAT=ier )
    IF (ier /= 0) maxoffnz=maxoffnz/3
    IF (ier == 0) THEN
       DEALLOCATE( dumsp, STAT=ier )
       IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Deallocation error')
    ENDIF
  ENDDO
! Request workspace for the SCD matrix  SC:
  CALL wascde (Ascbm%Nschur,Ascbm%a11d%BlkSiz, maxoffnz, SC)
  
! Compute the Schur-complement in SC:
  CALL cmpscscbm (maxoffnz, Ascbm, SchTol, SC)
     
ELSE
  PRINT '(/, A, 2X, A, A, /, 3X, A, I11, 3X, A)' ,  &
        'Internal error in', rounam, '!', 'Storage type', ityp, 'not implemented!'
  CALL dump(__FILE__,__LINE__, 'Storage type not implemented!')
END IF
  
! Compress the  storage of 'SC' and adjust the required size:
  CALL wcompr (scdetoany(SC))
  
END SUBROUTINE schurcmpl


!=======================================================================


SUBROUTINE cmpsccsrd (Nupp, maxoffnz, a, SchTol, SC)

USE m_dump
USE m_build

INTEGER							, INTENT(IN)  	:: Nupp
INTEGER							, INTENT(IN)  	:: maxoffnz
TYPE (csrdmatrix) 					, POINTER	:: a
DOUBLE PRECISION					, INTENT(IN)  	:: SchTol
TYPE (scdematrix) 					, POINTER	:: SC

!     Compute Schur-complement from CSRD-type matrix.
!     Only called from the subroutine  schurcmpl!

!     Arguments:
!     ==========
!     A%N       	i   Number of rows/columns in matrix A.
!     Nupp    		i   Size of the upper partition.
!     A%dia%BlkSiz   	i   Number of rows/columns in a diagonal block.
!                  	    Each of 'A%N' and 'Nupp' should be an integer
!                  	    multiple of 'A%dia%BlkSiz'.
!     MaxOffNz 		i   Maximum number of off-diagonal non-zeros that can
!                  	    be stored in new Schur-complement 'SC'.
!     A%Lotr   		i   A%Lotr(i), Nupp+1 <= i <= A%N, index in 'A%offd%jco' and
!                  	   'A%offd%co' of last nonzero in 'i'-th row of A_21.
!     A%offd%beg     	i   A%offd%beg(i): index in 'A%offd%jco' and 'A%offd%co' of the first
!                  	    off-diagonal element in row i of matrix A.
!     A%offd%jco     	i   A%offd%jco(nz): column number of off-diagonal element A%offd%co(nz).
!     A%offd%co      	i   A%offd%co(nz): value of off-diagonal element.
!     A%dia%com     	i   Contains the elements of the diagonal blocks:
!                  	    A%dia%com(1:Nupp*A%dia%BlkSiz): contains the inverse of the
!                     	    block-diagonal of A_11,  inv(A_11).
!                  	    A%dia%com(Nupp*A%dia%BlkSiz+1:A%N*A%dia%BlkSiz): contains the block-diagonal of A_22.
!                  	    Each diagonal block is stored in column major order.
!     SchTol   		i   All non-zero off-diagonal elements of the Schur-
!                  	    complement, S, to be stored into 'SC' should be greater than 'SchTol'.
!     sc%offd%beg    	o   sc%offd%beg(i): index in 'sc%offd%jco' and 'sc%offd%co' of the first
!                  	    off-diagonal element in row i of matrix SC.
!     sc%offd%jco    	o   sc%offd%jco(nz): column number of off-diagonal element sc%offd%co(nz).
!     sc%offd%co     	o   sc%offd%co(nz): value of off-diagonal element of SC.
!     sc%dia%com    	o   The values of the elements in the diagonal blocks of
!                  	    matrix SC, stored in column major order.

!     Array arguments used as local variables:
!     ========================================
!     ColNr    ColNr(i), 1 <= i <= NnzRow <= A%N-Nupp, column number
!              of i-th element that should be stored in the new
!              Schur-complement.
!     StorCol  StorCol(i), Nupp+1 <= i <= A%N,
!              = .TRUE.  Element in column 'i' of actual row should be
!                     stored in new Schur-complement.
!              = .FALSE.   Element in column 'i' of actual row should not be
!                     stored in new Schur-complement.
!     ValCol   ValCol(i), Nupp+1 <= i <= A%N, value to be stored in
!              column 'i' of actual row of the new Schur-complement.

!     Local Parameters:
!     =================
CHARACTER (LEN=*), PARAMETER :: rounam = 'cmpsccsrd'

!     Local Variables:
!     ================
!     Row   Nupp+1 <= Row <= A%N, the number of the actual row.
!     NnzRow   Number of nonzeros in actual row 'Row'.

INTEGER 					:: basecol, BaseRow, col, scnnz, BlkSiz, i, ier
INTEGER 					:: Row, nnzrow
INTEGER 					:: nza12, nza21, nza22, nz
INTEGER 					:: cola21, rowa12
DOUBLE PRECISION 				:: fact
LOGICAL, ALLOCATABLE, DIMENSION(:)              :: StorCol
INTEGER, ALLOCATABLE, DIMENSION(:)              :: ColNr
DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:)     :: ValCol

#ifdef DEBUG

!     TRACE INFORMATION
PRINT '(A, X, A)' , 'Entry:', rounam
#endif

ALLOCATE( StorCol(Nupp+1:A%n), STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Allocation error')
ALLOCATE( ColNr(1:A%n-Nupp), STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Allocation error')
ALLOCATE( ValCol(Nupp+1:A%n), STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Allocation error')

!     Clear column search pointer:

StorCol = .false.

!     Initialise number of nonzeros and pointer to first non-zero in
!     'SC':
scnnz          = 0
SC%offd%beg(1) = 1

!     Construct Schur-Complement, of size (A%N-Nupp), in
!     'SC' and 'SCd':

BlkSiz = A%dia%BlkSiz

IF (BlkSiz > 1) THEN
  DO Row = Nupp+1, A%n
    BaseRow = ((Row - 1) / BlkSiz) * BlkSiz
    
!        Copy row 'Row - BaseRow' of actual block in A22d into new row:
    
    FORALL (i = 1:BlkSiz) ColNr(i) = BaseRow+i
    StorCol(BaseRow+1:BaseRow+BlkSiz) = .true.
    ValCol(BaseRow+1:BaseRow+BlkSiz)  = A%dia%com(Row - BaseRow,BaseRow+1:BaseRow+BlkSiz)
    nnzrow = BlkSiz

    
!   {  NnzRow = BlkSiz  }
    
!   Copy non-zero off-diagonal elements in row 'Row' of A_22 into new row:
    
    DO nza22 = A%lotr(Row)+1, A%offd%beg(Row+1)-1
      nnzrow = nnzrow + 1
      
      col          = A%offd%jco(nza22)
      ColNr(nnzrow) = col
      StorCol(col) = .true.
      ValCol(col)  = A%offd%co(nza22)
    END DO
    
!   Subtract product  A_21*(1/D)*A_12  from  A_22
    
!   For each non-zero in row of A_21:

    DO nza21 = A%offd%beg(Row), A%lotr(Row)
      cola21 = A%offd%jco(nza21)
      
      basecol = ((cola21 - 1) / BlkSiz) * BlkSiz
      DO rowa12 = basecol+1, basecol+BlkSiz
        
!       Common factor for all non-zeros in row of A_12
        fact = A%offd%co(nza21)*A%dia%com(cola21-basecol,rowa12)
        
!              For each non-zero in row of A_12:
        DO nza12 = A%offd%beg(rowa12), A%offd%beg(rowa12+1)-1
          
          col = A%offd%jco(nza12)
          
          IF (StorCol(col)) THEN
!           An existing element:
            
            ValCol(col) = ValCol(col) - fact*A%offd%co(nza12)
          ELSE
!           A new element, insert into new row:
            
            nnzrow        = nnzrow + 1
            ColNr(nnzrow) = col
            StorCol(col) = .true.
            ValCol(col)  = - fact * A%offd%co(nza12)
          END IF
        END DO
      END DO
    END DO
    
    
    IF (scnnz + (nnzrow - BlkSiz) > maxoffnz) THEN
!           Not enough space left to store off-diagonals of 'Row'.
      PRINT '(A, 2X, A, A, /, 3X, A, I8, /, 3X, A, I8)' ,  &
          'Error in', rounam, '.  Not enough space to store Schur-complement!',  &
          'Detected when storing row:         ', Row-Nupp,  &
          'Number of rows in Schur-complement:', A%n-Nupp
      CALL dump(__FILE__,__LINE__, 'Not enough space left to store off-diagonals!')
    END IF
    
!   Off-diagonal elements:
    
!   Store off-diagonal elements, with absolute value > 'SchTol', into
!   the approximate Schur-complement 'SC'.  Off-diagonal elements
!   with absolute value <= SchTol in row 'Row' are lumped onto the
!   diagonal element in this row.
    
!   For each off-diagonal non-zero in new row:
    DO nz = BlkSiz+1, nnzrow
      col          = ColNr(nz)
      StorCol(col) = .false.
      
      IF (ABS(ValCol(col)) > SchTol) THEN
!              Element cannot be lumped, store off-diagonal:
        
        scnnz              = scnnz + 1
        SC%offd%co(SCnnz)  = ValCol(col)
        SC%offd%jco(SCnnz) = col - Nupp
      ELSE
!              Lump off-diagonal onto main diagonal:
         ValCol(Row) = ValCol(Row) + ValCol(col)
      END IF
    END DO
    
!   Pointer to first non-zero Off-diagonal in next row:

    SC%offd%beg(Row-Nupp+1) = SCnnz + 1
    
    
!   Block Diagonal elements:
    
!   Store the block part of the actual row into block diagonal part
!   of Schur complement 'SCd':
    
    DO nz = BaseRow+1, BaseRow+BlkSiz
      col          = ColNr(nz-BaseRow)
      StorCol(col) = .false.
      SC%dia%com(Row - BaseRow,nz-Nupp) = ValCol(col)
    END DO
  END DO
ELSE
!     {  BlkSiz = 1  }
  DO Row = Nupp+1, A%n
    
!        Add Block diagonal element of A_22 to the temporary store:
    
    nnzrow = 1
    
    ColNr(nnzrow)   = Row
    StorCol(Row) = .true.
    ValCol(Row)  = A%dia%com(1,Row)
    
!        {  NnzRow = BlkSiz = 1  }
    
!        Copy non-zero off-diagonal elements in row 'Row' of A_22 into
!        new row:
    
    DO nza22 = A%lotr(Row)+1, A%offd%beg(Row+1)-1
      nnzrow = nnzrow + 1
      
      col          = A%offd%jco(nza22)
      ColNr(nnzrow) = col
      StorCol(col) = .true.
      ValCol(col)  = A%offd%co(nza22)
    END DO
    
!        Subtract product  A_21*(1/D)*A_12  from  A_22
    
!        For each non-zero in row of A_21:
    DO nza21 = A%offd%beg(Row), A%lotr(Row)
      cola21 = A%offd%jco(nza21)
      
!           Common factor for all non-zeros in row of A_12
      fact = A%offd%co(nza21)*A%dia%com(1,cola21)
!            IF (fact .NE. 0.0D0) THEN
      
!           For each non-zero in row of A_12:
      DO nza12 = A%offd%beg(cola21), A%offd%beg(cola21+1)-1
        
        col = A%offd%jco(nza12)
        
        IF (StorCol(col)) THEN
!                 An existing element:
          
          ValCol(col) = ValCol(col) - fact*A%offd%co(nza12)
        ELSE
!                 A new element, insert into new row:
          
          nnzrow        = nnzrow + 1
          ColNr(nnzrow) = col
          StorCol(col) = .true.
          ValCol(col)  = - (fact * A%offd%co(nza12))
        END IF
      END DO
!            ENDIF
    END DO
    
    
    IF (SCnnz + (nnzrow - BlkSiz) > maxoffnz) THEN
!           Not enough space left to store off-diagonals of 'Row'.
      PRINT '(A, 2X, A, A, /, 3X, A, I8, /, 3X, A, I8)' ,  &
          'Error in', rounam, '.  Not enough space to store Schur-complement!',  &
          'Detected when storing row:         ', Row-Nupp,  &
          'Number of rows in Schur-complement:', A%n-Nupp
      CALL dump(__FILE__,__LINE__, 'Not enough space left to store off-diagonals!')
    END IF
    
!        Off-diagonal elements:
    
!        Store off-diagonal elements, with absolute value > 'SchTol', into
!        the approximate Schur-complement 'SC'.  Off-diagonal elements
!        with absolute value <= SchTol in row 'Row' are lumped onto the
!        diagonal element in this row.
    
!        For each off-diagonal non-zero in new row:
    DO nz = BlkSiz+1, nnzrow
      col          = ColNr(nz)
      StorCol(col) = .false.
      
      IF (ABS(ValCol(col)) > SchTol) THEN
!              Element cannot be lumped, store off-diagonal:
        
        SCnnz        = SCnnz + 1
        SC%offd%co(SCnnz)  = ValCol(col)
        SC%offd%jco(SCnnz) = col - Nupp
      ELSE
!              Lump off-diagonal onto main diagonal:
         ValCol(Row) = ValCol(Row) + ValCol(col)
       END IF
    END DO
    
!        Pointer to first non-zero Off-diagonal in next row:
    SC%offd%beg(Row-Nupp+1) = SCnnz + 1
    
    
!        Diagonal elements:
    
!        Store the Diagonal element of the actual row into the diagonal
!        part of the Schur complement 'SC%dia':
    
    StorCol(Row)      = .false.
    SC%dia%com(1,Row - Nupp) = ValCol(Row)
  END DO
END IF

DEALLOCATE( StorCol, STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Deallocation error')
DEALLOCATE( ColNr, STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Deallocation error')
DEALLOCATE( ValCol, STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Deallocation error')

END SUBROUTINE cmpsccsrd


!=======================================================================


SUBROUTINE cmpscscbm (maxoffnz, a, SchTol, SC)

USE m_dump
USE m_build

INTEGER							, INTENT(IN)    :: maxoffnz
DOUBLE PRECISION					, INTENT(IN)    :: SchTol
TYPE (scdematrix)					, POINTER       :: sc
TYPE (scbmmatrix)					, POINTER       :: a

!     Compute Schur-complement from SCBM-type matrix.
!     Only called from the subroutine  schurcmpl!

!     Arguments:
!     ==========
!     A%n    	i   Number of rows/columns in matrix A.
!     A%g     	i   Size of the upper partition.
!     MaxOffNz 	i   Maximum number of off-diagonal non-zeros that can
!                   be stored in new Schur-complement 'SC'.
!     A%a11d    i   The block-diagonal submatrix  inv(A_11).C
!     A%a12%beg i   A%a12%beg(i): index in 'A%a12%jco' and 'A%a12%co' of the first
!                   element in row i of submatrix A_12 of A.
!     A%a12%jco i   A%a12%jco(nz): column number of element A%a12%co(nz).
!     A%a12%co  i   A%a12%co(nz): value of nonzero element of A_12.
!     A%a21%beg i   A%a21%beg(i): index in 'A%a21%jco' and 'A%a21%co' of the first
!                   element in row i of submatrix A_21 of A.
!     A%a21%jco i   A%a21%jco(nz): column number of element A%a21%co(nz).
!     A%a21%co  i   A%a21%co(nz): value of nonzero element of A_21.
!     A%a22%beg i   A%a22%beg(i): index in 'A%a22%jco' and 'A%a22%co' of the first
!                   element in row i of submatrix A_22 of A.
!     A%a22%jco i   A%a22%jco(nz): column number of element A%a22%co(nz).
!     A%a22%co  i   A%a22%co(nz): value of nonzero element of A_22.
!     SchTol   	i   All non-zero off-diagonal elements of the Schur-
!                   complement, S, to be stored into 'SC' should be
!                   greater than 'SchTol'.
!     sc%offd%beg    o   sc%offd%beg(i): index in 'sc%offd%jco' and 'sc%offd%co' of the first
!                  off-diagonal element in row i of matrix SC.
!     sc%offd%jco    o   sc%offd%jco(nz): column number of off-diagonal element
!                  sc%offd%co(nz).
!     sc%offd%co     o   sc%offd%co(nz): value of nonzero off-diagonal element of SC.
!     sc%dia%com    o   The values of the elements in the diagonal blocks of
!                  matrix SC, stored in column major order.

!     Array arguments used as local variables:
!     ========================================
!     ColNr    ColNr(i), 1 <= i <= NnzRow <= A%Nschur, column number
!              of i-th element that should be stored in the new
!              Schur-complement.
!     StorCol  StorCol(i), 1 <= i <= A%Nschur,
!              = .TRUE.  Element in column 'i' of actual row should be
!                     stored in new Schur-complement.
!              = .FALSE.   Element in column 'i' of actual row should not be
!                     stored in new Schur-complement.
!     ValCol   ValCol(i), 1 <= i <= A%Nschur, value to be stored in
!              column 'i' of actual row of the new Schur-complement.

!     Local Parameters:
!     =================
CHARACTER (LEN=*), PARAMETER :: rounam = 'cmpscscbm'

!     Local Variables:
!     ================
!     Row   1 <= Row <= A%n-A%g, the number of the actual row.
!     NnzRow   Number of nonzeros in actual row 'Row'.

INTEGER 					:: scnnz, ier
INTEGER 					:: basecol, BaseRow, col
INTEGER 					:: Row, nnzrow
INTEGER 					:: nza12, nza21, nza22, nz
INTEGER 					:: cola21, rowa12
DOUBLE PRECISION 				:: fact
LOGICAL, ALLOCATABLE, DIMENSION(:)        	:: StorCol
INTEGER, ALLOCATABLE, DIMENSION(:)             	:: ColNr
DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:)    	:: ValCol

#ifdef DEBUG

!     TRACE INFORMATION
PRINT '(A, X, A)' , 'Entry:', rounam
#endif

ALLOCATE( StorCol(1:A%Nschur), STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Allocation error')
ALLOCATE( ColNr(1:A%Nschur), STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Allocation error')
ALLOCATE( ValCol(1:A%Nschur), STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Allocation error')

!     Clear column search pointer:
StorCol = .false.

!     Initialise number of nonzeros and pointer to first non-zero in
!     'SC':
scnnz    = 0
sc%offd%beg(1) = scnnz + 1

!     Construct Schur-Complement, of size A%NSCHUR, in  'SC' and 'Sc%dia':

IF (sc%dia%BlkSiz > 1) THEN
  DO Row = 1, A%Nschur
    BaseRow = ((Row - 1) / sc%dia%BlkSiz) * sc%dia%BlkSiz
    
    nnzrow = 0
    
!        Copy elements in row 'Row' of A_22 into new row of SC:
    
    DO nza22 = a%a22%beg(Row), a%a22%beg(Row+1)-1
      nnzrow        = nnzrow + 1
      col          = a%a22%jco(nza22)
      ColNr(nnzrow) = col
      StorCol(col) = .true.
      ValCol(col)  = a%a22%co(nza22)
    END DO
    
!        Add zero block-diagonal elements of A_22 if necessary:
    DO col = BaseRow+1, BaseRow+sc%dia%BlkSiz
      IF (.not. StorCol(col)) THEN
        nnzrow        = nnzrow + 1
        ColNr(nnzrow) = col
        StorCol(col) = .true.
        ValCol(col)  = 0.0D0
      END IF
    END DO
    
    
!        Subtract product  A_21*(1/A_11)*A_12  from  A_22
    
!        For each non-zero in row of A_21:
    DO nza21 = a%a21%beg(Row), a%a21%beg(Row+1)-1
      cola21 = a%a21%jco(nza21)
      
      basecol = ((cola21 - 1) / sc%dia%BlkSiz) * sc%dia%BlkSiz
      DO rowa12 = basecol+1, basecol+sc%dia%BlkSiz
        
!              Common factor for all non-zeros in row of A_12
        fact = a%a21%co(nza21)*a%a11d%com(cola21 - basecol,rowa12)
        
!              For each non-zero in row of A_12:
        DO nza12 = a%a12%beg(rowa12), a%a12%beg(rowa12+1)-1
          
          col = a%a12%jco(nza12)
          
          IF (StorCol(col)) THEN
!                    An existing element:
            
            ValCol(col) = ValCol(col) - fact*a%a12%co(nza12)
          ELSE
!                    A new element, insert into new row:
            
            nnzrow        = nnzrow + 1
            ColNr(nnzrow) = col
            StorCol(col) = .true.
            ValCol(col)  = - (fact * a%a12%co(nza12))
          END IF
        END DO
      END DO
    END DO
    
    
    IF (scnnz + (nnzrow - sc%dia%BlkSiz) > maxoffnz) THEN
!           Not enough space left to store off-diagonals of 'Row'.
      PRINT '(A, 2X, A, A, /, 3X, A, I8, /, 3X, A, I8)' ,  &
          'Error in', rounam, '.  Not enough space to store Schur-complement!',  &
          'Detected when storing row:         ', Row,  &
          'Number of rows in Schur-complement:', a%Nschur
      CALL dump(__FILE__,__LINE__, 'Not enough space left to store off-diagonals!')
    END IF
    
!        Store elements:
    
    
!        Off-diagonal elements:
    
!        Store off-diagonal elements, with absolute value > 'SchTol', into
!        the approximate Schur-complement 'SC'.  Off-diagonal elements
!        with absolute value <= SchTol in row 'Row' are lumped onto the
!        diagonal element in this row.
    
!        For each non-zero in new row:
    DO nz = 1, nnzrow
      col = ColNr(nz)
      IF (col <= BaseRow  .Or. col > BaseRow+sc%dia%BlkSiz) THEN
        StorCol(col) = .false.
        
        IF (ABS(ValCol(col)) > SchTol) THEN
!                 Off-diagonal element cannot be lumped, store:
          scnnz        = scnnz + 1
          sc%offd%co(scnnz)  = ValCol(col)
          sc%offd%jco(scnnz) = col
        ELSE
!                 Lump off-diagonal onto main diagonal:
           ValCol(Row) = ValCol(Row) + ValCol(col)
        END IF
      END IF
    END DO
    
!        Pointer to first non-zero Off-diagonal in next row:
    sc%offd%beg(Row+1) = scnnz + 1
    
    
!        Block-diagonal elements:
    
!        Store the block part of the actual row into block diagonal part
!        of Schur complement 'Sc%dia':
    
    StorCol(BaseRow+1:BaseRow+sc%dia%BlkSiz) = .false.
    sc%dia%com(Row - BaseRow,BaseRow+1:BaseRow+sc%dia%BlkSiz) = ValCol(BaseRow+1:BaseRow+sc%dia%BlkSiz)
    
  END DO
ELSE
!     {  Sc%dia%BlkSiz = 1  }
  DO Row = 1, a%Nschur
    
    nnzrow = 0
    
!        Copy elements in row 'Row' of A_22 into new row SC:
    
    DO nza22 = a%a22%beg(Row), a%a22%beg(Row+1)-1
      nnzrow        = nnzrow + 1
      col          = a%a22%jco(nza22)
      ColNr(nnzrow) = col
      StorCol(col) = .true.
      ValCol(col)  = a%a22%co(nza22)
    END DO
    
!        Add zero block-diagonal element of A_22 if necessary:
    IF (.not. StorCol(Row)) THEN
      nnzrow          = nnzrow + 1
      ColNr(nnzrow)   = Row
      StorCol(Row) = .true.
      ValCol(Row)  = 0.0D0
    END IF
    
!        Subtract product  A_21*(1/A_11)*A_12  from  A_22
    
!        For each non-zero in row of A_21:
    DO nza21 = a%a21%beg(Row), a%a21%beg(Row+1)-1
      cola21 = a%a21%jco(nza21)
      
!           Common factor for all non-zeros in row of A_12
      fact = a%a21%co(nza21)*a%a11d%com(1,cola21)
      
!           For each non-zero in row of A_12:
      DO nza12 = a%a12%beg(cola21), a%a12%beg(cola21+1)-1
        
        col = a%a12%jco(nza12)
        
        IF (StorCol(col)) THEN
!                 An existing element:
          
          ValCol(col) = ValCol(col) - fact*a%a12%co(nza12)
        ELSE
!                 A new element, insert into new row:
          
          nnzrow        = nnzrow + 1
          ColNr(nnzrow) = col
          StorCol(col) = .true.
          ValCol(col)  = - (fact * a%a12%co(nza12))
        END IF
      END DO
    END DO
    
    IF (scnnz + (nnzrow - sc%dia%BlkSiz) > maxoffnz) THEN
!           Not enough space left to store off-diagonals of 'Row'.
      PRINT '(A, 2X, A, A, /, 3X, A, I8, /, 3X, A, I8)' ,  &
          'Error in', rounam, '.  Not enough space to store Schur-complement!',  &
          'Detected when storing row:         ', Row, 'Number of rows in Schur-complement:', a%Nschur
      CALL dump(__FILE__,__LINE__, 'Not enough space left to store off-diagonals!')
    END IF
    
    
!        Off-diagonal elements:
    
!        Store off-diagonal elements, with absolute value > 'SchTol', into
!        the approximate Schur-complement 'SC'.  Off-diagonal elements
!        with absolute value <= SchTol in row 'Row' are lumped onto the
!        diagonal element in this row.
    
!        For each off-diagonal non-zero in new row:
    DO nz = 1, nnzrow
      col = ColNr(nz)
      IF (col /= Row) THEN
        StorCol(col) = .false.
        
        IF (ABS(ValCol(col)) > SchTol) THEN

!         Element cannot be lumped, store off-diagonal:
          
          scnnz        = scnnz + 1
          sc%offd%co(scnnz)  = ValCol(col)
          sc%offd%jco(scnnz) = col

        ELSE

!         Lump off-diagonal onto main diagonal:

          ValCol(Row) = ValCol(Row) + ValCol(col)

        END IF
      END IF
    END DO
    
!   Pointer to first non-zero Off-diagonal in next row:

    sc%offd%beg(Row+1) = scnnz + 1
    
    
!   Diagonal element:
    
!   Store the Diagonal element of the actual row into the diagonal
!   part of the Schur complement 'Sc%dia':
    
    StorCol(Row) = .false.
    sc%dia%com(1,Row)   = ValCol(Row)

  END DO
END IF

DEALLOCATE( StorCol, STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Deallocation error')
DEALLOCATE( ColNr, STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Deallocation error')
DEALLOCATE( ValCol, STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Deallocation error')

END SUBROUTINE cmpscscbm



INTEGER FUNCTION EstimateFillingCsrd(Nupp,a)

USE m_dump
USE m_build

INTEGER				,INTENT(IN)	::Nupp	
TYPE (csrdmatrix)		,POINTER	::a	


INTEGER, ALLOCATABLE, DIMENSION(:)	::fillTemp
INTEGER		      			::Estimate
INTEGER					::ier, i, nza21, BlkSiz

ALLOCATE( fillTemp(1:max(a%n-Nupp,Nupp)), STAT=ier)
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Allocation error')

! compute fill of A22

fillTemp(1:a%n-Nupp)=  a%offd%beg(Nupp+2:a%n+1)- a%lotr(Nupp+1:a%n)
Estimate=SUM(fillTemp(1:a%n-Nupp)) 

! Estimate fill of correction

fillTemp(1:Nupp)= (a%offd%beg(2:Nupp +1)- a%offd%beg(1:Nupp ))

BlkSiz=a%dia%BlkSiz

FORALL (i=1:Nupp:BlkSiz) fillTemp(i:i+BlkSiz-1) = SUM( fillTemp(i:i+BlkSiz-1))

DO i = Nupp+1, a%n
  Estimate=Estimate+SUM( fillTemp(a%offd%jco(a%offd%beg(i):a%lotr(i)) ))
END DO

DEALLOCATE( fillTemp, STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Deallocation error')
EstimateFillingCsrd=Estimate  

RETURN

END FUNCTION EstimateFillingCsrd





INTEGER FUNCTION EstimateFillingScbm(a)

USE m_dump
USE m_build

TYPE (scbmmatrix)		,POINTER	::a	


INTEGER, ALLOCATABLE		,DIMENSION(:)	::fillTemp
INTEGER		      				::Estimate
INTEGER						::ier, Nupp, BlkSiz, i

Nupp  =a%a12%n
BlkSiz=a%a11d%BlkSiz

ALLOCATE( fillTemp(1:max(a%n-Nupp,Nupp)), STAT=ier)
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Allocation error')

! compute fill of A22

Estimate=a%a22%beg(a%nschur+1)-1 

! Estimate fill of correction

fillTemp(1:Nupp)= (a%a12%beg(2:Nupp +1)- a%a12%beg(1:Nupp ))

DO i=1, Nupp ,BlkSiz
 fillTemp(i:i+BlkSiz-1) = SUM( fillTemp(i:i+BlkSiz-1))
ENDDO

DO i = 1, a%a21%beg(a%nschur+1)-1
   Estimate=Estimate+fillTemp(a%a21%jco(i))
ENDDO

DEALLOCATE( fillTemp, STAT=ier )
IF (ier /= 0) CALL dump(__FILE__,__LINE__,'Deallocation error')
EstimateFillingScbm=Estimate  

RETURN

END FUNCTION EstimateFillingScbm


END MODULE
