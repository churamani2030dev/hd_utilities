#!/bin/bash -f

############################################################# SETUP #############################################################

Setup_Script()
{
	# PWD, STATUS OF MOUNTED DISKS
	echo "pwd =" $PWD
	echo "df -h:"
	df -h

	# ENVIRONMENT
	source $ENVIRONMENT
	printenv
	echo "PERL INCLUDES: "
	perl -e "print qq(@INC)"

	# COPY INPUT FILE TO WORKING DIRECTORY
	# This step is necessary since the cache files will be created as soft links in the current directory, and we want to avoid large I/O processes.
	# We first copy the input file to the current directory, then remove the link.
	echo "LOCAL FILES PRIOR TO INPUT COPY"
	ls -l
	cp $INPUTFILE ./tmp_file
	rm -f $INPUTFILE
	mv tmp_file $INPUTFILE
	echo "LOCAL FILES AFTER INPUT COPY"
	ls -l
}

####################################################### UTILITY FUNCTIONS #######################################################

Extract_SkimName()
{
	# to extract the skim name, first extract the locations of the last two periods in the file name
	local LAST_INDEX=0
	local SECOND_TO_LAST_INDEX=0
	local INPUT_FILE=$1
	for INDEX in `echo $INPUT_FILE | grep -bo '\.' | awk 'BEGIN {FS=":"}{print $1}'`; do
		SECOND_TO_LAST_INDEX=$LAST_INDEX
		LAST_INDEX=$INDEX
	done

	# extract the skim name: awk & grep use different location #'ing, so must convert
	local LENGTH=$[$LAST_INDEX - $SECOND_TO_LAST_INDEX - 1]
	local START=$[$SECOND_TO_LAST_INDEX + 2]
	local SKIM_NAME=`echo $INPUT_FILE | awk -v size="$LENGTH" -v start="$START" '{print substr($0,start,size)}'`
	echo "SKIM_NAME:" $SKIM_NAME
	
	#return the result "by reference"
	local __result=$2
	eval $__result="'$SKIM_NAME'"
}

Extract_BaseName()
{
	# base name is everything before the last period
	local INPUT_FILE=$1
	local LENGTH=`echo $INPUT_FILE | awk '{print index($0,".")}'`
	let LENGTH-=1
	local BASE_NAME=`echo $INPUT_FILE | awk -v size="$LENGTH" '{print substr($0,1,size)}'`
	echo "BASE_NAME: " $BASE_NAME

	#return the result "by reference"
	local __result=$2
	eval $__result="'$BASE_NAME'"
}

####################################################### SAVE OUTPUT FILES #######################################################

Save_OutputFiles()
{
	# SEE WHAT FILES ARE PRESENT
	echo "FILES PRESENT PRIOR TO SAVE:"
	ls -l

	# REMOVE INPUT FILE: so that it's easier to determine which remaining files are skims
	rm -f $INPUTFILE

	# BUILD TAPEDIR, IF $OUTDIR_LARGE STARTS WITH "/cache/"  
	# If so, output files are pinned & jput.  If not, then they aren't. 
	local TAPEDIR=""
	local OUTDIR_LARGE_BASE=`echo $OUTDIR_LARGE | awk '{print substr($0,1,7)}'`
	# first strip /cache/, then insert /mss/
	if [ "$OUTDIR_LARGE_BASE" == "/cache/" ]; then
		local OUTPATH=`echo $OUTDIR_LARGE | awk '{print substr($0,8)}'`
		TAPEDIR=/mss/${OUTPATH}/
	fi

	# CALL SAVE FUNCTIONS
	Save_Histograms
	Save_REST
	Save_JANADot
	Save_EVIOSkims
	Save_HDDMSkims
	Save_ROOTFiles
	Save_IDXA

	# SEE WHAT FILES ARE LEFT
	echo "FILES REMAINING AFTER SAVING:"
	ls -l
}

Save_Histograms()
{
	# SAVE ROOT HISTOGRAMS
	if [ -e hd_root.root ]; then
		echo "Saving histogram file"

		# setup output dirs
		local OUTDIR_THIS=${OUTDIR_LARGE}/hists/${RUN_NUMBER}/
		local TAPEDIR_THIS=${TAPEDIR}/hists/${RUN_NUMBER}/
		mkdir -p -m 775 ${OUTDIR_THIS}

		# save it
		local OUTPUT_FILE=${OUTDIR_THIS}/hd_root_${RUN_NUMBER}_${FILE_NUMBER}.root
		mv -v hd_root.root $OUTPUT_FILE
		chmod 664 $OUTPUT_FILE

		# force save to tape & pin
		if [ "$TAPEDIR" != "" ]; then
			jcache pin $OUTPUT_FILE -D $CACHE_PIN_DAYS
			echo jput $OUTPUT_FILE $TAPEDIR_THIS/
		fi
	fi
}

Save_REST()
{
	# SAVE REST FILE
	if [ -e dana_rest.hddm ]; then
		echo "Saving REST file"

		# setup output dirs
		local OUTDIR_THIS=${OUTDIR_LARGE}/REST/${RUN_NUMBER}/
		local TAPEDIR_THIS=${TAPEDIR}/REST/${RUN_NUMBER}/
		mkdir -p -m 775 $OUTDIR_THIS

		# save it
		local OUTPUT_FILE=${OUTDIR_THIS}/dana_rest_${RUN_NUMBER}_${FILE_NUMBER}.hddm
		mv -v dana_rest.hddm $OUTPUT_FILE
		chmod 664 $OUTPUT_FILE

		# force save to tape & pin
		if [ "$TAPEDIR" != "" ]; then
			jcache pin $OUTPUT_FILE -D $CACHE_PIN_DAYS
			echo jput $OUTPUT_FILE $TAPEDIR_THIS/
		fi
	fi
}

Save_JANADot()
{
	# SAVE JANADOT FILE
	if [ -e jana.dot ]; then
		echo "Saving JANADOT file"
		dot -Tps2 jana.dot -o jana.ps
		ps2pdf jana.ps

		# setup output dir
		local OUTDIR_THIS=${OUTDIR_SMALL}/log/${RUN_NUMBER}/
		mkdir -p -m 775 $OUTDIR_THIS

		# save it
		local OUTPUT_FILE=${OUTDIR_THIS}/janadot_${RUN_NUMBER}_${FILE_NUMBER}.pdf
		mv -v jana.pdf $OUTPUT_FILE
		chmod 664 $OUTPUT_FILE
	fi
}

Save_EVIOSkims()
{
	# SAVE EVIO SKIMS
	echo "Saving EVIO skim files (if any)"
	for EVIO_FILE in `find . -type -f -name "*.evio"`; do
		Extract_SkimName $EVIO_FILE SKIM_NAME

		# setup output dir
		local OUTDIR_THIS=${OUTDIR_LARGE}/${SKIM_NAME}/${RUN_NUMBER}/
		local TAPEDIR_THIS=${TAPEDIR}/${SKIM_NAME}/${RUN_NUMBER}/
		mkdir -p -m 775 $OUTDIR_THIS

		# save it
		local OUTPUT_FILE=${OUTDIR_THIS}/${EVIO_FILE}
		mv -v $EVIO_FILE $OUTPUT_FILE
		chmod 664 $OUTPUT_FILE

		# force save to tape & pin
		if [ "$TAPEDIR" != "" ]; then
			jcache pin $OUTPUT_FILE -D $CACHE_PIN_DAYS
			echo jput $OUTPUT_FILE $TAPEDIR_THIS/
		fi
	done
}

Save_HDDMSkims()
{
	# SAVE HDDM SKIMS #assumes REST file already backed up and removed!
	echo "Saving HDDM skim files (if any)"
	for HDDM_FILE in `find . -type -f -name "*.hddm"`; do
		Extract_SkimName $HDDM_FILE SKIM_NAME

		# setup output dir
		local OUTDIR_THIS=${OUTDIR_LARGE}/${SKIM_NAME}/${RUN_NUMBER}/
		local TAPEDIR_THIS=${TAPEDIR}/${SKIM_NAME}/${RUN_NUMBER}/
		mkdir -p -m 775 $OUTDIR_THIS

		# save it
		local OUTPUT_FILE=${OUTDIR_THIS}/${HDDM_FILE}
		mv -v $HDDM_FILE $OUTPUT_FILE
		chmod 664 $OUTPUT_FILE

		# force save to tape & pin
		if [ "$TAPEDIR" != "" ]; then
			jcache pin $OUTPUT_FILE -D $CACHE_PIN_DAYS
			echo jput $OUTPUT_FILE $TAPEDIR_THIS/
		fi
	done
}

Save_ROOTFiles()
{
	# SAVE OTHER ROOT FILES
	echo "Saving other ROOT files (if any)"
	for ROOT_FILE in `find . -type -f -name "*.root"`; do
		Extract_BaseName $ROOT_FILE BASE_NAME

		# setup output dir
		local OUTDIR_THIS=${OUTDIR_LARGE}/${BASE_NAME}/${RUN_NUMBER}/
		local TAPEDIR_THIS=${TAPEDIR}/${BASE_NAME}/${RUN_NUMBER}/
		mkdir -p -m 775 $OUTDIR_THIS

		# save it
		local OUTPUT_FILE=${OUTDIR_THIS}/${BASE_NAME}_${RUN_NUMBER}_${FILE_NUMBER}.root
		mv -v $ROOT_FILE $OUTPUT_FILE
		chmod 664 $OUTPUT_FILE

		# force save to tape & pin
		if [ "$TAPEDIR" != "" ]; then
			jcache pin $OUTPUT_FILE -D $CACHE_PIN_DAYS
			echo jput $OUTPUT_FILE $TAPEDIR_THIS/
		fi
	done
}

Save_IDXA()
{
	# SAVE IDXA FILES
	echo "Saving IDXA files (if any)"
	for IDXA_FILE in `find . -type -f -name "*.idxa"`; do
		Extract_BaseName $IDXA_FILE BASE_NAME

		# setup output dir
		local OUTDIR_THIS=${OUTDIR_SMALL}/IDXA/${RUN_NUMBER}/
		mkdir -p -m 775 $OUTDIR_THIS

		# save it
		local OUTPUT_FILE=${OUTDIR_THIS}/${BASE_NAME}_${RUN_NUMBER}_${FILE_NUMBER}.idxa
		mv -v $IDXA_FILE $OUTPUT_FILE
		chmod 664 $OUTPUT_FILE
	done
}

########################################################## MAIN FUNCTION ########################################################

Run_Script()
{
	Setup_Script

	# RUN JANA
	hd_root $INPUTFILE --config=$CONFIG_FILE

	# RETURN CODE
	RETURN_CODE=$?
	echo "Return Code = " $RETURN_CODE
	if [ $RETURN_CODE -ne 0 ]; then
		exit $RETURN_CODE
	fi

	# SAVE OUTPUTS
	Save_OutputFiles
}

######################################################### EXECUTE SCRIPT ########################################################

# SET INPUTS
ENVIRONMENT=$1
INPUTFILE=$2
CONFIG_FILE=$3
OUTDIR_LARGE=$4
OUTDIR_SMALL=$5
RUN_NUMBER=$6
FILE_NUMBER=$7
CACHE_PIN_DAYS=$8

# PRINT INPUTS
echo "ENVIRONMENT       = $ENVIRONMENT"
echo "INPUTFILE         = $INPUTFILE"
echo "CONFIG_FILE       = $CONFIG_FILE"
echo "OUTDIR_LARGE      = $OUTDIR_LARGE"
echo "OUTDIR_SMALL      = $OUTDIR_SMALL"
echo "RUN_NUMBER        = $RUN_NUMBER"
echo "FILE_NUMBER       = $FILE_NUMBER"
echo "CACHE_PIN_DAYS    = $CACHE_PIN_DAYS"

# RUN
Run_Script

