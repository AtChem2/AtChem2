module outputFunctions_mod
  use types_mod
contains
  subroutine ro2Sum( ro2, y )
    implicit none

    real(kind=DP) :: ro2
    real(kind=DP), intent(in) :: y(*)

    ro2 = 0.00e+00

    return
  end subroutine ro2Sum


  subroutine outputEnvVar( t )
    use envVars
    implicit none

    integer(kind=NPI) :: i
    real(kind=DP), intent(in) :: t

    if ( ro2 < 0 ) ro2 = 0.0
    write (52,*) t, (currentEnvVarValues(i), i = 1, numEnvVars), ro2

    return
  end subroutine outputEnvVar


  subroutine output_jfy( fy, t )
    implicit none

    real(kind=DP), intent(in) :: fy(:,:), t
    integer(kind=NPI) :: i, j

    if ( size( fy, 1 ) /= size( fy, 2 ) ) then
      stop "size( fy, 1 ) /= size( fy, 2 ) in output_jfy()."
    end if
    ! Loop over all elements of fy, and print to jacobian.output, prefixed by t
    do i = 1, size( fy, 1)
      write (55, '(100 (1x, e12.5)) ') t, (fy(i, j), j = 1, size( fy, 1))
    end do
    write (55,*) '---------------'

    return
  end subroutine output_jfy


  subroutine outputPhotolysisRates( photoRateNamesForHeader, t )
    use photolysisRates, only : nrOfPhotoRates, ck, j
    implicit none

    character(len=*), intent(in) :: photoRateNamesForHeader(:)
    real(kind=DP), intent(in) :: t
    integer(kind=NPI) :: i
    logical :: firstTime = .true.

    if ( firstTime .eqv. .true. ) then
      write (58, '(100a15) ') 't', (trim( photoRateNamesForHeader(ck(i)) ), i = 1, nrOfPhotoRates)
      firstTime = .false.
    end if
    write (58, '(100e15.5) ') t, (j(ck(i)), i = 1, nrOfPhotoRates)

    return
  end subroutine outputPhotolysisRates


  pure function getReaction( speciesNames, reactionNumber ) result ( reaction )
    ! Given a list speciesNames, and an integer reactionNumber, return reaction,
    ! a string containing the string representing that reaction.
    use reactionStructure
    use storage, only : maxSpecLength, maxReactionStringLength
    implicit none

    character(len=maxSpecLength) :: reactants(10), products(10)
    character(len=maxSpecLength), intent(in) :: speciesNames(*)
    integer(kind=NPI) :: i, numReactants, numProducts
    integer(kind=NPI), intent(in) :: reactionNumber
    character(len=maxReactionStringLength) :: reactantStr, productStr, reaction

    ! Loop over reactants, and copy the reactant name for any reactant used in
    ! reaction reactionNumber. use numReactants as a counter of the number of reactants.
    ! String these together with '+', and append a '='
    numReactants = 0
    do i = 1, lhs_size
      if ( clhs(1, i) == reactionNumber ) then
        numReactants = numReactants + 1
        reactants(numReactants) = speciesNames(clhs(2, i))
      end if
    end do

    reactantStr = ' '
    do i = 1, numReactants
      reactantStr = trim( adjustl( trim( reactantStr ) // trim( reactants(i) ) ) )
      if ( i < numReactants ) then
        reactantStr = trim( reactantStr ) // '+'
      end if
    end do
    reactantStr = trim( reactantStr ) // '='

    ! Loop over products, and copy the product name for any product created in
    ! reaction reactionNumber. use numProducts as a counter of the number of products.
    ! String these together with '+', and append this to reactantStr. Save the
    ! result in reaction, which is returned
    numProducts = 0
    do i = 1, rhs_size
      if ( crhs(1, i) == reactionNumber ) then
        numProducts = numProducts + 1
        products(numProducts) = speciesNames(crhs(2, i))
      end if
    end do

    productStr = ' '
    do i = 1, numProducts
      productStr = trim( adjustl( trim( productStr ) // trim( products(i) ) ) )
      if ( i < numProducts ) then
        productStr = trim( productStr ) // '+'
      end if
    end do

    reaction = trim( reactantStr ) // trim( productStr )

    return
  end function getReaction


  subroutine outputRates( r, arrayLen, t, p, flag )
    use reactionStructure
    use species, only : getSpeciesList
    use storage, only : maxSpecLength, maxReactionStringLength
    use, intrinsic :: iso_fortran_env, only : stderr => error_unit
    implicit none

    integer(kind=NPI), intent(in) :: r(:,:), arrayLen(:)
    real(kind=DP), intent(in) :: t, p(:)
    integer, intent(in) :: flag
    character(len=maxSpecLength), allocatable :: speciesNames(:)
    integer(kind=NPI) :: i, j, output_file_number
    character(len=maxReactionStringLength) :: reaction
    logical :: first_time = .true.

    if ( size( r, 1 ) /= size( arrayLen ) ) then
      stop "size( r, 1 ) /= size( arrayLen ) in outputRates()."
    end if
    ! Add headers at the first call
    if ( first_time .eqv. .true. ) then
      write (56,*) '          time speciesNumber speciesName reactionNumber           rate'
      write (60,*) '          time speciesNumber speciesName reactionNumber           rate'
      first_time = .false.
    end if

    speciesNames = getSpeciesList()

    ! Flag = 0 for loss, 1 for production
    select case ( flag )
      case ( 0 )
        output_file_number = 56
      case ( 1 )
        output_file_number = 60
      case default
        write (stderr,*) "Unexpected flag value to outputRates(). flag = ", flag
        stop
    end select

    do i = 1, size( arrayLen )
      if ( arrayLen(i) > size( r, 2 ) ) then
        write (stderr,*) "arrayLen(i) > size( r, 2 ) in outputRates(). i = ", i
        stop
      end if
      do j = 2, arrayLen(i)
        if ( r(i, j) /= -1 ) then
          reaction = getReaction( speciesNames, r(i, j) )
          write (output_file_number, '(e15.5, I14, A12, I15, e15.5, A40)') t, r(i, 1), trim( speciesNames(r(i, 1)) ), r(i, j), &
                                                                           p(r(i, j)), trim( reaction )
        end if
      end do
    end do

    return
  end subroutine outputRates


  subroutine outputInstantaneousRates( time )
    use reactionStructure
    use directories, only : instantaneousRates_dir
    use productionAndLossRates, only : ir
    use storage, only : maxFilepathLength
    use, intrinsic :: iso_fortran_env, only : stderr => error_unit
    implicit none

    integer(kind=QI), intent(in) :: time
    integer(kind=NPI) :: i
    character(len=maxFilepathLength+30) :: irfileLocation
    character(len=30) :: strTime

    write (strTime,*) time

    irfileLocation = trim( instantaneousRates_dir ) // '/' // adjustl( strTime )

    open (10, file=irfileLocation)
    do i = 1, size( ir )
      write (10,*) ir(i)
    end do
    close (10, status='keep')

    return
  end subroutine outputInstantaneousRates


  subroutine outputSpeciesOutputRequired( t, arrayOfConcs )
    ! Print each element of arrayOfConcs, with size arrayOfConcsSize.
    ! If any concentration is negative, then set it to zero before printing.
    implicit none

    real(kind=DP), intent(in) :: t
    real(kind=DP), intent(inout) :: arrayOfConcs(:)
    integer(kind=NPI) :: i

    do i = 1, size( arrayOfConcs )
      if ( arrayOfConcs(i) < 0.0 ) then
        arrayOfConcs(i) = 0d0
      end if
    end do
    write (50, '(100 (1x, e15.5e3)) ') t, (arrayOfConcs(i), i = 1, size( arrayOfConcs ))
    return
  end subroutine outputSpeciesOutputRequired


  subroutine outputFinalModelState( names, concentrations )
    ! This routine outputs speciesNames and speciesConcs to modelOutput/finalModelState.output
    use types_mod
    implicit none

    character(len=*), intent(in) :: names(:)
    real(kind=DP), intent(in) :: concentrations(:)
    integer(kind=NPI) :: species_counter

    if ( size( names ) /= size( concentrations ) ) then
      stop 'size( speciesName ) /= size( concentrations ) in outputFinalModelState().'
    end if
    do species_counter = 1, size( names )
      write (53,*) names(species_counter), concentrations(species_counter)
    end do

    return
  end subroutine outputFinalModelState
end module outputFunctions_mod
