#!/bin/bash

# SET INPUTS
export ENVIRONMENT=$1 
shift
export CONFIG_FILE=$1
shift
export OUTDIR=$1
shift
export RUN_NUMBER=$1
shift
export FILE_NUMBER=$1
shift
export EVT_TO_GEN=$1
shift
export JANA_CALIB_CONTEXT="variation="$1
shift
export GENR=$1
shift
export GEANT=$1
shift
export SMEAR=$1
shift
export RECON=$1
shift
export CLEANGENR=$1
shift
export CLEANGEANT=$1
shift
export CLEANSMEAR=$1
shift
export CLEANRECON=$1
shift
export MCSWIF=$1
shift
export NUMTHREADS=$1
shift
export GENERATOR=$1
shift
export GEANTVER=$1
shift
export BKGFOLDSTR=$1
shift
export CUSTOM_GCONTROL=$1
shift
export eBEAM_ENERGY=$1
shift
export COHERENT_PEAK=$1
shift
export GEN_MIN_ENERGY=$1
shift
export GEN_MAX_ENERGY=$1
shift
export TAGSTR=$1
shift
export CUSTOM_PLUGINS=$1
shift
export PER_FILE=$1

if [[ "$GEANTVER" == "3" ]]; then
    export NUMTHREADS=1
fi

# PRINT INPUTS
echo "CONTEXT           = $JANA_CALIB_CONTEXT"
echo "ENVIRONMENT       = $ENVIRONMENT"
echo "CONFIG_FILE       = $CONFIG_FILE"
echo "OUTDIR            = $OUTDIR"
echo "RUN_NUMBER        = $RUN_NUMBER"
echo "FILE_NUMBER       = $FILE_NUMBER"
echo "NUM TO GEN        = $EVT_TO_GEN"
echo "generator         = $GENERATOR"
echo "generation        = $GENR  $CLEANGENR"
echo "Geant             = $GEANT  $CLEANGEANT"
echo "GCONTROL          = $CUSTOM_GCONTROL"
echo "BKG_FOLD          = $BKGFOLDSTR"
echo "MCsmear           = $SMEAR   $CLEANSMEAR"
echo "Recon             = $RECON   $CLEANRECON"

echo "detected bash"

#printenv
#necessary to run swif, uses local directory if swif=0 is used
if [[ "$MCSWIF" == "1" ]]; then
    # ENVIRONMENT
    echo $ENVIRONMENT
    source $ENVIRONMENT
    echo pwd=$PWD
    mkdir -p $OUTDIR
    mkdir -p $OUTDIR/log
fi

if [[ "$CUSTOM_GCONTROL" == "0" ]]; then
    cp $MCWRAPPER_CENTRAL/Gcontrol.in ./temp_Gcontrol.in
    chmod 777 ./temp_Gcontrol.in
else
    cp $CUSTOM_GCONTROL/Gcontrol.in ./temp_Gcontrol.in
fi

length_count=$((`echo $RUN_NUMBER | wc -c` - 1))

formatted_runNumber=""
while [ $length_count -lt 6 ]; do
    formatted_runNumber="0""$formatted_runNumber"
    length_count=$(($length_count + 1))
done

formatted_runNumber=$formatted_runNumber$RUN_NUMBER
flength_count=$((`echo $FILE_NUMBER | wc -c` - 1))

formatted_fileNumber=""
while [ $flength_count -lt 3 ]; do
    formatted_fileNumber="0""$formatted_fileNumber"
    flength_count=$(($flength_count + 1))
done

formatted_fileNumber=$formatted_fileNumber$FILE_NUMBER

custom_tag=""

if [[ "$TAGSTR" != "I_dont_have_one" ]]; then
    custom_tag=$TAGSTR\_
fi

STANDARD_NAME=$custom_tag$formatted_runNumber\_$formatted_fileNumber

colsize=`rcnd $RUN_NUMBER collimator_diameter | awk '{print $1}' | sed -r 's/.{2}$//' | sed -e 's/\.//g'`
if [[ "$colsize" == "B" || "$colsize" == "R" || "$JANA_CALIB_CONTEXT" != "variation=mc" ]]; then
    colsize="50"
fi

if [[ `echo $eBEAM_ENERGY | grep -o "\." | wc -l` == 0 ]]; then
    eBEAM_ENERGY=$eBEAM_ENERGY\.
fi
if [[ `echo $COHERENT_PEAK | grep -o "\." | wc -l` == 0 ]]; then
    COHERENT_PEAK=$COHERENT_PEAK\.
fi
if [[ `echo $GEN_MIN_ENERGY | grep -o "\." | wc -l` == 0 ]]; then
    GEN_MIN_ENERGY=$GEN_MIN_ENERGY\.
fi
if [[ `echo $GEN_MAX_ENERGY | grep -o "\." | wc -l` == 0 ]]; then
    GEN_MAX_ENERGY=$GEN_MAX_ENERGY\.
fi

if [[ ! -d "$OUTDIR" ]]; then
    mkdir $OUTDIR
fi
if [[ ! -d "$OUTDIR/configurations/" ]]; then
    mkdir $OUTDIR/configurations/
fi
if [[ ! -d "$OUTDIR/hddm/" ]]; then
    mkdir $OUTDIR/hddm/
fi
if [[ ! -d "$OUTDIR/root/" ]]; then
    mkdir $OUTDIR/root/
fi

bkglocstring=""
if [[ "$BKGFOLDSTR" == "DEFAULT" ]]; then
		    #find file and run:1
		    echo "Finding the right file to fold in during MCsmear step"
		    runperiod="RunPeriod-2017-01"

		    if [[ $RUN_NUMBER > 40000 ]]; then
			echo
			#set runperiod="RunPeriod-2017-10"
		    fi

		    if [[ $RUN_NUMBER < 30000 ]]; then
			echo "Warning: random triggers did not exist by this point"
		    fi

		    bkglocstring="/cache/halld/""$runperiod""/sim/random_triggers/""run$formatted_runNumber""_random.hddm"
		    #set bkglocstring="/w/halld-scifs1a/home/tbritton/converted.hddm"
		    
		    if [[ ! -f $bkglocstring ]]; then
			echo "Could not find mix-in file "$bkglocstring
			exit
		    fi
fi


recon_pre=`echo $CUSTOM_PLUGINS | cut -c1-4`
jana_config_file=`echo $CUSTOM_PLUGINS | sed -r 's/^.{5}//'`

if [[ -f $jana_config_file ]]; then
echo "gathering jana config file"
cp $jana_config_file ./jana_config.cfg
fi

gen_pre=""

if [[ "$GENR" != "0" ]]; then
	gen_pre=`echo $GENERATOR | cut -c1-4`
    if [[ "$gen_pre" != "file" && "$GENERATOR" != "genr8" && "$GENERATOR" != "bggen" && "$GENERATOR" != "genEtaRegge" && "$GENERATOR" != "gen_2pi_amp" && "$GENERATOR" != "gen_pi0" && "$GENERATOR" != "gen_2pi_primakoff" && "$GENERATOR" != "gen_omega_3pi" ]]; then
	echo "NO VALID GENERATOR GIVEN"
	echo "only [genr8, bggen, genEtaRegge, gen_2pi_amp, gen_pi0, gen_omega_3pi] are supported"
	exit
    fi
    
	if [[ "$gen_pre" == "file" ]]; then
		gen_in_file=`echo $GENERATOR | sed -r 's/^.{5}//'`
		echo "bypassing generation"
		if [[ -f $gen_in_file ]]; then
			echo "using pre-generated file: "$gen_in_file
			cp $gen_in_file ./$STANDARD_NAME.hddm
		else
			echo "cannot find file: "$gen_in_file
			exit
		fi
				
	else 
		if [[ -f $CONFIG_FILE ]]; then
	    	echo "input file found"
		else
	    	echo $CONFIG_FILE" does not exist"
	    	exit
    	fi

	fi
    
    if [[ "$GENERATOR" == "genr8" ]]; then
	echo "configuring genr8"
	STANDARD_NAME="genr8_"$STANDARD_NAME
	cp $CONFIG_FILE ./$STANDARD_NAME.conf
    elif [[ "$GENERATOR" == "bggen" ]]; then
	echo "configuring bggen"
	STANDARD_NAME="bggen_"$STANDARD_NAME
	cp $MCWRAPPER_CENTRAL/Generators/bggen/particle.dat ./
	cp $MCWRAPPER_CENTRAL/Generators/bggen/pythia.dat ./
	cp $MCWRAPPER_CENTRAL/Generators/bggen/pythia-geant.map ./
	cp $CONFIG_FILE ./$STANDARD_NAME.conf
	
    elif [[ "$GENERATOR" == "genEtaRegge" ]]; then
	echo "configuring genEtaRegge"
	STANDARD_NAME="genEtaRegge_"$STANDARD_NAME
	cp $CONFIG_FILE ./$STANDARD_NAME.conf
    elif [[ "$GENERATOR" == "gen_2pi_amp" ]]; then
	echo "configuring gen_2pi_amp"
	STANDARD_NAME="gen_2pi_amp_"$STANDARD_NAME
	cp $CONFIG_FILE ./$STANDARD_NAME.conf
	elif [[ "$GENERATOR" == "gen_omega_3pi" ]]; then
	echo "configuring gen_omega_3pi"
	STANDARD_NAME="gen_omega_3pi_"$STANDARD_NAME
	cp $CONFIG_FILE ./$STANDARD_NAME.conf
    elif [[ "$GENERATOR" == "gen_2pi_primakoff" ]]; then
	echo "configuring gen_2pi_primakoff"
	STANDARD_NAME="gen_2pi_primakoff_"$STANDARD_NAME
	cp $CONFIG_FILE ./$STANDARD_NAME.conf
    elif [[ "$GENERATOR" == "gen_pi0" ]]; then
	echo "configuring gen_pi0"
	STANDARD_NAME="genr_pi0_"$STANDARD_NAME
	cp $CONFIG_FILE ./$STANDARD_NAME.conf
    fi
	
	if [[ "$gen_pre" != "file" ]]; then
    config_file_name=`basename "$CONFIG_FILE"`
    echo $config_file_name
    fi

    if [[ "$GENERATOR" == "genr8" ]]; then
	echo "RUNNING GENR8"
	RUNNUM=$formatted_runNumber+$formatted_fileNumber
	sed -i 's/TEMPCOHERENT/'$COHERENT_PEAK'/' $STANDARD_NAME.conf
	# RUN genr8 and convert
	genr8 -r$formatted_runNumber -M$EVT_TO_GEN -A$STANDARD_NAME.ascii < $STANDARD_NAME.conf #$config_file_name
	genr8_2_hddm $STANDARD_NAME.ascii
    elif [[ "$GENERATOR" == "bggen" ]]; then
	RANDOM=$$
	echo $RANDOM
	sed -i 's/TEMPTRIG/'$EVT_TO_GEN'/' $STANDARD_NAME.conf
	sed -i 's/TEMPRUNNO/'$RUN_NUMBER'/' $STANDARD_NAME.conf
	sed -i 's/TEMPCOLD/'0.00$colsize'/' $STANDARD_NAME.conf
	sed -i 's/TEMPRAND/'$RANDOM'/' $STANDARD_NAME.conf
	sed -i 's/TEMPELECE/'$eBEAM_ENERGY'/' $STANDARD_NAME.conf
	sed -i 's/TEMPCOHERENT/'$COHERENT_PEAK'/' $STANDARD_NAME.conf
	sed -i 's/TEMPMINGENE/'$GEN_MIN_ENERGY'/' $STANDARD_NAME.conf
	sed -i 's/TEMPMAXGENE/'$GEN_MAX_ENERGY'/' $STANDARD_NAME.conf
	
	ln -s $STANDARD_NAME.conf fort.15
	bggen
	mv bggen.hddm $STANDARD_NAME.hddm
    elif [[ "$GENERATOR" == "genEtaRegge" ]]; then
	echo "RUNNING GENETAREGGE" 
	
	sed -i 's/TEMPCOLD/'0.00$colsize'/' $STANDARD_NAME.conf
	sed -i 's/TEMPELECE/'$eBEAM_ENERGY'/' $STANDARD_NAME.conf
	sed -i 's/TEMPCOHERENT/'$COHERENT_PEAK'/' $STANDARD_NAME.conf
	sed -i 's/TEMPMINGENE/'$GEN_MIN_ENERGY'/' $STANDARD_NAME.conf
	sed -i 's/TEMPMAXGENE/'$GEN_MAX_ENERGY'/' $STANDARD_NAME.conf
	genEtaRegge -N$EVT_TO_GEN -O$STANDARD_NAME.hddm -I$STANDARD_NAME.conf
    elif [[ "$GENERATOR" == "gen_2pi_amp" ]]; then
	echo "RUNNING GEN_2PI_AMP" 
        optionals_line=`head -n 1 $STANDARD_NAME.conf | sed -r 's/.//'`
	echo $optionals_line
	echo gen_2pi_amp -c $STANDARD_NAME.conf -hd $STANDARD_NAME.hddm -o $STANDARD_NAME.root -n $EVT_TO_GEN -r $RUN_NUMBER  -a $GEN_MIN_ENERGY -b $GEN_MAX_ENERGY $optionals_line
	gen_2pi_amp -c $STANDARD_NAME.conf -hd $STANDARD_NAME.hddm -o $STANDARD_NAME.root -n $EVT_TO_GEN -r $RUN_NUMBER -a $GEN_MIN_ENERGY -b $GEN_MAX_ENERGY $optionals_line
	elif [[ "$GENERATOR" == "gen_omega_3pi" ]]; then
	echo "RUNNING GEN_OMEGA_3PI" 
        optionals_line=`head -n 1 $STANDARD_NAME.conf | sed -r 's/.//'`
	echo $optionals_line
	echo gen_omega_3pi -c $STANDARD_NAME.conf -hd $STANDARD_NAME.hddm -o $STANDARD_NAME.root -n $EVT_TO_GEN -r $RUN_NUMBER  -a $GEN_MIN_ENERGY -b $GEN_MAX_ENERGY $optionals_line
	gen_omega_3pi -c $STANDARD_NAME.conf -hd $STANDARD_NAME.hddm -o $STANDARD_NAME.root -n $EVT_TO_GEN -r $RUN_NUMBER -a $GEN_MIN_ENERGY -b $GEN_MAX_ENERGY $optionals_li
    elif [[ "$GENERATOR" == "gen_2pi_primakoff" ]]; then
	echo "RUNNING GEN_2PI_PRIMAKOFF" 
        optionals_line=`head -n 1 $STANDARD_NAME.conf | sed -r 's/.//'`
	echo $optionals_line
	echo gen_2pi_primakoff -c $STANDARD_NAME.conf -o  $STANDARD_NAME.hddm -hd  $STANDARD_NAME.root -n $EVT_TO_GEN -r $RUN_NUMBER  -a $GEN_MIN_ENERGY -b $GEN_MAX_ENERGY $optionals_line
	gen_2pi_primakoff -c $STANDARD_NAME.conf -hd  $STANDARD_NAME.hddm -o  $STANDARD_NAME.root -n $EVT_TO_GEN -r $RUN_NUMBER -a $GEN_MIN_ENERGY -b $GEN_MAX_ENERGY $optionals_line
    elif [[ "$GENERATOR" == "gen_pi0" ]]; then
	echo "RUNNING GEN_PI0" 
        optionals_line=`head -n 1 $STANDARD_NAME.conf | sed -r 's/.//'`
	echo $optionals_line
	gen_pi0 -c $STANDARD_NAME.conf -hd $STANDARD_NAME.hddm -o $STANDARD_NAME.root -n $EVT_TO_GEN -r $RUN_NUMBER -a $GEN_MIN_ENERGY -b $GEN_MAX_ENERGY -p $COHERENT_PEAK  -s $formatted_fileNumber $optionals_line -m $eBEAM_ENERGY
    fi
    
    #GEANT/smearing
    
    if [[ "$GEANT" != "0" ]]; then
	echo "RUNNING GEANT"$GEANTVER
	
	if [[ `echo $eBEAM_ENERGY | grep -o "\." | wc -l` == 0 ]]; then
	    eBEAM_ENERGY=$eBEAM_ENERGY\.
	fi
	if [[ `echo $COHERENT_PEAK | grep -o "\." | wc -l` == 0 ]]; then
	    COHERENT_PEAK=$COHERENT_PEAK\.
	fi
	
	cp temp_Gcontrol.in $PWD/control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	chmod 777 $PWD/control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	sed -i 's/TEMPELECE/'$eBEAM_ENERGY'/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	sed -i 's/TEMPCOHERENT/'$COHERENT_PEAK'/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	sed -i 's/TEMPIN/'$STANDARD_NAME.hddm'/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	sed -i 's/TEMPRUNG/'$RUN_NUMBER'/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	sed -i 's/TEMPOUT/'$STANDARD_NAME'_geant'$GEANTVER'.hddm/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	sed -i 's/TEMPTRIG/'$EVT_TO_GEN'/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	sed -i 's/TEMPCOLD/'0.00$colsize'/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in

	if [[ "$gen_pre" == "file" ]]; then
			skip_num=$((FILE_NUMBER * PER_FILE))
            sed -i 's/TEMPSKIP/'$skip_num'/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
        else
	    sed -i 's/TEMPSKIP/'0'/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
        fi
	
	if [[ "$BKGFOLDSTR" != "BeamPhotons" ]]; then
	    echo "removing Beam Photon background from geant simulation"
	    sed -i 's/BGRATE/cBGRATE/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	    sed -i 's/BGGATE/cBGGATE/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	    sed -i 's/TEMPMINE/'$GEN_MIN_ENERGY'/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	else
	    sed -i 's/TEMPMINE/0.0012/' control'_'$formatted_runNumber'_'$formatted_fileNumber.in
	fi
	
	mv $PWD/control'_'$formatted_runNumber'_'$formatted_fileNumber.in $PWD/control.in
	
	if [[ "$GEANTVER" == "3" ]]; then
	    hdgeant 
	elif [[ "$GEANTVER" == "4" ]]; then
	    #make run.mac then call it below
	    rm -f run.mac
	    echo "/run/beamOn $EVT_TO_GEN" > run.mac
	    echo "exit" >>! run.mac
	    hdgeant4 -t$NUMTHREADS run.mac
	    rm run.mac
	else
	    echo "INVALID GEANT VERSION"
	    exit
	fi
	
	if [[ "$SMEAR" != "0" ]]; then
	    echo "RUNNING MCSMEAR"
	    
	    if [[ "$BKGFOLDSTR" == "BeamPhotons" || "$BKGFOLDSTR" == "None" ]]; then
		echo "running MCsmear without folding in random background"
		mcsmear -o$STANDARD_NAME'_geant'$GEANTVER'_smeared.hddm' $STANDARD_NAME'_geant'$GEANTVER'.hddm'
	    elif [[ "$BKGFOLDSTR" == "DEFAULT" ]]; then
			echo "mcsmear -o$STANDARD_NAME"\_"geant$GEANTVER"\_"smeared.hddm $STANDARD_NAME"\_"geant$GEANTVER.hddm $bkglocstring"\:"1"
			mcsmear -o$STANDARD_NAME\_geant$GEANTVER\_smeared.hddm $STANDARD_NAME\_geant$GEANTVER.hddm $bkglocstring\:1
		else
		    #trust the user and use their string
		    echo 'mcsmear -o'$STANDARD_NAME'_geant'$GEANTVER'_smeared.hddm'' '$STANDARD_NAME'_geant'$GEANTVER'.hddm'' '$BKGFOLDSTR
		    mcsmear -o$STANDARD_NAME'_geant'$GEANTVER'_smeared.hddm' $STANDARD_NAME'_geant'$GEANTVER'.hddm' $BKGFOLDSTR

	    fi
	    #run reconstruction
	    if [[ "$CLEANGENR" == "1" ]]; then
		if [[ "$GENERATOR" == "genr8" ]]; then
		    rm *.ascii
		elif [[ "$GENERATOR" == "bggen" ]]; then
		    rm particle.dat
		    rm pythia.dat
		    rm pythia-geant.map
		    unlink fort.15
		fi
		
		rm $STANDARD_NAME.hddm
	    fi
	    
	    if [[ "$RECON" != "0" ]]; then
		echo "RUNNING RECONSTRUCTION"

		if [[ "$recon_pre" == "file" ]]; then
			echo "using config file: "$jana_config_file
			hd_root ./$STANDARD_NAME'_geant'$GEANTVER'_smeared.hddm' --config=jana_config.cfg -PNTHREADS=$NUMTHREADS
		else
		
			declare -a pluginlist=("danarest" "monitoring_hists")
			echo ${pluginlist[@]}
			echo $CUSTOM_PLUGINS
            if [[ "$CUSTOM_PLUGINS" != "None" ]]; then
				pluginlist=("${pluginlist[@]}" $CUSTOM_PLUGINS)
            fi
			echo ${pluginlist[@]}

			PluginStr=""
		
            for plugin in "${pluginlist[@]}"; do
				PluginStr="$PluginStr""$plugin"","
            done
		
			PluginStr=`echo $PluginStr | sed -r 's/.{1}$//'`
            echo "Running hd_root with:""$PluginStr"
			echo "hd_root ""$STANDARD_NAME"'_geant'"$GEANTVER"'_smeared.hddm'" -PPLUGINS=""$PluginStr ""-PNTHREADS=""$NUMTHREADS"
			hd_root ./$STANDARD_NAME'_geant'$GEANTVER'_smeared.hddm' -PPLUGINS=$PluginStr -PNTHREADS=$NUMTHREADS
		fi

		if [[ -f dana_rest.hddm ]]; then
                    mv dana_rest.hddm dana_rest_$STANDARD_NAME.hddm
                fi


		if [[ "$CLEANGEANT" == "1" ]]; then
		    rm *_geant$GEANTVER.hddm
		    rm control.in
		    rm -f geant.hbook
		    rm -f hdgeant.rz
		    if [[ "$PWD" != "$MCWRAPPER_CENTRAL" ]]; then
			rm temp_Gcontrol.in	
		    fi
		    
		fi
		
		if [[ "$CLEANSMEAR" == "1" ]]; then
		    rm *_smeared.hddm
		    rm smear.root
		fi
		
		if [[ "$CLEANRECON" == "1" ]]; then
		    rm dana_rest*
		fi
		
		rootfiles=$(ls *.root)
		filename_root=""
		for rootfile in $rootfiles; do
		    filename_root=`echo $rootfile | sed -r 's/.{5}$//'`
		    filetomv="$rootfile"
		    mv $filetomv $filename_root\_$STANDARD_NAME.root
		    mv $PWD/$filename_root\_$STANDARD_NAME.root $OUTDIR/root/
		done
	    fi
	fi
    fi
fi
if [[ "$gen_pre" != "file" ]]; then
	mv $PWD/*.conf $OUTDIR/configurations/
fi
hddmfiles=$(ls | grep .hddm)
if [[ "$hddmfiles" != "" ]]; then
	mv $PWD/*.hddm $OUTDIR/hddm/
fi
#mv $PWD/*.root $OUTDIR/root/ #just in case
