!---------------------------------------------------------------*
!
!
!      
!     This subroutine performs a Monte Carlo simulation on the 
!     polymer chain.
!
!    Quinn Made Changes to this file starting on 12/15/15    
!
      
SUBROUTINE MCsim(mc,md,NSTEP,INTON,rand_stat)

    !use mt19937, only : grnd, sgrnd, rnorm, mt, mti
    use mersenne_twister
    use simMod

    IMPLICIT NONE 

    INTEGER, intent(in) :: NSTEP             ! Number of MC steps
    INTEGER, intent(in) :: INTON             ! Include polymer interactions
    
!   Variables for the simulation
    
    INTEGER ISTEP             ! Current MC step index
    DOUBLE PRECISION PROB     ! Calculated test prob
    DOUBLE PRECISION TEST     ! Random test variable
    INTEGER IP                ! Test polymer 
    INTEGER IB1               ! Test bead position 1
    INTEGER IT1               ! Index of test bead 1
    INTEGER IB2               ! Test bead position 2
    INTEGER IT2               ! Index of test bead 2
    INTEGER IT3, IT4          ! second polymer for polymer swap
    INTEGER IT1plusNT, IT2plusNT
    logical forward           ! direction of reptation move

    INTEGER I,J
    
    INTEGER MCTYPE                    ! Type of MC move
    
    DOUBLE PRECISION EB_P2,EPAR_P2,EPERP_P2
    DOUBLE PRECISION GAM_P2,ETA_P2
    DOUBLE PRECISION EB,EPAR,EPERP
    DOUBLE PRECISION GAM,ETA
    DOUBLE PRECISION XIR,XIU
    DOUBLE PRECISION LHC      ! Length of HC int
    DOUBLE PRECISION VHC      ! HC strength
    DOUBLE PRECISION phiTot  ! for testing

    DOUBLE PRECISION ENERGY
    logical isfile
! Things for random number generator
    real urnd(1) ! single random number
    type(random_stat), intent(inout) :: rand_stat
!   Load the input parameters
    Type(MCvar), intent(inout) :: mc      ! system varibles 
    Type(MCData), intent(inout) :: md     ! system allocated data



    EB=   mc%PARA(1)
    EPAR= mc%PARA(2)
    EPERP=mc%PARA(3)
    GAM=  mc%PARA(4)
    ETA=  mc%PARA(5)
    XIR=  mc%PARA(6)
    XIU=  mc%PARA(7)
    LHC=  mc%PARA(9)
    VHC=  mc%PARA(10)
    EB_P2=   mc%PARAP2(1)
    EPAR_P2= mc%PARAP2(2)
    EPERP_P2=mc%PARAP2(3)
    GAM_P2=  mc%PARAP2(4)
    ETA_P2=  mc%PARAP2(5)
! -------------------------------------
! -------------------------------------
!
!   initialize densities and energies 
!
! -------------------------------------
    ! --- Binding Energy ---
    md%ABP=0 ! set entire array to zero
    !  Notide that ABP and AB are intensionally swapped below
    IT1=1; IT2=mc%NT
    if (mc%simtype.eq.1) then
        call MC_bind(mc%NT,mc%G,IT1,IT2,md%ABP,md%AB,md%METH, &
                     mc%EU,mc%EM,mc%DEBind,mc%mu,mc%dx_mu,mc%nBeadsP2)

        inquire(file = "data/error", exist=isfile)
        if (isfile) then
            OPEN (UNIT = 3, FILE = "data/error", STATUS ='OLD', POSITION="append")
        else 
            OPEN (UNIT = 3, FILE = "data/error", STATUS = 'new')
        endif

        if(abs(mc%EBind-mc%DEBind).gt.0.00001) then
            print*, "Warning. Integrated binding enrgy:", &
                    mc%EBind," while absolute binding energy:", &
                    mc%DEBind
            write(3,*), "Warning. Integrated binding enrgy:", &
                    mc%EBind," while absolute binding energy:", &
                    mc%DEBind
        endif
        mc%EBind=mc%DEBind
        mc%x_mu=mc%dx_mu
    else
        mc%EBind=0.0
        mc%DEBind=0.0
        mc%x_mu=0.0
    endif

    ! --- Elastic Energy ---
    call energy_elas(mc%DEELAS,md%R,md%U,mc%NT,mc%NB,mc%NP,mc%Para,mc%nBeadsP2)
    if(abs((mc%EElas(1)+  mc%EElas(2)+ mc%EElas(3))-& 
           (mc%DEElas(1)+mc%DEElas(2)+mc%DEElas(3))).gt.0.0001) then
        print*, "Warning. Integrated elastic enrgy:", &
                (mc%EElas(1)+mc%EElas(2)+mc%EElas(3)),&
                " while absolute elastic energy:", &
                (mc%DEElas(1)+mc%DEElas(2)+mc%DEElas(3))
        write(3,*), "Warning. Integrated elastic enrgy:", &
                (mc%EElas(1)+mc%EElas(2)+mc%EElas(3)),&
                " while absolute elastic energy:", &
                (mc%DEElas(1)+mc%DEElas(2)+mc%DEElas(3))
    endif
    mc%EElas=mc%DEElas ! copy array

    ! --- Elastic Energy of Extra Polymer---
    call energy_elas(mc%DEELAS_P2,md%R_P2,md%U_P2,mc%nBeadsP2,mc%nBeadsP2,1,mc%paraP2,0)
    if(abs((mc%EElas_P2(1)+  mc%EElas_P2(2)+ mc%EElas_P2(3))-& 
           (mc%DEElas_P2(1)+mc%DEElas_P2(2)+mc%DEElas_P2(3))).gt.0.0001) then
        print*, "Warning. Integrated elastic enrgy of extra polymer:", &
                (mc%EElas_P2(1)+mc%EElas_P2(2)+mc%EElas_P2(3)),&
                " while absolute elastic energy enrgy of extra polymer:", &
                (mc%DEElas_P2(1)+mc%DEElas_P2(2)+mc%DEElas_P2(3))
        write(3,*), "Warning. Integrated elastic enrgy of extra polymer:", &
                (mc%EElas_P2(1)+mc%EElas_P2(2)+mc%EElas_P2(3)),&
                " while absolute elastic energy of extra polymer:", &
                (mc%DEElas_P2(1)+mc%DEElas_P2(2)+mc%DEElas_P2(3))
    endif
    mc%EElas_P2=mc%DEElas_P2 ! copy array

    ! --- Umbrella Energy ---
    call calcRxnQ(mc,md,mc%rxnQp,-1,-1) ! caclualte only 
    call calcUmbrellaE(mc,md,mc%rxnQp,mc%DEUmbrella,mc%umbBin)

    if(abs(mc%EUmbrella-mc%DEUmbrella).gt. 0.0001_dp) then
        print*, "Warning. Intigraged Umbrella Energy,", &
            mc%EUmbrella, " While abosolute energy is", &
            mc%DEUmbrella
    endif
    mc%EUmbrella=mc%DEUmbrella
    

    ! --- Interaction Energy ---
    if (INTON.EQ.1) then
        ! initialize phi
        IT1=1
        IT2=mc%NT+mc%nBeadsP2 ! need to set up all beads
        do I=1,mc%NBIN
             md%PHIA(I)=0.0_dp
             md%PHIB(I)=0.0_dp
        enddo
        call MC_int(mc,md,IT1,IT2,.True.)
        do I=1,mc%NBIN
            phiTot=phiTot+(md%PHIA(I)+md%PHIB(I))*md%Vol(I)
        enddo
        ! test to see if sum of changes are same as calculating from scratch
        print*, "phiTot", phiTot," NT:",mc%NT
        if(abs(mc%EChi-mc%DEChi).gt. 0.0001_dp) then
             print*, "Warning. Intigrated chi energy:", & 
                     mc%EChi,"  while absolute chi energy:", &
                     mc%DEChi
             write(3,*), "Warning. Intigrated chi energy:", & 
                     mc%EChi,"  while absolute chi energy:", &
                     mc%DEChi
        endif
        mc%EChi=mc%DEChi
        mc%x_chi=mc%dx_chi
        if(abs(mc%ECouple-mc%DECouple).gt. 0.0001_dp) then
             print*, "Warning. Intigrated couple energy:", & 
                     mc%ECouple,"  while absolute couple energy:", &
                     mc%DECouple
             write(3,*), "Warning. Intigrated couple energy:", & 
                     mc%ECouple,"  while absolute couple energy:", &
                     mc%DECouple
        endif
        mc%ECouple=mc%DECouple
        mc%x_Couple=mc%dx_couple
        if(abs(mc%EKap-mc%DEKap).gt. 0.0001_dp) then
             print*, "Warning. Intigrated Kap energy:", & 
                     mc%EKap,"  while absolute Kap energy:", &
                     mc%DEKap
             write(3,*), "Warning. Intigrated Kap energy:", & 
                     mc%EKap,"  while absolute Kap energy:", &
                     mc%DEKap
        endif
        mc%EKap=mc%DEKap
        mc%x_Kap=mc%dx_Kap

        if(abs(mc%EField-mc%DEField).gt.0.00001) then
            print*, "Warning. Integrated field enrgy:", &
                    mc%EField," while absolute field energy:", &
                    mc%DEField
            write(3,*), "Warning. Integrated field enrgy:", &
                    mc%EField," while absolute field energy:", &
                    mc%DEField
        endif
        mc%EField=mc%DEField
        mc%x_Field=mc%dx_Field

        ! check for NaN
        do I=1,mc%NBIN
            if (abs(md%Vol(I)).lt.0.00001) Cycle
            if (isnan(md%PHIA(I))) then
                write(*,"(A,I5,A)"), "PHIA(",I,")=NaN"
                write(*,"(A,I5,A,f8.4)"), "Vol(",I,")=",md%Vol(I)
                stop 1
            endif
            if (isnan(md%PHIB(I))) then
                write(*,"(A,I5,A)"), "PHIB(",I,")=NaN"
                write(*,"(A,I5,A,f8.4)"), "Vol(",I,")=",md%Vol(I)
                stop 1
            endif
            if (isnan(md%Vol(I))) then
                write(*,"(A,I5,A)"), "Vol(",I,")=NaN"
                stop 1
            endif
        enddo

    else
        do I=1,mc%NBIN
             md%PHIA(I)=0.0_dp
             md%PHIB(I)=0.0_dp
        enddo
    endif
    close (3) 

! -------------------------------------
!
!   Begin Monte Carlo simulation
!
! -------------------------------------
    ISTEP=1
    DO WHILE (ISTEP.LE.NSTEP)
       !--------------------------------
       !
       !  Do moves on extra Polymer
       !
       !-------------------------------
       DO MCTYPE=1,mc%moveTypes
          if (MCTYPE.GE.7 .and. MCTYPE.LE.9) cycle
          if (mod(ISTEP,3).gt.0) CYCLE ! save time
          if ((mod(ISTEP,80).ne.0).and. & 
              ((MCTYPE.eq.5).or.(MCTYPE.eq.6))) then
              CYCLE ! save time
          endif

          call MC_move(md%R_P2,md%U_P2,md%RP_P2,md%UP_P2,mc%nBeadsP2,mc%nBeadsP2,1, &
                       IP,IB1,IB2,IT1,IT2,MCTYPE, & 
                       mc%MCAMP,mc%WINDOW,md%AB,md%ABP,mc%G,&
                       rand_stat, mc%winType,IT3,IT4,forward,0)

          IT1plusNT=IT1+mc%NT 
          IT2plusNT=IT2+mc%NT
          if (IT1.NE.IB1 .or. IT2.NE.IB2 .or. IT1.lt.1) then
              print*, "in MCsim"
              print*, "MCTYPE",MCTYPE
              print*,"IT1",IT1,"IB1",IB1,"IT2",IT2,"IB2",IB2
              stop 1
          endif


          do I=IB1,IB2
              md%RP(I+mc%NT,1)=md%RP_P2(I,1)
              md%RP(I+mc%NT,2)=md%RP_P2(I,2)
              md%RP(I+mc%NT,3)=md%RP_P2(I,3)
          enddo

!   Calculate the change in compression and bending energy
          if ((MCTYPE.NE.5) .and. &
              (MCTYPE.NE.6) .and. &
              (MCTYPE.NE.7) .and. &
              (MCTYPE.NE.8) .and. &
              (MCTYPE.NE.9) .and. &
              (MCTYPE.NE.10) )then
              call MC_eelas(mc%DEELAS_P2,md%R_P2,md%U_P2,md%RP_P2,md%UP_P2,&
                            mc%nBeadsP2,mc%nBeadsP2,IB1,IB2, & 
                            IT1,IT2,EB_P2,EPAR_P2,EPERP_P2,GAM_P2,ETA_P2,0)
          else
              mc%DEELAS_P2(1)=0.0
              mc%DEELAS_P2(2)=0.0
              mc%DEELAS_P2(3)=0.0
          endif
!   Calculate the change in the self-interaction energy (actually all
!   interation energy, not just self?)
          if (INTON.EQ.1) then
             if (MCTYPE.EQ.9) then
                 print*, "Don't do move 9"
                 stop
             elseif (MCTYPE.EQ.10) then
                 call MC_int_rep(mc,md,IT1plusNT,IT2plusNT,forward)
             else
                 call MC_int(mc,md,IT1plusNT,IT2plusNT,.false.)
             endif
          else
              mc%DEKap=0.0_dp
              mc%DECouple=0.0_dp
              mc%DEChi=0.0_dp
              mc%DEField=0.0_dp
          endif

!   Calculate the change in confinement energy
          if (mc%confineType.NE.0) then
              print*, "Error: set up confinment for extra polymer"
              stop 1
          else
              mc%ECon=0.0_dp;
          endif

!   Calculate change in Umbrella energy
          if (INTON.eq.1 .and. mc%umbrellaOn) then
              call calcRxnQ(mc,md,mc%rxnQp,IT1,IT2) ! calcualte proposed rxnQ
              call calcUmbrellaE(mc,md,mc%rxnQp,mc%DEUmbrella,mc%umbBin_p) !calculage  proposed energy
              mc%DEUmbrella=mc%DEUmbrella-mc%EUmbrella ! change in energy
              ! now update umbrell sampling ...
              mc%IndUmbrella=mc%IndUmbrella+1 
              if(mod(mc%IndUmbrella,mc%nStepsUmbrella).eq.0) then
                  call updateUmbrella(mc,md)
              endif
              !if ((mod(ISTEP,25000).eq.0).and.(MCTYPE.eq.1)) then
              !    call saveQ(mc)
              !endif
          else
              mc%DEUmbrella=0
          endif 
!   Change the position if appropriate
          ENERGY=mc%DEELAS_P2(1)+mc%DEELAS_P2(2)+mc%DEELAS_P2(3) & 
                 +mc%DEKap+mc%DECouple+mc%DEChi+mc%DEBind+mc%ECon+mc%DEField+ &
                 mc%DEUmbrella
          PROB=exp(-ENERGY)
          call random_number(urnd,rand_stat)
          TEST=urnd(1)
          if (TEST.LE.PROB) then
             if(MCTYPE.EQ.7) then
                 print*, "Not set up"; stop
                 !mc%EBind=mc%EBind+mc%DEBind
                 DO I=IT1,IT2
                      md%AB(I)=md%ABP(I)
                      md%AB(I)=md%ABP(I)
                 ENDDO
             else
                 DO I=IT1,IT2
                     md%R_P2(I,1)=md%RP_P2(I,1)
                     md%R_P2(I,2)=md%RP_P2(I,2)
                     md%R_P2(I,3)=md%RP_P2(I,3)
                     
                     md%U_P2(I,1)=md%UP_P2(I,1)
                     md%U_P2(I,2)=md%UP_P2(I,2)
                     md%U_P2(I,3)=md%UP_P2(I,3)
                     md%R(I+mc%NT,1)=md%RP_P2(I,1)
                     md%R(I+mc%NT,2)=md%RP_P2(I,2)
                     md%R(I+mc%NT,3)=md%RP_P2(I,3)
                 enddo
                 if (MCTYPE.EQ.9) then
                     print*, "Can't do that!"
                     stop 1
                 endif
             endif
             if (mc%ECon.gt.0.0_dp) then
                 print*, "MCTYPE", MCType
                 stop 1
             endif
             mc%EUmbrella=mc%EUmbrella+mc%DEUmbrella
             mc%umbBin=mc%umbBin_p
             mc%rxnQ=mc%rxnQp

             mc%x_mu=mc%x_mu+mc%dx_mu
             mc%EELAS_P2(1)=mc%EELAS_P2(1)+mc%DEELAS_P2(1)
             mc%EELAS_P2(2)=mc%EELAS_P2(2)+mc%DEELAS_P2(2)
             mc%EELAS_P2(3)=mc%EELAS_P2(3)+mc%DEELAS_P2(3)
             if (INTON.EQ.1) then
                DO I=1,mc%NPHI
                   J=md%INDPHI(I)
                   md%PHIA(J)=md%PHIA(J)+md%DPHIA(I)
                   md%PHIB(J)=md%PHIB(J)+md%DPHIB(I)  
                   if ((md%PHIA(J).lt.-0.000001_dp) .or. (md%PHIB(J).lt.-0.00001_dp)) then
                       print*, "Error in MCsim. Negitive phi"
                       stop 1
                   endif
                enddo
                mc%ECouple=mc%ECouple+mc%DECouple
                mc%EKap=mc%EKap+mc%DEKap
                mc%EChi=mc%EChi+mc%DEChi
                mc%EField=mc%EField+mc%DEField
                mc%x_Couple=mc%x_couple+mc%dx_couple
                mc%x_kap=mc%x_Kap+mc%dx_kap
                mc%x_chi=mc%x_chi+mc%dx_chi
                mc%x_field=mc%x_field+mc%dx_field

             endif
             !mc%SUCCESS(MCTYPE)=mc%SUCCESS(MCTYPE)+1
          endif
          ! Keep track of how many times eacy bin is visited
          if (mc%umbrellaOn.and.INTON.eq.1 .and.mc%umbBin.ne.-1) then
             ! if (umbrellaBin.lt.1 .or. umbrellaBin.gt.40) then
             !     print*, "MCTYPE", MCTYPE, "TEST",TEST,"PROB",PROB
             !     print*, "umbrellaBin",umbrellaBin
             !     print*, "umbrellaBin_p",umbrellaBin_p
             !     print*, "INTON",INTON
             !     print*, "mc%umbrellaOn",mc%umbrellaOn
             !     print*, "rxnQ",mc%rxnQ
             !     print*, "mc%minQ",mc%minQ
             !     print*, "nUmbrellaBins",mc%nUmbrellaBins
             !     stop
             ! endif
              md%umbrellaCounts(mc%umbBin)=md%umbrellaCounts(mc%umbBin)+1
          elseif (mc%umbBin.eq.-1) then
              mc%nOutside=mc%nOutside+1
          endif


       enddo

       !---------------------
       !
       !  Do moves on other polymers
       !
       !----------------------
       DO MCTYPE=1,mc%moveTypes

          if (mc%MOVEON(MCTYPE).EQ.0) cycle

          ! Turn down poor moves
          if ((mc%PHit(MCTYPE).lt.mc%MIN_ACCEPT).and. &
              (mod(ISTEP,mc%reduce_move).ne.0).and. &
              ((MCTYPE.eq.5).or.(MCTYPE.eq.6))) then
              CYCLE
          endif
          
          call MC_move(md%R,md%U,md%RP,md%UP,mc%NT,mc%NB,mc%NP, &
                       IP,IB1,IB2,IT1,IT2,MCTYPE, & 
                       mc%MCAMP,mc%WINDOW,md%AB,md%ABP,mc%G,&
                       rand_stat, mc%winType,IT3,IT4,forward,mc%nBeadsP2)
          
!   Calculate the change in compression and bending energy
          if ((MCTYPE.NE.5) .and. &
              (MCTYPE.NE.6) .and. &
              (MCTYPE.NE.7) .and. &
              (MCTYPE.NE.8) .and. &
              (MCTYPE.NE.9) .and. &
              (MCTYPE.NE.10) )then
              call MC_eelas(mc%DEELAS,md%R,md%U,md%RP,md%UP,&
                            mc%NT,mc%NB,IB1,IB2, & 
                            IT1,IT2,EB,EPAR,EPERP,GAM,ETA,mc%nBeadsP2)
          else
              mc%DEELAS(1)=0.0
              mc%DEELAS(2)=0.0
              mc%DEELAS(3)=0.0
          endif
          if (MCTYPE.eq.8) then
              print*, "Flop move not working!  Chain energy isn't symmetric"
              stop 1
          endif
!   Calculate the change in the binding energy
          if (MCTYPE.EQ.7) then
              !print*, 'MCsim says EM:',EM,'EU',EU
              call MC_bind(mc%NT,mc%G,IT1,IT2,md%AB,md%ABP,md%METH,mc%EU,mc%EM, &
                           mc%DEBind,mc%mu,mc%dx_mu,mc%nBeadsP2)
          else
              mc%DEBind=0.0
          endif
         
!   Calculate the change in the self-interaction energy (actually all
!   interation energy, not just self?)
          if (INTON.EQ.1) then
             if (MCTYPE.EQ.9) then
                 !skip if doesn't do anything
                 if (abs(mc%CHI_ON).lt.0.00001) CYCLE
                 call MC_int_swap(mc,md,IT1,IT2,IT3,IT4)
                 if (abs(mc%DEKap).gt.0.0001) then
                     print*, "Error in MCsim.  Kappa energy shouldn't change on move 9"
                     print*, "DEKap", mc%DEKap
                     stop 1
                 endif
             elseif (MCTYPE.EQ.10) then
                 call MC_int_rep(mc,md,IT1,IT2,forward)
             else
                 call MC_int(mc,md,IT1,IT2,.false.)
             endif
          else
              mc%DEKap=0.0_dp
              mc%DECouple=0.0_dp
              mc%DEChi=0.0_dp
              mc%DEField=0.0_dp
          endif
          if ((MCTYPE.eq.8).and.(mc%DEKap.gt.0.00001)) then
              print*, "Error in MCsim. Kappa energy shouldn't change on move 8"
          endif

!   Calculate the change in confinement energy
          if ((MCTYPE.NE.7).and. &
              (MCTYPE.NE.8).and. &
              (MCTYPE.NE.9)) then
              call MC_confine(mc%confineType, mc%LBox, md%RP, mc%NT, & 
                              IT1,IT2,mc%ECon,mc%nBeadsP2)
          else
              mc%ECon=0.0_dp;
          endif

!   Change the position if appropriate
          ENERGY=mc%DEELAS(1)+mc%DEELAS(2)+mc%DEELAS(3) & 
                 +mc%DEKap+mc%DECouple+mc%DEChi+mc%DEBind+mc%ECon+mc%DEField
          PROB=exp(-ENERGY)
          call random_number(urnd,rand_stat)
          TEST=urnd(1)
          if (TEST.LE.PROB) then
             if(MCTYPE.EQ.7) then
                 mc%EBind=mc%EBind+mc%DEBind
                 DO I=IT1,IT2
                      md%AB(I)=md%ABP(I)
                 ENDDO
             else
                 DO I=IT1,IT2
                     md%R(I,1)=md%RP(I,1)
                     md%R(I,2)=md%RP(I,2)
                     md%R(I,3)=md%RP(I,3)
                     md%U(I,1)=md%UP(I,1)
                     md%U(I,2)=md%UP(I,2)
                     md%U(I,3)=md%UP(I,3)
                 enddo
                 if (MCTYPE.EQ.9) then
                     DO I=IT3,IT4
                         md%R(I,1)=md%RP(I,1)
                         md%R(I,2)=md%RP(I,2)
                         md%R(I,3)=md%RP(I,3)
                         md%U(I,1)=md%UP(I,1)
                         md%U(I,2)=md%UP(I,2)
                         md%U(I,3)=md%UP(I,3)
                     enddo
                 endif
             endif
             if (mc%ECon.gt.0.0_dp) then
                 print*, "MCTYPE", MCType
                 call MCvar_printEnergies(mc) 
                 print*, "error in MCsim, out of bounds "
                 stop 1
             endif
             mc%x_mu=mc%x_mu+mc%dx_mu
             mc%EELAS(1)=mc%EELAS(1)+mc%DEELAS(1)
             mc%EELAS(2)=mc%EELAS(2)+mc%DEELAS(2)
             mc%EELAS(3)=mc%EELAS(3)+mc%DEELAS(3)
             !if (mc%EELAS(1) .ne. mc%EELAS(1) .or. mc%EELAS(1).lt.0.0) then
             !    print*, "mc%EElas(1)",mc%EElas(1),"MCTYPE",MCTYPE
             !    print*, "mc%DEELAS(1)",mc%DEELAS(1)
             !    print*, "IT1",IT1,"IT2",IT2,"IB1",IB1,"IB2",IB2
             !    stop 1
             !endif
             if (INTON.EQ.1) then
                DO I=1,mc%NPHI
                   J=md%INDPHI(I)
                   md%PHIA(J)=md%PHIA(J)+md%DPHIA(I)
                   md%PHIB(J)=md%PHIB(J)+md%DPHIB(I)  
                   if ((md%PHIA(J).lt.-0.000001_dp) .or. (md%PHIB(J).lt.-0.00001_dp)) then
                       print*, "Error in MCsim. Negitive phi"
                       stop 1
                   endif
                enddo
                mc%ECouple=mc%ECouple+mc%DECouple
                mc%EKap=mc%EKap+mc%DEKap
                mc%EChi=mc%EChi+mc%DEChi
                mc%EField=mc%EField+mc%DEField
                mc%x_Couple=mc%x_couple+mc%dx_couple
                mc%x_kap=mc%x_Kap+mc%dx_kap
                mc%x_chi=mc%x_chi+mc%dx_chi
                mc%x_field=mc%x_field+mc%dx_field

             endif
             mc%SUCCESS(MCTYPE)=mc%SUCCESS(MCTYPE)+1
          endif
!   Adapt the amplitude of step every NADAPT steps

          !amplitude and window adaptations
          if (mod(ISTEP,mc%NADAPT(MCTYPE)).EQ.0) then  ! Addapt ever NADAPT moves
             call MCvar_adapt(mc,MCTYPE)
           
             ! move each chain back if drifted though repeated BC 
             if (mc%recenter_on) then
                 call MCvar_recenter(mc,md)  ! You don't need to do this if there is confinement
            endif
          endif

       enddo ! End of movetype loop

       !  -----  Parallel tempering ----
       IF (mod(ISTEP,mc%NPT).eq.0) THEN
          call replicaExchange(mc,md)
       ENDIF
      
       ! seps in this subroutine
       ISTEP=ISTEP+1
    enddo ! end of ISTEP loop
    
    RETURN      
END
    
!-------------------------------------------------------------*
