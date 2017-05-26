module solver_params_mod
  use types_mod
  implicit none
  save

  real(kind=DP) :: atol, rtol
  integer(kind=SI) :: JvApprox
  real(kind=DP) :: deltaJv, deltaMain
  integer(kind=NPI) :: lookBack
  real(kind=DP) :: maxStep
  integer(kind=NPI) :: maxNumInternalSteps
  integer(kind=SI) :: solverType
  integer(kind=NPI) :: preconBandUpper, preconBandLower
  character(len=30) :: solverTypeName(3)

contains
  subroutine set_solver_parameters( input_parameters )
    use types_mod
    implicit none

    real(kind=DP) :: input_parameters(*)

    solverTypeName(1) = 'SPGMR'
    solverTypeName(2) = 'SPGMR + Banded Preconditioner'
    solverTypeName(3) = 'Dense'

    ! Used in FCVMALLOC(): ATOL is the absolute tolerance (scalar or array).
    atol = input_parameters(1)
    ! Used in FCVMALLOC(): RTOL is the relative tolerance (scalar).
    rtol = input_parameters(2)
    ! TODO: convert this to boolean?
    ! If JvApprox==1 and solverType={1,2}, call FCVSPILSSETJAC() below, with non-zero flag.
    ! This means FCVJTIMES() in solverFunctions.f90 should be used to approximate the Jacobian.
    JvApprox = nint( input_parameters(3), SI )
    ! This is never used, but is referenced in a comment in FCVJTIMES().
    ! TODO: delete?
    deltaJv = input_parameters(4)
    ! From CVODE docs: DELT is the linear convergence tolerance factor of the SPGMR. Used in FCVSPGMR().
    deltaMain = input_parameters(5)
    ! From CVODE docs: MAXL is the maximum Krylov subspace dimension. Used in FCVSPGMR().
    ! TODO: Rename to MAXL?
    lookBack = nint( input_parameters(6), NPI )
    ! From CVODE docs: Maximum absolute step size. Passed via FCVSETRIN().
    maxStep = input_parameters(7)
    ! From CVODE docs: Maximum no. of internal steps before tout. Passed via FCVSETIIN().
    maxNumInternalSteps = nint( input_parameters(8), NPI )
    ! USed to choose which solver to use:
    ! 1: SPGMR
    ! 2: SPGMR + Banded preconditioner
    ! 3: Dense solver
    ! otherwise: error
    solverType = nint( input_parameters(9), SI )
    ! From CVODE docs: MU (preconBandUpper) and ML (preconBandLower) are the upper
    ! and lower half- bandwidths of the band matrix that is retained as an
    ! approximation of the Jacobian.
    preconBandUpper = nint( input_parameters(10), NPI )
    preconBandLower = nint( input_parameters(11), NPI )

    ! float format
    100 format (A18, 1P E11.3)
    ! integer format
    200 format (A18, I11)
    write (*, '(A)') ' Solver parameters:'
    write (*, '(A)') ' ------------------'
    write (*, 100) 'atol: ', atol
    write (*, 100) 'rtol: ', rtol
    write (*, 200) 'JacVApprox: ', JvApprox
    write (*, 100) 'deltaJv: ', deltaJv
    write (*, 100) 'deltaMain: ', deltaMain
    write (*, 200) 'lookBack: ', lookBack
    write (*, 100) 'maxStep: ', maxStep
    write (*, 200) 'preconBandUpper: ', preconBandUpper
    write (*, 200) 'preconBandLower: ', preconBandLower
    write (*, '(A18, A)') 'solverType: ', adjustl( solverTypeName(solverType) )
    write (*, '(A)') ' ------------------'
    write (*,*)
  end subroutine set_solver_parameters
end module solver_params_mod


module model_params_mod
  use types_mod
  implicit none
  save

  integer(kind=NPI) :: maxNumTimesteps
  real(kind=DP) :: timestepSize
  integer(kind=SI) :: speciesInterpolationMethod, conditionsInterpolationMethod, decInterpolationMethod
  integer(kind=QI) :: ratesOutputStepSize
  real(kind=DP) :: modelStartTime
  integer(kind=QI) :: jacobianOutputStepSize
  integer(kind=QI) :: irOutStepSize
  character(len=20) :: interpolationMethodName(2)

contains
  subroutine set_model_parameters( input_parameters )
    use types_mod
    use constraints, only : maxNumberOfDataPoints
    use SZACalcVars, only : latitude, longitude
    use date, only : day, month, year
    use interpolationMethod, only : setSpeciesInterpMethod, setConditionsInterpMethod, setDecInterpMethod
    implicit none

    real(kind=DP) :: input_parameters(*)

    interpolationMethodName(1) = 'piecewise constant'
    interpolationMethodName(2) = 'piecewise linear'
    ! maxNumTimesteps sets the maximum number of timesteps to calculate.
    ! Calculation will terminate when currentNumTimestep>=maxNumTimesteps.
    maxNumTimesteps = nint( input_parameters(1), NPI )
    ! Size of timestep: tout is incremented by this amount on each iteration of the main while loop.
    timestepSize = input_parameters(2)
    ! Use the local variable speciesInterpolationMethod to set the value speciesInterpMethod,
    ! the private member of MODULE interpolationMethod.
    ! getSpeciesInterpMethod() is called by getConstrainedQuantAtT.
    ! Values:
    ! 1: Piecewise constant
    ! 2: Piecewise linear
    ! otherwise: error
    speciesInterpolationMethod = nint( input_parameters(3), SI )
    call setSpeciesInterpMethod( speciesInterpolationMethod )
    conditionsInterpolationMethod = nint( input_parameters(4), SI )
    call setConditionsInterpMethod( conditionsInterpolationMethod )
    decInterpolationMethod = nint( input_parameters(5), SI )
    call setDecInterpMethod( decInterpolationMethod )
    ! Member variable of MODULE constraints. Used in getConstrainedQuantAtT and readEnvVar
    maxNumberOfDataPoints = nint( input_parameters(6), NPI )
    ! Frequency at which outputRates is called below.
    ratesOutputStepSize = nint( input_parameters(7), QI )
    ! Start time of model. Used to set t initially, and to calculate the elapsed time.
    modelStartTime = input_parameters(8)
    ! Frequency at which output_jfy is called below.
    jacobianOutputStepSize = nint( input_parameters(9), QI )
    ! Member variables of module SZACalcVars
    latitude = input_parameters(10)
    longitude = input_parameters(11)
    ! Member variables of module date
    day = nint( input_parameters(12), SI )
    month = nint( input_parameters(13), SI )
    year = nint( input_parameters(14), DI )
    ! Frequency at which to output instantaneous rates
    irOutStepSize = nint( input_parameters(15), QI )

    ! float format
    300 format (A52, E11.3)
    ! integer format
    400 format (A52, I11)
    ! string format
    500 format (A52, A17)
    write (*, '(A)') ' Model parameters:'
    write (*, '(A)') ' -----------------'
    write (*, 400) 'number of steps: ', maxNumTimesteps
    write (*, 300) 'step size (seconds): ', timestepSize
    write (*, 500) 'species interpolation method: ', adjustl( interpolationMethodName(speciesInterpolationMethod) )
    write (*, 500) 'conditions interpolation method: ', adjustl( interpolationMethodName(conditionsInterpolationMethod) )
    write (*, 500) 'dec interpolation method: ', adjustl( interpolationMethodName(decInterpolationMethod) )
    write (*, 400) 'maximum number of data points in constraint file: ', maxNumberOfDataPoints
    write (*, 400) 'ratesOutputStepSize: ', ratesOutputStepSize
    write (*, 400) 'instantaneous rates output step size: ', irOutStepSize
    write (*, 300) 'modelStartTime: ', modelStartTime
    write (*, 400) 'jacobianOutputStepSize: ', jacobianOutputStepSize
    write (*, 300) 'latitude: ', latitude
    write (*, 300) 'longitude: ', longitude
    write (*, '(A52, I3, A, I2, A, I4) ') 'day/month/year: ', day, '/', month, '/', year
    write (*, '(A)') ' -----------------'
    write (*,*)
  end subroutine set_model_parameters
end module model_params_mod