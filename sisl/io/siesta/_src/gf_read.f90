subroutine read_open_gf(fname, iu )
  use io_m, only: open_file

  implicit none

  ! Input parameters
  character(len=*), intent(in) :: fname
  integer, intent(out) :: iu

  ! Define f2py intents
!f2py intent(in) :: fname
!f2py intent(out) :: iu

  ! Open file
  call open_file(fname, 'read', 'old', 'unformatted', iu)

end subroutine read_open_gf

subroutine read_gf_sizes(iu, nspin, no_u, nkpt, NE)
  use io_m, only: iostat_update

  implicit none

  ! Precision 
  integer, parameter :: dp = selected_real_kind(p=15)

  ! Input parameters
  integer, intent(in) :: iu
  integer, intent(out) :: nspin, no_u, nkpt, NE

  ! Define f2py intents
!f2py intent(in) :: iu
!f2py intent(out) :: nspin
!f2py intent(out) :: no_u
!f2py intent(out) :: nkpt
!f2py intent(out) :: NE

  ! Local variables
  integer :: na_used, ierr

  read(iu, iostat=ierr) nspin !cell
  call iostat_update(ierr)
  read(iu, iostat=ierr) !na_u, no_u
  call iostat_update(ierr)
  read(iu, iostat=ierr) na_used, no_u
  call iostat_update(ierr)
  read(iu, iostat=ierr) !xa_used, lasto_used
  call iostat_update(ierr)
  read(iu, iostat=ierr) !.false., Bloch, pre_expand
  call iostat_update(ierr)
  read(iu, iostat=ierr) !mu
  call iostat_update(ierr)

  ! k-points
  read(iu, iostat=ierr) nkpt
  call iostat_update(ierr)
  read(iu, iostat=ierr) !
  call iostat_update(ierr)

  read(iu, iostat=ierr) NE
  call iostat_update(ierr)

end subroutine read_gf_sizes

subroutine read_gf_header(iu, nkpt, kpt, NE, E)
  use io_m, only: iostat_update

  implicit none

  ! Precision 
  integer, parameter :: dp = selected_real_kind(p=15)

  ! Input parameters
  integer, intent(in) :: iu
  integer, intent(in) :: nkpt, NE
  real(dp), intent(out) :: kpt(3,nkpt)
  complex(dp), intent(out) :: E(NE)

  ! Define f2py intents
!f2py intent(in) :: iu
!f2py intent(in) :: nkpt
!f2py intent(in) :: NE
!f2py intent(out) :: kpt
!f2py intent(out) :: E

  integer :: ierr

  read(iu, iostat=ierr) !nspin, cell
  call iostat_update(ierr)
  read(iu, iostat=ierr) !na_u, no_u
  call iostat_update(ierr)
  read(iu, iostat=ierr) !na_used, no_used
  call iostat_update(ierr)
  read(iu, iostat=ierr) !xa_used, lasto_used
  call iostat_update(ierr)
  read(iu, iostat=ierr) !.false., Bloch, pre_expand
  call iostat_update(ierr)
  read(iu, iostat=ierr) !mu
  call iostat_update(ierr)

  ! k-points
  read(iu, iostat=ierr) !nkpt
  call iostat_update(ierr)
  read(iu, iostat=ierr) kpt
  call iostat_update(ierr)

  read(iu, iostat=ierr) !NE
  call iostat_update(ierr)
  read(iu, iostat=ierr) E
  call iostat_update(ierr)

end subroutine read_gf_header

subroutine read_gf_find(iu, nspin, nkpt, NE, &
    cstate, cspin, ckpt, cE, cis_read, istate, ispin, ikpt, iE)
  use io_m, only: iostat_update

  implicit none

  ! Input parameters
  integer, intent(in) :: iu
  integer, intent(in) :: nspin, nkpt, NE
  integer, intent(in) :: cstate, cspin, ckpt, cE, cis_read
  integer, intent(in) :: istate, ispin, ikpt, iE

  ! Define f2py intents
!f2py intent(in) :: iu, nspin, nkpt, NE
!f2py intent(in) :: cstate, cspin, ckpt, cE, cis_read
!f2py intent(in) :: istate, ispin, ikpt, iE

  integer :: ierr, i

  ! We calculate the current record position
  ! Then we calculate the resulting record position
  ! Finally we backspace or read to the record position
  integer :: crec, irec

  if ( istate == -1 ) then
    ! Easy case, the file should be re-read from the beginning
    rewind(iu, iostat=ierr)
    call iostat_update(ierr)
    return
  end if

  if ( cstate == -1 ) then
    ! Skip to the start of the file
    ! There are 10 fields that needs to be read past
    do irec = 1, 10
      read(iu, iostat=ierr)
      call iostat_update(ierr)
    end do
  end if

  ! Find linear record index
  crec = linear_rec(cstate, cspin, ckpt, cE, cis_read)
  irec = linear_rec(istate, ispin, ikpt, iE, 0)

  if ( crec < irec ) then
    do i = crec, irec - 1
      read(iu, iostat=ierr) ! record
      call iostat_update(ierr)
    end do
  else if ( crec > irec ) then
    do i = irec, crec - 1
      backspace(iu, iostat=ierr) ! record
      call iostat_update(ierr)
    end do
  end if

contains

  function linear_rec(state, ispin, ikpt, iE, is_read) result(irec)
    ! Note that these indices are 0-based
    integer, intent(in) :: state, ispin, ikpt, iE, is_read
    integer :: irec

    integer :: nHS, nSE

    ! Skip to the spin
    nHS = max(0, ispin) * nkpt
    nSE = max(0, ispin) * nkpt * NE
    ! per H and S we also have ik, iE, E
    ! per SE we also have ik, iE, E (except for the first energy-point where we don't have it)
    irec = nHS * 3 + nSE * 2 - nHS

    ! Skip to the k-point
    nHS = max(0, ikpt)
    nSE = max(0, ikpt) * NE
    irec = irec + nHS * 3 + nSE * 2 - nHS

    ! Skip to the energy-point
    irec = irec + max(0, iE) * 2
    if ( iE > 0 ) irec = irec - 1 ! correct the iE == 0 ik, iE, E line

    ! If the state is 0, it means that we should read beyond H and S for the given k-point
    if ( state == 0 ) irec = irec + 3

    if ( is_read == 1 ) then
      ! Means that we already have read past this entry
      if ( iE > 0 ) then
        irec = irec + 2
      end if
    end if

  end function linear_rec

end subroutine read_gf_find

subroutine read_gf_hs(iu, no_u, H, S)
  use io_m, only: iostat_update

  implicit none

  ! Precision 
  integer, parameter :: dp = selected_real_kind(p=15)

  ! Input parameters
  integer, intent(in) :: iu
  integer, intent(in) :: no_u

  ! Variables for the size
  complex(dp), intent(out) :: H(no_u,no_u), S(no_u,no_u)

  ! Define f2py intents
!f2py intent(in) :: iu
!f2py intent(in) :: no_u
!f2py intent(out) :: H
!f2py intent(out) :: S

  integer :: ierr

  read(iu, iostat=ierr) !ik, iE, E
  call iostat_update(ierr)
  read(iu, iostat=ierr) H
  call iostat_update(ierr)
  read(iu, iostat=ierr) S
  call iostat_update(ierr)

end subroutine read_gf_hs

subroutine read_gf_se( iu, no_u, iE, SE )
  use io_m, only: iostat_update

  implicit none

  ! Precision 
  integer, parameter :: dp = selected_real_kind(p=15)

  ! Input parameters
  integer, intent(in) :: iu
  integer, intent(in) :: no_u
  integer, intent(in) :: iE
  complex(dp), intent(out) :: SE(no_u,no_u)

  ! Define f2py intents
!f2py intent(in) :: iu
!f2py intent(in) :: no_u
!f2py intent(in) :: iE
!f2py intent(out) :: SE

  integer :: ierr

  if ( iE > 0 ) then
    read(iu, iostat=ierr) !ik, iE, E
    call iostat_update(ierr)
  end if
  read(iu, iostat=ierr) SE
  call iostat_update(ierr)

end subroutine read_gf_se
