#define GMCF_VERBOSE
#define MODEL_API
! This is the producer of a producer/consumer coupled model example.
! Atmosphere model: Delta t = 20 min
! Coupling period is 10 days (and at t=0 no coupling) = 10*24*60 min
! i.e. the atmosphere model takes 24 steps for 1 step of the ocean model
! and we couple every 10 days
! * Ocean is more fine-grained than Atmosphere
! => In atmosphere I must sample the ocean values
! What the atmosphere model receives from the ocean model is, I assume, T at the surface
! In practice, the ocean will be a larger array, and I interpolate over a portion of that.
! But we can start with two arrays of the same size.
! Let's assume we exchange the wind speed
subroutine program_atmosphere_gmcf(sys, tile, model_id) ! This replaces 'program main'

! Lines marked with ! gmcf-coupler / ! end gmcf-coupler are additions for coupling

! gmcf-coupler
    use gmcfAPI

    use gmcfAPIatmosphere

    implicit none

    integer(8) , intent(In) :: sys
    integer(8) , intent(In) :: tile
    integer , intent(In) :: model_id
    integer :: n_ticks
! end gmcf-coupler
    integer :: t,t_start,t_stop,t_step, ii, jj, kk
!    integer, parameter :: ATMOSPHERE_IP=48,ATMOSPHERE_JP=48,ATMOSPHERE_KP=27

    real(kind=4), dimension(ATMOSPHERE_IP,ATMOSPHERE_JP) :: t_surface
    real(kind=4), dimension(ATMOSPHERE_IP,ATMOSPHERE_JP,ATMOSPHERE_KP) :: u,v,w
    real(kind=4) :: v2
!    real(kind=4), dimension(128) :: var_name_1
!    real(kind=4), dimension(128,128,128) :: var_name_2

    ! Simulation start, stop, step for model 2
    t_start=0
    t_stop = 11 ! Problem is, it does not finish because the other model has finished
    t_step = 1

    ! gmcf-coupler
    ! Init amongst other things gathers info about the time loops, maybe from a config file, need to work this out in detail:
    call gmcfInitAtmosphere(sys,tile, model_id)
    ! end gmcf-coupler

    print *, "FORTRAN ATMOSPHERE MODEL", model_id,"main routine called with pointers",sys,tile
        ! Compute initial
!        do ii=1,128
!            var_name_1(ii) = 0.0
!        do jj=1,128
!        do kk=1,128
!            var_name_2(ii,jj,kk) = 0.0
!        end do
!        end do
!        end do
!        var_name_1(1) = 55.7188
!        var_name_2(1,1,1) = 55.7188


    ! Set initial values
     u=2.0
     v=0.0
     w=0.0
     t_surface = 0.0

        print *, "FORTRAN ATMOSPHERE MODEL", model_id,"WORK INIT DONE:",sum(u),sum(t_surface)

    do t = t_start,t_stop,t_step
        print *, "FORTRAN ATMOSPHERE MODEL", model_id," syncing for time step ",t,"..."
        ! gmcf-coupler
        ! Sync all models by requesting all timesteps, block until all received, and sending your timestep to all who ask, until everyone has asked?
        ! Is this possible? I think it is OK:
        ! Start by sending N-1 requests; read from the FIFO,
        ! block if there is nothing there.
        ! You'll get requests and/or data. For every request, send data; keep going until you've sent data to all and received data from all.
        ! I don't think this will deadlock.

        ! Sync will synchronise simulation time steps but also handle any pending requests
        n_ticks = (t-t_start)/t_step
        call gmcfSyncAtmosphere(n_ticks) !, var_name_1, var_name_2)

        call gmcfPreAtmosphere(u,v,w, t_surface)
        ! end gmcf-coupler

!        v2 = v1-2*v2
         v2 = u(1,1,1) - 2 * t_surface(1,1)
!         print *, "FORTRAN MODEL", model_id," v2 = ",v2,' = (',u(1,1,1),'-',t_surface(1,1),'*2)'
         print 7188, model_id, v2,u(1,1,1),t_surface(1,1)
         7188 format("FORTRAN MODEL ",i1, " v2 = ",f8.1,' = (',f8.1,' - ',f8.1,' * 2 )')
         u(1,1,1)=v2

!        if (gmcfStatus(GMCF_OCEAN_ID) /= FIN) then
!        ! Compute
!        do ii=1,128
!            var_name_1(ii) = 1e-6*ii / (t_sync+1)
!            do jj=1,128
!                do kk=1,128
!                    var_name_2(ii,jj,kk) = sqrt(1.0*ii*jj*kk)/(t_sync+1)
!                end do
!            end do
!        end do
!        var_name_1(1) = 55.7188
!        var_name_2(1,1,1) = 55.7188
!        print *, "FORTRAN ATMOSPHERE MODEL", model_id,"WORK DONE:",sum(var_name_1),sum(var_name_2)
!        end if ! FIN

!        call gmcfPostAtmosphere(var_name_2)

    end do  ! time loop model 2
    call gmcfFinished(model_id)
    print *, "FORTRAN ATMOSPHERE MODEL", model_id,"main routine finished after ",t_stop - t_start," time steps"

end subroutine program_atmosphere_gmcf

