module M_Equil_Write
!--
!-- routines writing results of equilibrium or speciation calculations
!--
  use M_Kinds
  use M_Trace,only: iDebug,fTrc,fHtm,T_,Pause_
  implicit none

  private

  public:: Equil_Write_Detail
  public:: Equil_Write_ShoDetail
  public:: Equil_Write_EnTete
  public:: Equil_Write_LogK

  logical:: Done_WriteLogK= .false.

contains

subroutine Equil_Write_LogK(vCpn,TdgK,Pbar)
!--
!-- write a table of logK of species
!-- calculated with logK-0 for the SYSTEM's primary species
!--
  use M_T_Component,only: T_Component
  use M_Dtb_Test,   only: Dtb_Tabulate_ForSystem
  use M_Basis,      only: Basis_Build
  use M_Basis_Vars, only: vLCi,vLAx,vOrdPr,tNuSp
  use M_TPcond_Read,only: TPpath_Read
  !
  use M_Global_Vars,only: vSpc,vSpcDtb
  use M_Path_Vars,  only: vTPpath
  !
  type(T_Component),intent(in):: vCpn(:)
  real(dp),         intent(in):: TdgK,Pbar
  !
  type(T_Component):: vCpnTmp(size(vCpn))
  !
  if(Done_WriteLogK) return !-------------------------------------return
  !
  vCpnTmp= vCpn
  call Basis_Build(.false.,vCpnTmp)
  !
  call TPpath_Read(TdgK,Pbar)
  !
  call Dtb_Tabulate_ForSystem( &
  & vTPpath, &
  & vCpnTmp,vSpc,vSpcDtb, &
  & vLCi,vLAx,vOrdPr,tNuSp)
  !
  if(allocated(vTPpath)) deallocate(vTPpath)
  !
  Done_WriteLogK= .true.
  !
  return
end subroutine Equil_Write_LogK

subroutine Equil_Write_EnTete(iFile,vSpc,vPrm,vBool,Str1,Str2,WriteCR)
!--
!-- write title line: a name (s) followed by species names
!--
  use M_T_Species,only: T_Species
  !
  integer,        intent(in):: iFile
  type(T_Species),intent(in):: vSpc(:)
  integer,        intent(in):: vPrm(:)
  logical,        intent(in):: vBool(:)
  !
  character(*),   intent(in),optional:: Str1
  character(*),   intent(in),optional:: Str2
  logical,        intent(in),optional:: WriteCR
  !
  integer::I,J
  !
  if(present(Str1)) write(iFile,'(A,A1)',advance="no") trim(Str1),T_
  if(present(Str2)) write(iFile,'(A,A1)',advance="no") trim(Str2),T_

  do J=1,size(vSpc)
    I=vPrm(J)
    if(vBool(I)) write(iFile,'(A,A1)',advance="no") trim(vSpc(I)%NamSp),T_
  enddo
  if(.not. present(WriteCR)) then
    write(iFile,*)
  else
    if(WriteCR) write(iFile,*)
  end if

  return
end subroutine Equil_Write_EnTete

subroutine Equil_Write_Detail(cSelec,TdgK,Pbar,vCpn)
!--
!-- write detailed results for a single speciation
!--
  use M_Numeric_Tools !->CalcPermut
  use M_IoTools !GetUnit
  use M_Files,       only: DirOut,cTitle,File_Write_Date_Time,Files_Index_Write
  use M_Dtb_Const,   only: T_CK, R_JK, F_JV
  use M_Numeric_Const,only: MinExpDP,MaxExpDP,Ln10
  use M_T_Species,   only: T_Species
  use M_T_Component, only: T_Component
  use M_SolModel_Tools,only: Solmodel_CalcMolal,Solmodel_pHpE
  use M_Basis,       only: Basis_CpnInert,Basis_Change
  !
  use M_Global_Vars, only: vSpc,vSpcDtb,vEle,nAq
  use M_Global_Vars, only: vFas,vMixFas,vMixModel
  use M_Basis_Vars,  only: iH_,iBal,isW,MWsv,iOx,isH_,isO2,tStoikio
  use M_Basis_Vars,  only: vOrdPr,tAlfFs,tNuFas
  !
  character(len=3), intent(in):: cSelec
  real(dp),         intent(in):: TdgK,Pbar
  type(T_Component),intent(in):: vCpn(:)
  !
  type(T_Species)  :: S
  character(len=80):: Str1,Str2,Str
  character(len=80):: strFile
  integer :: nCp,nFs,nSp,nPur
  integer :: iPr,iAq,iFs,fo,J,K,iModel
  real(dp):: IonStr
  real(dp):: X,Y,Affin,pH_,pE_,Eh_
  real(dp):: Z_Plus,Z_Minus
  logical,parameter:: ReportMajorOnly= .false.
  !
  integer, allocatable::vPrm(:),vPrmMs(:)
  real(dp),allocatable::vMolal(:),vQsK(:)
  !
  type(T_Component),dimension(:),allocatable:: vCpnInert
  ! type(T_Component),dimension(:),allocatable:: vC
  !
  if(iDebug>0) write(fTrc,'(/,A)') "< Equil_Write_Detail"
  !
  nCp=size(vCpn)
  nSp=size(vSpc)
  nFs=size(vFas)
  !
  allocate(vPrm(nAq))
  allocate(vMolal(nAq))
  !
  Z_Plus= SUM(vSpc(1:nAq)%Dat%Mole*vSpc(1:nAq)%Z, MASK=(vSpc(1:nAq)%Z >0))
  Z_Minus=SUM(vSpc(1:nAq)%Dat%Mole*vSpc(1:nAq)%Z, MASK=(vSpc(1:nAq)%Z <0))
  !
  call Solmodel_CalcMolal(vSpc,isW,vMolal,IonStr)
  call Solmodel_pHpE(isW,iOx,isH_,isO2,vSpc,pH_,pE_)
  !
  select case(trim(cSelec))
  case("SPC")  ;  strfile="_specia.res"
  case("MIX")  ;  strfile="_specia_mix.res"
  case("BOX")  ;  strfile="_specia_box.res"
  case("INJ")  ;  strfile="_specia_inj.res"
  case("INI")  ;  strfile="_specia_ini.res"
  case("DYN")  ;  strfile="_specia_end.res"
  case("EQ1","EQ2","EQM")  ; strfile="_equil.res"
  end select
  !
  call GetUNit(fo)
  open(fo,file=trim(DirOut)//trim(strFile))

  call Files_Index_Write(fHtm,&
  & trim(DirOut)//trim(strFile),&
  & "SPC/EQU: result of speciation or equilibrium")
  !
  call File_Write_Date_Time(fo)
  !
  write(fo,'(A)') "!."//trim(cTitle)
  !
  select case(trim(cSelec))
    case("EQ1","EQ2","EQM")
      write(fo,'(A)') "!.fluid in equilibrium with other phases"
    case("SPC")
      write(fo,'(A)') "!.fluid speciation (before interaction)"
    case("DYN")
      write(fo,'(A)') "!.fluid speciation (after interaction)"
    case("INI")
      write(fo,'(A)') "!.fluid speciation (begin interaction)"
    case("MIX")
      write(fo,'(A)') "!.fluid speciation of mixing fluid"
  end select
  !
  !write(fo,'(A)') "INPUT="//trim(NamFInn)
  !-------------------------------------------------write Charge Balance
  X= Zero
  if(Z_Plus - Z_Minus > EPSILON(X)) X= (Z_Plus + Z_Minus)/(Z_Plus - Z_Minus)
  write(fo,'(/,A)') &
  & "Charge balance, sum(+), sum(-), delta/sum"
  write(fo,'(3G15.6,/)') Z_Plus,Z_Minus,X
  !
  if(iBal==0 .and. vCpn(iH_)%Statut/="INERT") &
  & write(fo,'(A,/,A,/,A)') &
  & "!!!", &
  & "!CAVEAT! NO Element For Electron Balance -> ELECTRONEUTRALITY NOT ENFORCED", &
  & "!!!"
  !--/
  
  !---------------------------------------------------GLOBAL COMPOSITION
  allocate(vCpnInert(1:nCp))
  call Basis_CpnInert(isW,tStoikio,vCpn,vCpnInert)
  !
  write(fo,'(A,/,A,/,A)') &
  & "!-----------------------------------------------------------------------", &
  & "!--fluid composition, mole nr / kgH2O-----------------------------------", &
  & "!--can be used as SYSTEM for a new all-inert run------------------------"
  write(fo,'(2X,A,G15.6)') "TdgC  ",TdgK-T_CK
  write(fo,'(2X,A,G15.6)') "Pbar  ",Pbar
  do iPr=1,size(vCpn)
    write(fo,'(2X,3(A,1X),G15.6)') &
    & vEle(vCpnInert(iPr)%iEle)%NamEl, &
    & "INERT", &
    & vSpc(vCpnInert(iPr)%iSpc)%NamSp,&
    & vCpnInert(iPr)%Mole /MWsv /vCpnInert(isW)%Mole
  enddo
  write(fo,'(A,/)') &
  & "!-----------------------------------------------------------------------"
  !
  deallocate(vCpnInert)
  !
  if(cSelec(1:2)=="EQ") then

    write(fo,'(A,/,A)') "!","!total composition"
    !write(fo,'(A)') "!can be used as input for fluid mixing"
    do iPr=1,size(vCpn)
      X= SUM(tStoikio(iPr,1:nAq)*vSpc(1:nAq)%Dat%Mole) &
      +  SUM(tAlfFs(iPr,1:nFs) *vFas(1:nFs)%Mole)
      write(fo,'(A,2(A1,G24.17))') vEle(vCpn(iPr)%iEle)%NamEl,T_,X !,T_,Y
    enddo

  end if
  !--------------------------------------------------/GLOBAL COMPOSITION
  !
  !--------------------------------------------------ELEMENTS,COMPONENTS
  write(fo,'(A)') &
  & "!-----------------------------------------------------------------------"
  write(fo,'(A)') "!element, status, mole balance, mole number, mg/kg"
  !
  do iPr=1,size(vCpn)
    !
    X= SUM(tStoikio(iPr,1:nAq)*vSpc(1:nAq)%Dat%Mole) !-> abundance in fluid
    Y= X *vEle(vCpn(iPr)%iEle)%WeitKg *1.D6 !-> kg to mg

    !---COMMENT--
    !  value of vCpn(:)%Mole has not been updated !!
    !  seems it is the input value ....
    !---/

    write(fo,'(I3,A1,2(A,A1),3(G15.8,A1))',advance="NO") &
    & iPr,                       T_, &
    & vEle(vCpn(iPr)%iEle)%NamEl,T_, &
    & vCpn(iPr)%Statut,          T_, &
    & vCpn(iPr)%Mole,            T_, &
    & X,T_,Y,T_
    !
    !if(vCpn(iPr)%Statut=="MOBILE") & !
    if(    trim(vCpn(iPr)%Statut)=="MOBILE" &
    & .or. trim(vCpn(iPr)%Statut)=="BUFFER") &
    & write(fo,'(G15.6,A1,A,A1)',advance="NO") &
    & exp(vSpc(vCpn(iPr)%iSpc)%Dat%LAct),T_,vSpc(vCpn(iPr)%iSpc)%NamSp,T_
    !
    write(fo,*)
    !
  enddo
  !
  !-------------------------------------------------/ELEMENTS,COMPONENTS
  
  !--------------------------------------------------------------pH, etc
  write(fo,'(A)') &
  & "!-----------------------------------------------------------------------"
  write(fo,'(A,G12.3)') "pH=         ",pH_ !vSpc(isH_)%LnAct/Ln10
  if(iOx>0) then
    Eh_= pE_ *TdgK *Ln10 *R_JK /F_JV
    write(fo,'(A,G12.3)') "pE=         ",pE_
    write(fo,'(A,G12.3)') "Eh(Volts)=  ",Eh_
  end if
  write(fo,'(A12,G12.3)')            "IonStrength=",IonStr
  !------------------------------------------------------------/ pH, etc
  
  !---------------------------------------------------EQUILIBRIUM.PHASES
  if(cSelec(1:2)=="EQ") then
    !
    write(fo,'(A)') &
    & "!-----------------------------------------------------------------------"

    write(fo,'(A)') "Equilibrium Species (result of Equil_n)"

    do iFs=1,size(vFas)

      if(vFas(iFs)%Mole > Zero) then

        write(fo,'(2A,G15.6)', advance="NO") &
        & vFas(iFs)%NamFs," MOLE=",vFas(iFs)%Mole

        if(vFas(iFs)%iMix>0) then
          write(fo,'(A)',advance="NO") " X(:)="
          !print *, "vFas(iFs)%iMix",vFas(iFs)%iMix
          !pause
          iModel= vMixFas(vFas(iFs)%iMix)%iModel
          !print *, "iModel, nPole=",iModel,vMixModel(iModel)%nPole
          !pause
          do J=1,vMixModel(iModel)%nPole
            write(fo,'(G15.6,1X)',advance="NO") &
            & vMixFas(vFas(iFs)%iMix)%vXPole(J)
          enddo
        end if
        write(fo,*)

      end if

    enddo

    write(fo,'(A)') &
    & "!-----------------------------------------------------------------------"

    !-------------------------------------------------------------header
    write(fo,'(A7,A1)', advance="NO") "Element",T_
    write(fo,'(A15,A1)',advance="NO") "Fluid          ",T_
    do iFs=1,nFs
      if(vFas(iFs)%Mole > Zero) &
      write(fo,'(A15,A1)',advance="NO") vFas(iFs)%NamFs,T_
    enddo
    write(fo,*)
    !------------------------------------------------------------------/

    !--------------results: distribution of element amounts among phases
    do iPr=1,size(vCpn)
      write(fo,'(A7,A1)',advance="NO") vEle(vCpn(iPr)%iEle)%NamEl,T_
      X= SUM(tStoikio(iPr,1:nAq)*vSpc(1:nAq)%Dat%Mole)
      write(fo,'(G15.6,A1)',advance="NO") X,T_
      do iFs=1,nFs
        if(vFas(iFs)%Mole > Zero .and. vFas(iFs)%iSpc/=0) then
          !!!todo!!! print *,vFas(iFs)%NamFs
          write(fo,'(G15.6,A1)',advance="NO") &
          & tStoikio(iPr,vFas(iFs)%iSpc)*vFas(iFs)%Mole,T_
        end if
      enddo
      write(fo,*)
    enddo
    !------------------------------------------------------------------/

    write(fo,'(A)') &
    & "!-----------------------------------------------------------------------"

    write(fo,'(A)') "Fluid Composition"
    do iPr=1,size(vCpn)
      X=SUM(tStoikio(iPr,1:nAq)*vSpc(1:nAq)%Dat%Mole)
      write(fo,'(I3,A1,2(A,A1),G15.6,A1)',advance="NO") &
      & iPr,T_, vEle(vCpn(iPr)%iEle)%NamEl,T_, vCpn(iPr)%Statut,T_,X,T_
      !if(trim(vCpn(iPr)%Statut)=="MOBILE") &!
      if(trim(vCpn(iPr)%Statut)=="MOBILE" .or. &
      &  trim(vCpn(iPr)%Statut)=="BUFFER") &
      & write(fo,'(G15.6,A1,A,A1)',advance="NO") &
      & exp(vSpc(vCpn(iPr)%iSpc)%Dat%LAct),T_,vSpc(vCpn(iPr)%iSpc)%NamSp,T_
      write(fo,*)
    enddo

    write(fo,'(A)') &
    & "!-----------------------------------------------------------------------"

  end if !(cSelec=="EQ*")
  !--------------------------------------------------/EQUILIBRIUM.PHASES
  !
  !--- order species --
  call CalcPermut(vSpc(1:nAq)%Dat%Mole,vPrm)
  !-> order species by increasing abundance
  !to apply permutation vPermut to array Arr: Arr=Arr(vPermut)
  !---/
  !
  !----------------------------------------------------------AQU.SPECIES
  write(fo,'(A)') &
  & "!-----------------------------------------------------------------------"
  write(fo,'(A)') "All Species, in order of decreasing Mole number"
  !
  write(fo,'(A15,A1)',   advance="no") "________SPECIES",T_
  write(fo,'(2(A12,A1))',advance="no") "_MOLE_NUMBER",T_,"_MOLALITY___",T_
  write(fo,'(2(A12,A1))',advance="no") "_log(GAMMA)_",T_,"_GAMMA______",T_
  write(fo,'(2(A12,A1))',advance="no") "log(ACTIVIT)",T_,"_ACTIVITY___",T_
  write(fo,*)
  !
  !-----------------------------------------ordered in decreasing amount
  !do iPr=1,nCp

    do iAq=nAq,1,-1

      S= vSpc(vPrm(iAq))
      X= S%Dat%Mole /vSpc(isW)%Dat%Mole /vSpc(isW)%WeitKg
      !-> X is molality

      write(fo,'(A15,A1)',advance="no")  trim(S%NamSp),T_

      write(fo,'(5(G12.5,A1))',advance="no") &
      & S%Dat%Mole,      T_, &
      & X,               T_, &
      & S%Dat%LGam/Ln10, T_, &
      & exp(S%Dat%LGam), T_, &
      & S%Dat%LAct/Ln10, T_

      if(S%Dat%LAct>MinExpDP .and. S%Dat%LAct<MaxExpDP) then
        write(fo,'(G12.5,A1)') exp(S%Dat%LAct),T_
      else
        write(fo,*)
      end if

    enddo

  !enddo
  write(fo,*)
  !---------------------------------------------------------/AQU.SPECIES

  !-----------------------------------------------------RELATIVE AMOUNTS
  write(fo,'(/,2A,/)') &
  & "for each Element, Species in order of decreasing Mole number", &
  & "Relative Amounts in Permil of Total Amount"
  write(fo,*)
  !
  write(fo,'(A15,A1,A7,A1)',advance="no")  &
  & "________ELEMENT",T_,"_STOKIO",T_
  write(fo,'(7(A15,A1))',   advance="no")  &
  & "________SPECIES",T_, &
  & "RELATIVE_AMOUNT",T_,"_______MOLALITY",T_,"___MOLE_NUMBER_",T_, &
  & "____ACTIV_COEFF",T_,"__log(ACTIVITY)",T_,"_______ACTIVITY",T_
  write(fo,*)
  !
  do iPr=2,nCp
    !
    write(fo,'(A15,A1,A7,A1,A15,A1,F15.3)') &
    & vEle(vCpn(iPr)%iEle)%NamEl,T_, &
    & "___",                    T_, &
    & "        TOT=",           T_, &
    & vCpn(iPr)%Mole
    !
    do iAq=nAq,1,-1

      if(tStoikio(iPr,vPrm(iAq))/=0) then
        S= vSpc(vPrm(iAq))
        !
        X= 1000.0D0 *ABS(tStoikio(iPr,vPrm(iAq))) *S%Dat%Mole &
        &  /SUM(tStoikio(iPr,:)*vSpc(:)%Dat%Mole)
        !
        write(fo,'(A15,A1,F7.2,A1)',advance="no") &
        & vEle(vCpn(iPr)%iEle)%NamEl, T_, &
        & tStoikio(iPr,vPrm(iAq)),   T_
        write(fo,'(A15,A1)',     advance="no") trim(S%NamSp),T_
        write(fo,'(5(G15.6,A1))',advance="no") &
        & X,                T_, &
        & vMolal(vPrm(iAq)),T_, &
        & S%Dat%Mole,       T_, &
        & exp(S%Dat%LGam),  T_, &
        & S%Dat%LAct/Ln10
        !
        if(S%Dat%LAct>MinExpDP .and. S%Dat%LAct<MaxExpDP) then
          write(fo,'(G15.6,A1)') exp(S%Dat%LAct),T_
        else
          write(fo,*)
        end if
        !
      end if

    enddo
    !
    write(fo,'(A)') &
    & "!-----------------------------------------------------------------------"
    !
  enddo
  !----------------------------------------------------/RELATIVE AMOUNTS

  !--------------------------------------------RELATIVE AMOUNTS (MAJORS)
  if(ReportMajorOnly) then
    !
    write(fo,'(/,A,/)') & !the same, only major species ....
    & "for each Element, Species in order of decreasing Mole number, only Major"
    !
    do iPr=2,nCp

      write(fo,'(A12,A1,A3,A1,A12,A1,F15.3)') &
      & vEle(vCpn(iPr)%iEle)%NamEl,T_, &
      & "___",                     T_, &
      & "        TOT=",            T_, &
      & vCpn(iPr)%Mole

      do iAq=nAq,1,-1

        if(tStoikio(iPr,vPrm(iAq))/=0) then
          S=vSpc(vPrm(iAq))
          X=1.0D3 *ABS(tStoikio(iPr,vPrm(iAq))) &
          &       *S%Dat%Mole &
          &       /SUM(tStoikio(iPr,:)*vSpc(:)%Dat%Mole)
          if(X>=10.0D0) then
            write(fo,'(A12,A1,F7.2,A1)',    advance="no") &
            & vEle(vCpn(iPr)%iEle)%NamEl, T_, &
            & tStoikio(iPr,vPrm(iAq)),   T_
            write(fo,'(A12,A1)',            advance="no") &
            & trim(S%NamSp),T_
            write(fo,'(F15.3, A1,F15.4,A1)',advance="no") &
            & X,                T_, &
            & vMolal(vPrm(iAq)),T_
            write(fo,'(F15.8, A1,G15.4,A1)',advance="no") &
            & S%Dat%Mole, T_, &
            & S%Dat%Mole, T_
            write(fo,'(G15.4,A1,G15.4,A1,G15.4)') &
            & exp(S%Dat%LGam),T_, &
            & exp(S%Dat%LAct),T_, &
            & S%Dat%LAct/Ln10
          end if
        end if

      enddo

    enddo
    !
  end if
  !-------------------------------------------/RELATIVE AMOUNTS (MAJORS)
  !
  !-------------------------------------------AFFINITIES PHASES vs FLUID
  if(nFs>0) then
    !
    nPur= count(vFas(:)%iSpc>0)
    !
    allocate(vQsK(1:nPur))
    allocate(vPrmMs(1:nPur))
    !
    write(fo,'(/,A,/)') &
    & "logQsK, all non-aqueous phases, Minerals & Gases"
    !
    !--- calculate logQsk -> store in vQsk
    do iFs=1,nPur
      Affin= vFas(iFs)%Grt &
      &    - dot_product( tNuFas(iFs,1:nCp),  &
      &        vSpc(vOrdPr(1:nCp))%Dat%LAct + vSpc(vOrdPr(1:nCp))%G0rt )
      vQsK(iFs)= - Affin /Ln10
    enddo
    !
    !-------------sort minerals in order of increasing saturation degree
    call CalcPermut(vQsk(:),vPrmMs(:))
    !
    !---------------------write sorted (in both F12.3 and G15.8 formats)
    do iFs=nPur,1,-1
      J=vPrmMs(iFs)
      write(fo,'(A24,A1,F12.3,A1,G15.8,A1)',advance="no") &
      & trim(vFas(J)%NamFs),T_,&
      & vQsk(J),T_,&
      & vQsk(J),T_
      write(fo,*)
    enddo
    !---/
    !
    write(fo,'(/,2(A,/))') &
    & "logQsK, all non-aqueous phases, Minerals & Gases", &
    & "scaled to stoichiometric numbers of moles of prim'species in reaction"
    !--- compute logQsk -> store in vQsk --
    do iFs=1,nPur
      Affin= vFas(iFs)%Grt &
      &    - dot_product( tNuFas(iFs,1:nCp), &
      &                   vSpc(vOrdPr(1:nCp))%Dat%LAct &
      &                   +vSpc(vOrdPr(1:nCp))%G0rt )
      vQsK(iFs)= -Affin /Ln10 /SUM(ABS(tNuFas(iFs,1:nCp)))
    enddo
    !---/
    !
    !---------------sort phases in order of increasing saturation degree
    call CalcPermut(vQsk(:),vPrmMs(:))
    !
    !---------------------write sorted (in both F12.3 and G15.8 formats)
    do iFs=nPur,1,-1
      J= vPrmMs(iFs)
      !! if(vFas(J)%iSpc/=0) then
      Str1="_"
      Str2="_"
      if(vFas(J)%iSpc/=0) then
        K= vFas(J)%iSpc
        if(vSpc(K)%iDtb>0) Str1= trim(vSpcDtb(vSpc(K)%iDtb)%DtbTrace)
        if(vSpc(K)%iDtb>0) Str2= trim(vSpc(K)%Formula)
      end if
      write(fo,'(A24,A1,F12.3,A1,G15.8,A1,A7,A1,A,A1)',advance="no") &
      & trim(vFas(J)%NamFs),T_, &
      & vQsk(J),            T_, &
      & vQsk(J),            T_, &
      & trim(Str1),         T_, &
      & trim(Str2),         T_
      write(fo,*)
    enddo
    !---/
    !
    deallocate(vQsK)
    deallocate(vPrmMs)
    !
  end if !if(nFs>0)
  !------------------------------------------/AFFINITIES PHASES vs FLUID
  !
  deallocate(vPrm)
  deallocate(vMolal)
  !
  close(fo)
  !
  if(iDebug>0) then
    print '(/,A,/)',&
    & "Speciation detail saved in file "//trim(DirOut)//trim(strFile)
    if(iDebug>1) call Pause_
  end if
  !
  if(iDebug>0) write(fTrc,'(A,/)') "</ Equil_Write_Detail"
  !
end subroutine Equil_Write_Detail

subroutine Equil_Write_ShoDetail(cSelec,TdgK,Pbar,vCpn)
!--
!-- write detailed results for a single speciation
!--
  use M_Numeric_Tools !->CalcPermut
  use M_IoTools !GetUnit
  use M_Files,       only: DirOut,cTitle
  !
  use M_Dtb_Const,   only: T_CK
  use M_Numeric_Const,only: MinExpDP,MaxExpDP,Ln10
  !
  use M_SolModel_Tools,only: Solmodel_CalcMolal,Solmodel_pHpE
  !
  use M_T_Component, only: T_Component
  use M_T_Species,   only: T_Species
  !
  use M_Global_Vars, only: vSpc,vEle,vFas,nAq
  use M_Basis_Vars,  only: iH_,isW,iOx,isH_,isO2,MWsv
  use M_Basis_Vars,  only: vOrdPr,tNuFas,tAlfFs,tStoikio
  !
  character(len=3), intent(in):: cSelec
  real(dp),         intent(in):: TdgK,Pbar
  type(T_Component),intent(in):: vCpn(:)
  !
  type(T_Species):: S
  integer :: nCp,nFs,nSp
  integer :: iPr,iAq,iMs !,J
  real(dp):: IonStr
  real(dp):: X,pH_,pE_ !,Y,Affin
  real(dp):: Z_Plus,Z_Minus
  integer :: vPrm(nAq)
  real(dp):: vMolal(nAq)
  !
  integer,parameter:: FF= 6 != write on screen

  if(iDebug>0) write(fTrc,'(/,A)') "< Equil_Write_ShoDetail"
  !
  nCp= size(vCpn)
  nSp= size(vSpc)
  nFs= size(vFas)
  nFs= count(vFas(:)%iSpc>0)
  !
  Z_Plus= SUM(vSpc(1:nAq)%Dat%Mole*vSpc(1:nAq)%Z, MASK=(vSpc(1:nAq)%Z >0))
  Z_Minus=SUM(vSpc(1:nAq)%Dat%Mole*vSpc(1:nAq)%Z, MASK=(vSpc(1:nAq)%Z <0))
  !
  call Solmodel_CalcMolal(vSpc,isW,vMolal,IonStr)
  call Solmodel_pHpE(isW,iOx,isH_,isO2,vSpc,pH_,pE_)
  !
  write(FF,'(A)') "----------------------------------------------------"
  write(FF,'(A)') "----------------------------------------- results --"
  write(FF,'(A)') "----------------------------------------------------"
  write(FF,'(2(A,G15.6,A1))') "TdgC=",TdgK-T_CK,T_,"Pbar=",Pbar,T_
  !
  !---------------------------------------------------global composition
  write(FF,'(A)') "< --------------------- global composition (mole) --"
  do iPr=1,size(vCpn)
    X=  SUM(tStoikio(iPr,1:nAq)*vSpc(1:nAq)%Dat%Mole) & !-> abundance in fluid
    & + SUM(tAlfFs(iPr,1:nFs) *vFas(1:nFs)%Mole)
    write(FF,'(A,A1,G15.6)') vEle(vCpn(iPr)%iEle)%NamEl,T_,X
  enddo
  write(FF,'(A)') "</--"
  write(FF,*)

  !----------------------------------------------------fluid composition
  write(FF,'(A)') "< ---------------- fluid composition (mole|activ) --"
  do iPr=1,size(vCpn)
    !
    write(FF,'(I3,1X,2(A,A1))',advance="NO") &
    & iPr,vEle(vCpn(iPr)%iEle)%NamEl,T_,vCpn(iPr)%Statut,T_
    !
    if(trim(vCpn(iPr)%Statut)=="MOBILE" .or. &
    &  trim(vCpn(iPr)%Statut)=="BUFFER") then

      !------for MOBILE/BUFFER comp't print activity and related species
      write(FF,'(G15.6,A1,A)') &
      & exp(vSpc(vCpn(iPr)%iSpc)%Dat%LAct), T_, &
      & vSpc(vCpn(iPr)%iSpc)%NamSp

    else

      !---------------------for INERT/BALANCE species, print mole number
      X= SUM(tStoikio(iPr,1:nAq)*vSpc(1:nAq)%Dat%Mole)
      write(FF,'(G15.6,A1,G15.6)') vCpn(iPr)%Mole,T_,X

    end if
    !
  enddo
  write(FF,'(A)') "</--"
  write(FF,*)

  !---------------------------------------------------------------------
  write(FF,'(A)') "< ----------------------- neutrality, pH, pE, ... --"
  !
  write(FF,'(3(A,G15.6,/))') &
  & "  Sum(+)=     ", Z_Plus,    &
  & "  Sum(-)=     ", Z_Minus,   &
  & "  Balance=    ", ABS(Z_Plus + Z_Minus)
  !
  write(FF,'(A,G12.3)')           "  pH=         ",pH_ !vSpc(isH_)%LnAct/Ln10
  if(iOx>0) write(FF,'(A,G12.3)') "  pE=         ",pE_
  write(FF,'(A,G12.3)')           "  IonStrength=",IonStr
  !
  write(FF,'(A)') "</-- " !neutrality, pH, pE, ... --"
  write(FF,*)

  !-------------------------------------------------for equilibrium runs
  if(cSelec(1:2)=="EQ") then

    write(FF,'(A)') "< ------------------------- equilibrium results --"
    !
    write(FF,'(A)') "------------------------------- minerals, gases --"
    do iMs=1,size(vFas)
      if(vFas(iMs)%Mole > Zero) &
      write(FF,'(G15.6,2A)') vFas(iMs)%Mole,"= ",trim(vFas(iMs)%NamFs)
    enddo
    write(FF,'(A)') "--"
    !
    write(FF,'(A)') "----------------------------------------- fluid --"
    do iPr=1,size(vCpn)
      !
      X=SUM(tStoikio(iPr,1:nAq)*vSpc(1:nAq)%Dat%Mole)
      write(FF,'(I3,A1,2(A,A1),G15.8,A1)',advance="NO") &
      & iPr,                                        T_, &
      & vEle(vCpn(iPr)%iEle)%NamEl,                 T_, &
      & vCpn(iPr)%Statut,                           T_, &
      & X,                                          T_
      !if(trim(vCpn(iPr)%Statut)=="MOBILE") & !
      !
      if(trim(vCpn(iPr)%Statut)=="MOBILE" .or. &
      &  trim(vCpn(iPr)%Statut)=="BUFFER") &
      & write(FF,'(G15.6,A1,A,A1)',advance="NO") &
      & exp(vSpc(vCpn(iPr)%iSpc)%Dat%LAct),  T_, &
      & vSpc(vCpn(iPr)%iSpc)%NamSp,          T_
      !
      write(FF,*)
    
    enddo
    
    write(FF,'(A)') "--"
    write(FF,'(A)') "</------------------------- equilibrium results --"

  end if
  !------------------------------------------------/for equilibrium runs

  write(FF,'(A)') &
  & "!-----------------------------------------------------------------------"
  write(FF,'(A)') "All Species, in order of decreasing Mole number"
  !
  ! order species by increasing abundance
  !,to apply permutation vPrm to array Arr: Arr=Arr(vPrm)
  call CalcPermut(vSpc(1:nAq)%Dat%Mole,vPrm)
  !
  write(FF,'(4(A15,A1))') &
  & "________SPECIES",T_,"____MOLE_NUMBER",T_, &
  & "____ACTIV_COEFF",T_,"__log(ACTIVITY)",T_
  do iAq=nAq,1,-1
    S=vSpc(vPrm(iAq))
    write(FF,'(A15,A1,3(G15.6,A1))') &
    & trim(S%NamSp),  T_, &
    & S%Dat%Mole,     T_, &
    & exp(S%Dat%LGam),T_, &
    & S%Dat%LAct/Ln10,T_
  enddo
  write(FF,'(A)') &
  & "!-----------------------------------------------------------------------"
  !
  if(iDebug>0) write(fTrc,'(A,/)') "</ Equil_Write_ShoDetail"

  return
end subroutine Equil_Write_ShoDetail

end module M_Equil_Write