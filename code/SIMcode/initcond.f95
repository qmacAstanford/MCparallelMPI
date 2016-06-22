!! ---------------------------------------------------------------*
      
!     
!     This subroutine sets the initial condition for a chain within
!     the capsid
!     
!     Andrew Spakowitz
!     Written 4-16-04
!
!     Updated by Quinn in 2016
!
SUBROUTINE initcond(R,U,AB,NT,N,NP,FRMFILE,PARA,LBOX, &
                    setType,rand_stat)

!use mt19937, only : grnd, init_genrand, rnorm, mt, mti
use mersenne_twister
use setPrecision

IMPLICIT NONE

DOUBLE PRECISION PI
PARAMETER (PI=3.141593_dp)

DOUBLE PRECISION R(NT,3)  ! Bead positions
DOUBLE PRECISION U(NT,3)  ! Tangent vectors
INTEGER AB(NT)            ! Chemical identity of beads
INTEGER N,NP,NT           ! Number of beads
DOUBLE PRECISION GAM      ! Equil bead separation
DOUBLE PRECISION LBOX     ! Box edge length
INTEGER I,J,IB            ! Index Holders
LOGICAL FRMFILE           ! Is conformation in file?
INTEGER INPUT             ! Is input file set?
DOUBLE PRECISION RMIN
DOUBLE PRECISION R0(3)
DOUBLE PRECISION PARA(10)
INTEGER setType           ! select what type of configurateion

!     Varibles for type 2

DOUBLE PRECISION Uold(3) ! save previous direction
DOUBLE PRECISION Rold(3) ! save previous position
DOUBLE PRECISION theta   ! random angle
DOUBLE PRECISION z       ! random z position
DOUBLE PRECISION rr      ! random radial position
LOGICAL search           ! for exiting while loop
DOUBLE PRECISION test(3) ! test position for inside confinment
DOUBLE PRECISION Rc      ! radius of confinement
INTEGER ii !for testing

!     Variables in the simulation

DOUBLE PRECISION KAP,EPS  ! Elastic properties
DOUBLE PRECISION XI       ! Drag coefficients

!      Random number generator initiation
type(random_stat) rand_stat
real urand(3)

!     Setup the choice parameters
INPUT=1

if(FRMFILE)then
   OPEN (UNIT = 5, FILE = 'input/r0', STATUS = 'OLD')
   Do I=1,NT
      READ(5,*) R(I,1),R(I,2),R(I,3),AB(I)
   enddo
   CLOSE(5)

   OPEN (UNIT = 5, FILE = 'input/u0', STATUS = 'OLD')
   Do I=1,NT
      READ(5,*) U(I,1),U(I,2),U(I,3)
   enddo 
   CLOSE(5)
   return
endif

   
!     Fix the initial condition
if(setType.eq.1) then
! staight line in y direction with random starting position
    if (INPUT.EQ.0) then
       LBOX=10.
       GAM=1.
    else
       GAM=PARA(4)
       LBOX=PARA(8)
    endif

    IB=1
    DO I=1,NP
       call random_number(urand,rand_stat)
       R0(1)=urand(1)*LBOX
       R0(2)=urand(2)*LBOX
       R0(3)=urand(3)*LBOX
       DO J=1,N
          R(IB,1)=R0(1)
          R(IB,2)=R0(2)+GAM*(J-N/2.0_dp-0.5_dp) ! center on box
          R(IB,3)=R0(3)
          U(IB,1)=0.
          U(IB,2)=1.
          U(IB,3)=0.
          IB=IB+1
       enddo
    enddo 
else if(setType.eq.2) then
    ! travel in radom direction
    ! rerandomize when reaching boundary
    ! slit boundary in z direction            
    
    if (INPUT.EQ.0) then
       LBOX=10.0_dp
       GAM=1.0_dp
    else
       GAM=PARA(4)
       LBOX=PARA(8)
    endif
    
    IB=1
    DO  I=1,NP
        call random_number(urand,rand_stat)
        Rold(1)=urand(1)*LBOX
        Rold(2)=urand(2)*LBOX
        Rold(3)=urand(3)*LBOX
        call random_number(urand,rand_stat)
        theta=urand(1)*2*PI
        z=urand(2)*2-1
        Uold(1)=sqrt(1-z*z)*cos(theta)
        Uold(2)=sqrt(1-z*z)*sin(theta)
        Uold(3)=z
        
        DO J=1,N
           search=.TRUE.
           ii=0
           do while(search)
                ii=ii+1
                if(ii.gt.100) then
                    print*,'stuck in loop'
                    print*,'Rold=',Rold(1),Rold(2),Rold(3)
                    print*,'test=',test(1),test(2),test(3)
                    exit
                endif
                test(1)=Rold(1)+Uold(1)*GAM
                test(2)=Rold(2)+Uold(2)*GAM
                test(3)=Rold(3)+Uold(3)*GAM
                search=.FALSE.
                if(test(3).gt.LBOX)then
                    search=.TRUE.
                endif
                if(test(3).lt.0)then
                    search=.TRUE.
                endif
                if(search) then
                     call random_number(urand,rand_stat)
                     theta=urand(1)*2*PI
                     z=urand(2)*2-1
                     Uold(1)=sqrt(1-z*z)*cos(theta)
                     Uold(2)=sqrt(1-z*z)*sin(theta)
                     Uold(3)=z
                endif
           enddo
           R(IB,1)=test(1)
           R(IB,2)=test(2)
           R(IB,3)=test(3)
           Rold(1)=test(1)
           Rold(2)=test(2)
           Rold(3)=test(3)
           U(IB,1)=Uold(1)
           U(IB,2)=Uold(2)
           U(IB,3)=Uold(3)
           
           IB=IB+1
        enddo
    enddo 
else if(setType.eq.3) then
    ! travel in radom direction
    ! rerandomize when reaching boundary
    ! square boundary             
    
    if (INPUT.EQ.0) then
       LBOX=10.0_dp
       GAM=1.0_dp
    else
       GAM=PARA(4)
       LBOX=PARA(8)
    endif
    
    IB=1
    DO  I=1,NP
       call random_number(urand,rand_stat)
       Rold(1)=urand(1)*LBOX
       Rold(2)=urand(2)*LBOX
       Rold(3)=urand(3)*LBOX
       call random_number(urand,rand_stat)
       theta=urand(1)*2*PI
       z=urand(2)*2-1
       Uold(1)=sqrt(1-z*z)*cos(theta)
       Uold(2)=sqrt(1-z*z)*sin(theta)
       Uold(3)=z
       
       DO J=1,N
          search=.TRUE.
          ii=0
          do while(search)
               ii=ii+1
               if(ii.gt.100) then
                   print*,'stuck in loop'
                   print*,'Rold=',Rold(1),Rold(2),Rold(3)
                   print*,'test=',test(1),test(2),test(3)
                   exit
               endif
               test(1)=Rold(1)+Uold(1)*GAM
               test(2)=Rold(2)+Uold(2)*GAM
               test(3)=Rold(3)+Uold(3)*GAM
               search=.FALSE.
               if(test(1).gt.LBOX)then
                   search=.TRUE.
               endif
               if(test(1).lt.0)then
                   search=.TRUE.
               endif
               if(test(2).gt.LBOX)then
                   search=.TRUE.
               endif
               if(test(2).lt.0)then
                   search=.TRUE.
               endif
               if(test(3).gt.LBOX)then
                   search=.TRUE.
               endif
               if(test(3).lt.0)then
                   search=.TRUE.
               endif
               if(search) then
                    call random_number(urand,rand_stat)
                    theta=urand(1)*2_dp*PI
                    z=urand(2)*2.0_dp-1.0_dp
                    Uold(1)=sqrt(1-z*z)*cos(theta)
                    Uold(2)=sqrt(1-z*z)*sin(theta)
                    Uold(3)=z
               endif
          enddo
          R(IB,1)=test(1)
          R(IB,2)=test(2)
          R(IB,3)=test(3)
          Rold(1)=test(1)
          Rold(2)=test(2)
          Rold(3)=test(3)
          U(IB,1)=Uold(1)
          U(IB,2)=Uold(2)
          U(IB,3)=Uold(3)
          
          IB=IB+1
       enddo 
    enddo
                 
else if(setType.eq.4) then
    ! travel in radom direction
    ! rerandomize when reaching boundary
    ! shpere boundary
    ! radius of LBox/2 centered at LBox/2             
    Rc=LBOX/2.0_dp ! use LBOX as radius
    if (INPUT.EQ.0) then
       LBOX=10.0_dp
       GAM=1.0_dp
    else
       GAM=PARA(4)
       LBOX=PARA(8)
    endif            
    IB=1
    DO  I=1,NP
       call random_number(urand,rand_stat)
       theta=urand(1)*2.0_dp*PI
       z=urand(2)*2.0_dp-1.0_dp
       rr=Rc*urand(3)  ! should have an r**2 from jacobian
       Rold(1)=sqrt(1.0_dp-z*z)*cos(theta)*rr + LBox/2.0_dp
       Rold(2)=sqrt(1.0_dp-z*z)*sin(theta)*rr + LBox/2.0_dp
       Rold(3)=z*rr + LBox/2.0_dp
       call random_number(urand,rand_stat)
       theta=urand(1)*2_dp*PI
       z=urand(2)*2.0_dp-1.0_dp
       Uold(1)=sqrt(1-z*z)*cos(theta)
       Uold(2)=sqrt(1-z*z)*sin(theta)
       Uold(3)=z                  
       DO J=1,N
           search=.TRUE.
           do while(search)
               test(1)=Rold(1)+Uold(1)*GAM
               test(2)=Rold(2)+Uold(2)*GAM
               test(3)=Rold(3)+Uold(3)*GAM
               search=.FALSE.
               if((test(1)-LBox/2)**2+&
                   (test(2)-LBox/2)**2+&
                   (test(3)-LBox/2)**2.gt.Rc**2)then
                   search=.TRUE.
               endif
               if(search) then
                    call random_number(urand,rand_stat)
                    theta=urand(1)*2.0_dp*PI
                    z=urand(2)*2.0_dp-1.0_dp
                    Uold(1)=sqrt(1.0_dp-z*z)*cos(theta)
                    Uold(2)=sqrt(1.0_dp-z*z)*sin(theta)
                    Uold(3)=z
               endif
           enddo
           R(IB,1)=test(1)
           R(IB,2)=test(2)
           R(IB,3)=test(3)
           Rold(1)=test(1)
           Rold(2)=test(2)
           Rold(3)=test(3)
           U(IB,1)=Uold(1)
           U(IB,2)=Uold(2)
           U(IB,3)=Uold(3)
           IB=IB+1
       enddo ! loop to N
    enddo ! loop to np
else if(setType.eq.5) then 
    ! randomly distribute beads in shereical confinement
    do IB=1,NT
        search=.true.
        do while(search)
             call random_number(urand,rand_stat)
             test(1)=urand(1)*LBox
             test(2)=urand(2)*LBox
             test(3)=urand(3)*LBox
             if(((test(1)-LBox/2)**2+ &
                 (test(2)-LBox/2)**2+ &
                 (test(3)-LBox/2)**2).lt.(LBox*LBox*0.25_dp)) then
                 search=.false.
             endif
        enddo
        R(IB,1)=test(1)
        R(IB,2)=test(2)
        R(IB,3)=test(3)
        U(IB,1)=0.00_dp 
        U(IB,2)=0.00_dp
        U(IB,3)=0.00_dp
    enddo
endif

 
RETURN     
END
      
!---------------------------------------------------------------*