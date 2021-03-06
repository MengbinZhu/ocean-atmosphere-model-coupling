#define GMCF_VERBOSE
#define MODEL_API
! This is the ocean model
! Ocean model: Delta t = 480 min
! Ocean is more fine-grained than Atmosphere
! => In ocean I must interpolate the Atmosphere values
! What the ocean model receives from the atmosphere model is, I assume, either (u,v,w) at the surface, or p at the surface, not sure which

! test 1: basic functionality
!
!# An example of case 1:
!
!def f1(v1,v2):
!    return v1+v2/2
!
!def f2(v1,v2):
!    return v1-2*v2
!
!v1=2
!v2=2
!for t in range(0,10):
!    v1r = v1
!    v2r = v2
!    v1 = f1(v1, v2r)
!    v2 = f2(v2, v1r)
!    print(v1,v2)


subroutine program_ocean_gmcf(sys, tile, model_id) ! This replaces 'program main'


    ! Lines marked with ! gmcf-coupler / ! end gmcf-coupler are additions for coupling

    ! gmcf-coupler
    use gmcfAPI

    use gmcfAPIocean

    implicit none

    integer(8) , intent(In) :: sys
    integer(8) , intent(In) :: tile
    integer , intent(In) :: model_id
    integer :: n_ticks;
    ! end gmcf-coupler
    integer :: t,t_start,t_stop,t_step, ii, jj, kk
    integer :: can_interpolate ! should be LOGICAL

    real(kind=4) :: v1b, v1e, v2b, v2e
    real(kind=4), dimension(OCEAN_NX,OCEAN_NY) :: t_surface
    real(kind=4), dimension(OCEAN_NX,OCEAN_NY,OCEAN_KP) :: u,v,w

    real(4), parameter :: pi=3.1415926535
    real(4), parameter :: a1=16
    real(4), parameter :: omega1=pi/360
    real(4), parameter :: phi1=pi/4
    real(4), parameter :: eps1=5e-1
    ! Simulation start, stop, step for model 1
    t_start = 0
    t_stop = 1200 ! 720
    t_step = 1

!    t_sync_prev = -1 ! always
!    t_sync = t_start
!    t_sync_step = 20 !


    ! This flag is used to activate the interpolation functionality
    can_interpolate = 0

    ! gmcf-coupler
    ! Init amongst other things gathers info about the time loops, maybe from a config file, need to work this out in detail:
    call gmcfInitOcean(sys,tile,model_id)
    ! end gmcf-coupler

    print *, "FORTRAN OCEAN MODEL", model_id,"main routine called with pointers",sys,tile

    ! Set initial values
     u=0.0
     v=0.0
     w=0.0
     t_surface = 2.0
        print *, "FORTRAN OCEAN MODEL", model_id,"WORK INIT DONE:",sum(u),sum(t_surface)
    do t = t_start,t_stop,t_step
        print *, "FORTRAN OCEAN MODEL", model_id," syncing for time step ",t,"..."
        ! gmcf-coupler
        ! Sync all models by requesting all timesteps, block until all received, and sending your timestep to all who ask, until everyone has asked?
        ! Is this possible? I think it is OK:
        ! Start by sending N-1 requests; read from the FIFO,
        ! block if there is nothing there.
        ! You'll get requests and/or data. For every request, send data; keep going until you've sent data to all and received data from all.
        ! I don't think this will deadlock.
        n_ticks = (t-t_start)/t_step
        call gmcfSyncOcean(n_ticks)
        ! We are getting u,v,w from the atmosphere via wind_profile
        ! So this call should get the correct values for use in the subsequent calculations
        ! We are also sending the temperature (t_surface) to the atmosphere
        ! So this call should take temperature as an argument as well.
        call gmcfPreOcean(u,v,w, t_surface)
        ! end gmcf-coupler
#if TEST==1
        !v1 = v1+v2/200
        v1b=t_surface(2,2) + u(2,2,1)/200.0
        if (mod(t,72)==0) then
             print 7188, model_id, v1b,t_surface(2,2),u(2,2,1)
        end if
         7188 format("FORTRAN MODEL ",i1, " v1b = ",f8.1,' = (',f8.1,' + ',f8.1,' / 200 )')
        t_surface(2,2)=v1b

        v1e=t_surface(OCEAN_NX,OCEAN_NY) + u(OCEAN_NX,OCEAN_NY,1)/200.0
         print 7189, model_id, v1e,t_surface(OCEAN_NX,OCEAN_NY),u(OCEAN_NX,OCEAN_NY,1)
         7189 format("FORTRAN MODEL ",i1, " v1e = ",f8.1,' = (',f8.1,' + ',f8.1,' / 200 )')
        t_surface(OCEAN_NX,OCEAN_NY)=v1e
        t_surface = v1b
#endif
        v2b = u(2,2,1)
        v1b= a1*sin(omega1*(t*GMCF_TIME_STEP_OCEAN+GMCF_TIME_OFFSET_OCEAN)+phi1)+eps1*v2b
        t_surface = v1b

         print 7188,  (t*GMCF_TIME_STEP_OCEAN+GMCF_TIME_OFFSET_OCEAN),v1b,v2b
         7188 format('OCEAN:    ',i4,'    ',f8.1,'    ',f8.1)

#if 0
        ! WV: Another complication is that we might need to interpolate the received values.
        ! WV: This will always be the case if the consumer time step is smaller than the producer
        ! WV: And we know this from the configuration.
        ! WV: So a guard should be generated around the computation.

        if (can_interpolate == 0) then
            can_interpolate = 1
        else
            ! And now we can do work on this data
            ! WV: I would prefer to introduce a copy step with the interpolated values, but that is yet another copy ...
            ! WV: In fact, the current full-size copy in the gmcffloatarrayfromptrc_ function should be removed!
            ! WV: And then we could do
            v1sum=0.0
            v2sum=0.0
            do ii=1,128
                v1sum = v1sum + (var_name_1_prev(ii)*t_inter + var_name_1(ii)*(t_sync_step-t_inter) )/t_sync_step
                do jj=1,128
                    do kk=1,128
                        v2sum = v2sum + ( var_name_2_prev(ii,jj,kk)*t_inter +var_name_2(ii,jj,kk)*(t_sync_step-t_inter) )/t_sync_step
                    end do
                end do
            end do
            print *, "FORTRAN OCEAN MODEL", model_id,"WORK DONE:",v1sum,v2sum
        end if
#endif
    end do ! time loop model 1
    call gmcfFinished(model_id)
    print *, "FORTRAN OCEAN MODEL", model_id,"main routine finished after ",t_stop - t_start," time steps"

end subroutine program_ocean_gmcf

