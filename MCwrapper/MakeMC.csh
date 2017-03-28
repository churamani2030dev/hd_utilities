#!/bin/csh -f

# SET INPUTS
setenv ENVIRONMENT $1 
shift
setenv CONFIG_FILE $1
shift
setenv GEN_NAME $1
shift
setenv OUTDIR $1
shift
setenv RUN_NUMBER $1
shift
setenv FILE_NUMBER $1
shift
setenv EVT_TO_GEN $1
shift
setenv JANA_CALIB_CONTEXT "variation="$1
shift
setenv GENR $1
shift
setenv GEANT $1
shift
setenv SMEAR $1
shift
setenv RECON $1
shift
setenv CLEANGENR $1
shift
setenv CLEANGEANT $1
shift
setenv CLEANSMEAR $1
shift
setenv CLEANRECON $1
shift
setenv MCSWIF $1
shift
setenv NUMTHREADS $1
shift
setenv GENERATOR $1
shift
setenv GEANTVER $1
shift
setenv BKGFOLDSTR $1
shift
setenv CUSTOM_GCONTROL $1
shift
setenv eBEAM_ENERGY $1
shift
setenv COHERENT_PEAK $1
shift
setenv GEN_MIN_ENERGY $1
shift
setenv GEN_MAX_ENERGY $1

if ("$GEANTVER" == "3") then
setenv NUMTHREADS 1
endif

# PRINT INPUTS
echo "ENVIRONMENT       = $ENVIRONMENT"
echo "CONFIG_FILE       = $CONFIG_FILE"
echo "OUTDIR            = $OUTDIR"
echo "RUN_NUMBER        = $RUN_NUMBER"
echo "FILE_NUMBER       = $FILE_NUMBER"
echo "NUM TO GEN        = $EVT_TO_GEN"
echo "generator        = $GENERATOR"
echo "generation        = $GENR  $CLEANGENR"
echo "Geant        = $GEANT  $CLEANGEANT"
echo "GCONTROL        = $CUSTOM_GCONTROL"
echo "BKG_FOLD      = $BKGFOLDSTR"
echo "MCsmear        = $SMEAR $CLEANSMEAR"
echo "Recon        = $RECON   $CLEANRECON"

echo "detected c-shell"
#printenv
#necessary to run swif, uses local directory if swif=0 is used
if ("$MCSWIF" == "1") then
# ENVIRONMENT
echo $ENVIRONMENT
source $ENVIRONMENT
echo pwd = $PWD
mkdir -p $OUTDIR
mkdir -p $OUTDIR/log
endif

if ("$CUSTOM_GCONTROL" == "0" ) then
cp $MCWRAPPER_CENTRAL/Gcontrol.in ./
else
cp $CUSTOM_GCONTROL/Gcontrol.in ./
endif

if ("$GENR" != "0") then
    if ("$GENERATOR" != "genr8" && "$GENERATOR" != "bggen" && "$GENERATOR" != "genEtaRegge" && "$GENERATOR" != "gen_2pi_amp" && "$GENERATOR" != "gen_pi0" && "$GENERATOR" != "gen_2pi_primakoff" ) then
	echo "NO VALID GENERATOR GIVEN"
	echo "only [genr8, bggen, genEtaRegge, gen_2pi_amp, gen_pi0] are supported"
	exit
    endif

    if ( -f $CONFIG_FILE ) then
	    echo " input file found"
	else
	    echo $CONFIG_FILE" does not exist"
	    exit
    endif

    if ("$GENERATOR" == "genr8") then
	echo "configuring genr8"
	cp $CONFIG_FILE ./genr8\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
    else if ("$GENERATOR" == "bggen") then
	echo "configuring bggen"
	cp $MCWRAPPER_CENTRAL/Generators/bggen/particle.dat ./
	cp $MCWRAPPER_CENTRAL/Generators/bggen/pythia.dat ./
	cp $MCWRAPPER_CENTRAL/Generators/bggen/pythia-geant.map ./
	cp $CONFIG_FILE ./bggen\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	if ( `echo $eBEAM_ENERGY | grep -o "\." | wc -l` == 0) then
	    set eBEAM_ENERGY = $eBEAM_ENERGY\.
	endif
	if ( `echo $COHERENT_PEAK | grep -o "\." | wc -l` == 0) then
	    set COHERENT_PEAK = $COHERENT_PEAK\.
	endif
	if ( `echo $GEN_MIN_ENERGY | grep -o "\." | wc -l` == 0) then
	    set GEN_MIN_ENERGY = $GEN_MIN_ENERGY\.
	endif
	if ( `echo $GEN_MAX_ENERGY | grep -o "\." | wc -l` == 0) then
	    set GEN_MAX_ENERGY = $GEN_MAX_ENERGY\.
	endif
	
    else if ("$GENERATOR" == "genEtaRegge") then
	echo "configuring genEtaRegge"
	cp $CONFIG_FILE ./genEtaRegge\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
    else if ("$GENERATOR" == "gen_2pi_amp") then
	echo "configuring gen_2pi_amp"
	cp $CONFIG_FILE ./gen_2pi_amp\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
    else if ("$GENERATOR" == "gen_2pi_primakoff") then
	echo "configuring gen_2pi_primakoff"
	cp $CONFIG_FILE ./gen_2pi_primakoff\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
    else if ("$GENERATOR" == "gen_pi0") then
	echo "configuring gen_pi0"
	cp $CONFIG_FILE ./gen_pi0\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
    endif
    set config_file_name=`basename "$CONFIG_FILE"`
    echo $config_file_name
    
    if ("$GENERATOR" == "genr8") then
	echo "RUNNING GENR8"
	set RUNNUM = $RUN_NUMBER+$FILE_NUMBER
	sed -i 's/TEMPCOHERENT/'$COHERENT_PEAK'/' genr8\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	# RUN genr8 and convert
	genr8 -r$RUN_NUMBER -M$EVT_TO_GEN -A$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.ascii < genr8\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf #$config_file_name
	genr8_2_hddm $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.ascii
    else if ("$GENERATOR" == "bggen") then
	set colsize=`rcnd $RUN_NUMBER collimator_diameter | awk '{print $1}' | sed -r 's/.{2}$//' | sed -e 's/\.//g'`
	if ("$colsize" == "B" || "$colsize" == "R" ) then
	set colsize = "34"
	endif
	set RANDOM=$$
	echo $RANDOM
	sed -i 's/TEMPTRIG/'$EVT_TO_GEN'/' bggen\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	sed -i 's/TEMPRUNNO/'$RUN_NUMBER'/' bggen\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	sed -i 's/TEMPCOLD/'0.00$colsize'/' bggen\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	sed -i 's/TEMPRAND/'$RANDOM'/' bggen\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	sed -i 's/TEMPELECE/'$eBEAM_ENERGY'/' bggen\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	sed -i 's/TEMPCOHERENT/'$COHERENT_PEAK'/' bggen\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	sed -i 's/TEMPMINGENE/'$GEN_MIN_ENERGY'/' bggen\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	sed -i 's/TEMPMAXGENE/'$GEN_MAX_ENERGY'/' bggen\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	
	ln -s bggen\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf fort.15
	bggen
	mv bggen.hddm $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.hddm
        else if ("$GENERATOR" == "genEtaRegge") then
	echo "RUNNING GENETAREGGE" 
	set colsize=`rcnd $RUN_NUMBER collimator_diameter | awk '{print $1}' | sed -r 's/.{2}$//' | sed -e 's/\.//g'`
	if ("$colsize" == "B" || "$colsize" == "R" ) then
	set colsize = "34"
	endif
	sed -i 's/TEMPCOLD/'0.00$colsize'/' genEtaRegge\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	sed -i 's/TEMPELECE/'$eBEAM_ENERGY'/' genEtaRegge\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	sed -i 's/TEMPCOHERENT/'$COHERENT_PEAK'/' genEtaRegge\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	sed -i 's/TEMPMINGENE/'$GEN_MIN_ENERGY'/' genEtaRegge\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	sed -i 's/TEMPMAXGENE/'$GEN_MAX_ENERGY'/' genEtaRegge\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	genEtaRegge -N$EVT_TO_GEN -O$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.hddm -I'genEtaRegge'\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf
	else if ("$GENERATOR" == "gen_2pi_amp") then
	echo "RUNNING GEN_2PI_AMP" 
        set optionals_line = `head -n 1 $config_file_name | sed -r 's/.//'`
	echo $optionals_line
	echo gen_2pi_amp -c gen_2pi_amp\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf -o $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.hddm -hd $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.root -n $EVT_TO_GEN -r $RUN_NUMBER  -a $GEN_MIN_ENERGY -b $GEN_MAX_ENERGY $optionals_line
	gen_2pi_amp -c gen_2pi_amp\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf -hd $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.hddm -o $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.root -n $EVT_TO_GEN -r $RUN_NUMBER -a $GEN_MIN_ENERGY - b $GEN_MAX_ENERGY $optionals_line
	else if ("$GENERATOR" == "gen_2pi_primakoff") then
	echo "RUNNING GEN_2PI_PRIMAKOFF" 
        set optionals_line = `head -n 1 $config_file_name | sed -r 's/.//'`
	echo $optionals_line
	echo gen_2pi_primakoff -c gen_2pi_primakoff\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf -o $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.hddm -hd $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.root -n $EVT_TO_GEN -r $RUN_NUMBER  -a $GEN_MIN_ENERGY -b $GEN_MAX_ENERGY $optionals_line
	gen_2pi_primakoff -c gen_2pi_primakoff\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf -hd $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.hddm -o $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.root -n $EVT_TO_GEN -r $RUN_NUMBER -a $GEN_MIN_ENERGY - b $GEN_MAX_ENERGY $optionals_line
	else if ("$GENERATOR" == "gen_pi0") then
	echo "RUNNING GEN_PI0" 
        set optionals_line = `head -n 1 $config_file_name | sed -r 's/.//'`
	echo $optionals_line
	gen_pi0 -c gen_pi0\_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.conf -hd $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.hddm -o $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.root -n $EVT_TO_GEN -r $RUN_NUMBER -a $GEN_MIN_ENERGY -b $GEN_MAX_ENERGY -p $COHERENT_PEAK  -s $FILE_NUMBER $optionals_line -m $eBEAM_ENERGY
    endif

#GEANT/smearing
#modify TEMPIN/TEMPOUT/TEMPTRIG/TOSMEAR in control.in

    if ("$GEANT" != "0") then
	echo "RUNNING GEANT"$GEANTVER
	set colsize=`rcnd $RUN_NUMBER collimator_diameter | awk '{print $1}' | sed -r 's/.{2}$//' | sed -e 's/\.//g'`
	if ("$colsize" == "B" || "$colsize" == "R" ) then
	set colsize = "34"
	endif

	if ( `echo $eBEAM_ENERGY | grep -o "\." | wc -l` == 0) then
	    set eBEAM_ENERGY = $eBEAM_ENERGY\.
	endif
	if ( `echo $COHERENT_PEAK | grep -o "\." | wc -l` == 0) then
	    set COHERENT_PEAK = $COHERENT_PEAK\.
	endif

	set inputfile=$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER
	cp Gcontrol.in $PWD/control'_'$RUN_NUMBER'_'$FILE_NUMBER.in
	sed -i 's/TEMPELECE/'$eBEAM_ENERGY'/' control'_'$RUN_NUMBER'_'$FILE_NUMBER.in
	sed -i 's/TEMPCOHERENT/'$COHERENT_PEAK'/' control'_'$RUN_NUMBER'_'$FILE_NUMBER.in
	sed -i 's/TEMPIN/'$inputfile.hddm'/' control'_'$RUN_NUMBER'_'$FILE_NUMBER.in
	sed -i 's/TEMPRUNG/'$RUN_NUMBER'/' control'_'$RUN_NUMBER'_'$FILE_NUMBER.in
	sed -i 's/TEMPOUT/'$inputfile'_geant.hddm/' control'_'$RUN_NUMBER'_'$FILE_NUMBER.in
	sed -i 's/TEMPTRIG/'$EVT_TO_GEN'/' control'_'$RUN_NUMBER'_'$FILE_NUMBER.in
	#sed -i 's/TOSMEAR/'$SMEAR'/' control'_'$RUN_NUMBER'_'$FILE_NUMBER.in
	sed -i 's/TEMPCOLD/'0.00$colsize'/' control'_'$RUN_NUMBER'_'$FILE_NUMBER.in
	mv $PWD/control'_'$RUN_NUMBER'_'$FILE_NUMBER.in $PWD/control.in
	
	if ("$GEANTVER" == "3") then
	hdgeant 
	else if ("$GEANTVER" == "4") then
	#make run.mac then call it below
	rm run.mac
	echo /run/beamOn $EVT_TO_GEN >> run.mac
	echo "exit" >> run.mac
	hdgeant4 -t$NUMTHREADS run.mac
	rm run.mac
	else
	echo "INVALID GEANT VERSION"
	exit
	endif
	
	if ("$SMEAR" != "0") then
	    echo "RUNNING MCSMEAR"
	    
	    if ("$BKGFOLDSTR" == "0") then
	    mcsmear -o$inputfile'_geant_smeared.hddm' $inputfile'_geant.hddm'
	    else
	    echo 'mcsmear -o'$inputfile'_geant_smeared.hddm'' '$inputfile'_geant.hddm'' '$BKGFOLDSTR
	    mcsmear -o$inputfile'_geant_smeared.hddm' $inputfile'_geant.hddm' $BKGFOLDSTR
	    endif
	    #run reconstruction
	    if ("$CLEANGENR" == "1") then
		if ("$GENERATOR" == "genr8") then
		    rm *.ascii
		else if ("$GENERATOR" == "bggen") then
		    rm particle.dat
		    rm pythia.dat
		    rm pythia-geant.map
		    unlink fort.15
		endif
		
		rm $GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.hddm
	    endif
	    
	    if ("$RECON" != "0") then
		echo "RUNNING RECONSTRUCTION"
		hd_root $inputfile'_geant_smeared.hddm' -PPLUGINS=danarest,monitoring_hists -PNTHREADS=$NUMTHREADS
		mv hd_root.root hd_root_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.root
		mv dana_rest.hddm dana_rest_$GEN_NAME\_$RUN_NUMBER\_$FILE_NUMBER.hddm
		
		if ("$CLEANGEANT" == "1") then
		rm *_geant.hddm
		    if("$PWD" != "$MCWRAPPER_CENTRAL")
			rm Gcontrol.in	
		    endif
		endif
		
		if ("$CLEANSMEAR" == "1") then
		rm *_smeared.hddm
		rm smear.root
		endif
		
		if ("$CLEANRECON" == "1") then
		rm dana_rest*
		endif
	    endif
	endif
    endif
endif

if (! -d "$OUTDIR" ) then
    mkdir $OUTDIR
endif
if (! -d "$OUTDIR/configurations/" ) then
    mkdir $OUTDIR/configurations/
endif
if (! -d "$OUTDIR/hddm/" ) then
    mkdir $OUTDIR/hddm/
endif
if (! -d "$OUTDIR/root/" ) then
    mkdir $OUTDIR/root/
endif
    mv $PWD/*.conf $OUTDIR/configurations/
    mv $PWD/*.hddm $OUTDIR/hddm/
    mv $PWD/*.root $OUTDIR/root/
