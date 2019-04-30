#!/bin/bash

nevents=1000
nthreads=1
vertex="0 0 50 80"
numrun=11366

function show_help
{
    cat <<EOF
Description:

Perform a test of the simulation and reconstruction chain for

    gamma p -> p X
                 X -> b1 pi-
                      b1 -> omega pi+
                            omega -> pi+ pi- pi0

Usage:

  b1pi_test.sh [-n <number of events>] [-t <number of threads>] [-r <run number>]\\
    [-v <vertex string>] [-d <b1pi_test script directory>]

Example:

  export B1PI_TEST_DIR /group/halld/Software/scripts/b1pi_test
  b1pi_test.sh -n 1000 -t 4 -v "0 0 50 80"
EOF
}

while getopts "h?v:f:n:t:d:r:s:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    f)  output_file=$OPTARG
        ;;
    n)  NEVENTS=$OPTARG
	;;
    v)  VERTEX=$OPTARG
	;;
    t)  NTHREADS=$OPTARG
	;;
    d)  B1PI_TEST_DIR=$OPTARG
	;;
    r)  RUN=$OPTARG
	;;
    s)  SEED=$OPTARG
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if [ ! -d "$B1PI_TEST_DIR" ]
    then
    echo "error: location of scripts and macros not found"
    echo "       location tried = \"$B1PI_TEST_DIR\""
    exit 1
fi

if [ -z "$NEVENTS" ]
    then
    echo "info: number of events not defined, using default value $nevents"
    NEVENTS=$nevents
fi

if [ -z "$NTHREADS" ]
    then
    echo "info: number of threads not defined, using default value $nthreads"
    NTHREADS=$nthreads
fi

if [ -z "$VERTEX" ]
    then
    echo "info: vertex parameters not defined, using default values $vertex"
    VERTEX=$vertex
fi

if [ -z "$RUN" ]
    then
    echo "info: run number not defined, using default values $numrun"
    RUN=$numrun
fi

if [ -z "$SEED" ]
    then
    echo "info: random number seed not defined, using genr8 default (different seed each run)"
    SEED_OPTION=""
else
    SEED_OPTION="-s${SEED}"
fi

echo NEVENTS = $NEVENTS
echo VERTEX = $VERTEX
echo NTHREADS = $NTHREADS
echo B1PI_TEST_DIR = $B1PI_TEST_DIR
echo RUN = $RUN
echo SEED = $SEED

export JANA_CALIB_CONTEXT="variation=mc"

echo "Copying script files and macros ..."
cp -pv $B1PI_TEST_DIR/* .
cp -pv $B1PI_TEST_DIR/macros/* .

echo "Running genr8 ..."
genr8 -r${RUN} -M${NEVENTS} -Ab1_pi.ascii ${SEED_OPTION} < b1_pi.input

echo "Converting generated events to HDDM ..."
genr8_2_hddm -V"${VERTEX}" b1_pi.ascii 

echo "Creating control.in file ..."
cat - << EOF > control.in

INFILE 'b1_pi.hddm'
TRIG ${NEVENTS}
OUTFILE 'hdgeant.hddm'
RNDM 123
HADR 1

EOF

echo "Running hdgeant ..."
command="hdgeant"
echo $command
$command

echo "Running mcsmear ..."
command="mcsmear -PJANA:BATCH_MODE=1 -PTHREAD_TIMEOUT=500 hdgeant.hddm"
echo $command
$command

echo "Running hd_root with danarest ..."
command="hd_root -PJANA:BATCH_MODE=1 --nthreads=$NTHREADS -PTHREAD_TIMEOUT=500 -PPLUGINS=danarest hdgeant_smeared.hddm"
echo $command
$command

echo "Running hd_root with b1pi_hists & monitoring_hists ..."
command="hd_root -PJANA:BATCH_MODE=1 --nthreads=$NTHREADS -PTHREAD_TIMEOUT=500 -PPLUGINS=b1pi_hists,monitoring_hists dana_rest.hddm"
echo $command
$command

echo "Create plots"
command="root -b -q mk_pics.C"
echo $command
$command

echo "Save test data"
command="python update_db.py"
echo $command
$command