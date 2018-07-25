#!/usr/bin/env python
#
# Initial test script for sumbitting CORI/NERSC job via
# swif2. (This is actually at least the 3rd iteration used
# in initial testing of NERSC)
#
# This will run commands submitting several recon jobs
# with the run/file numbers hardcoded into this script.
# Here is how this is supposed to work:
#
# This will run swif2 with all of the SBATCH(slurm) options
# passed via command line. This includes the shifter image
# that should be used. swif2 will then take care of getting
# the file from tape and transferring it to NERSC. Once
# the file is there, it will submit the job to Cori.
#
# When the job wakes up, it will be in a subdirectory of the
# NERSC project directory that swif2 has already setup.
# This directory will contain a symbolic link pointing
# to the raw data file which is somewhere else in the project
# directory tree.
#
# The container will run the /launch/run_job_nersc.sh script
# where /launch has been mounted in the container from the
# "launch" directory in the project directory. The jana
# config file is also kept in the launch directory.
#
# The container will also have /cvmfs mounted. The standard
# gluex containers have links built in so that /group will
# point to the appropriate subdirectory of /cvmfs making the
# the GlueX software available. The run_job_nersc.sh script
# will use this to setup the environment and then run hd_root
# using the /launch/jana_recon.config file.
#
# A couple of more notes:
#
# 1. The CCDB and RCDB used comes from an sqlite file in
# CVMFS. These are copied to the local node in /tmp at
# the beginning of the job and deleted at the end. The
# timestamp used is built into the /launch/jana_recon.config
#
# 2. NERSC requires that the program being run is actually
# a script that starts with #!/XXX/YYY . Thus, the command
# we give to swif2 to run for the job is:
#
#       /launch/jana_recon.config
#
# which is a simple wrapper script to run the
# /launch/run_job_nersc.sh script using shifter
#
# 3. The output directory is created here
# to allow group writing since the files are copied using
# the davidl account on globus but swif2 is being run from
# the gxproj4 account.
#

import subprocess
import mysql.connector
import sys


WORKFLOW  = 'nersc_test_01'
NAME      = 'GLUEX_RECON'
PROJECT   = 'm3120'
MAXTIME   = '3:30:00'  # Set 3.5hr time limit
QOS       = 'regular'  # debug, regular, premium
NODETYPE  = 'haswell'  # haswell, knl  (quad,cache)
IMAGE     = 'docker:markito3/gluex_docker_devel'
CONFIG    = '/launch/jana_recon.config'
OUTPUTTOP = '/cache/halld/halld-scratch/RunPeriod-2018-01/recon/ver00'

RUNPERIOD = 'RunPeriod-2018-01'
RUNS      = [41137]    # List of runs to process
MAXFILENO = 1000       # Max file number per run to process (n.b. file numbers start at 0!)

TESTMODE  = True

RCDB_HOST = 'hallddb'
RCDB_USER = 'rcdb'
RCDB      = None

#----------------------------------------------------
def MakeJob(RUN,FILE):
	JOB_STR   = '%s_%06d_%03d' % (NAME, RUN, FILE)
	EVIOFILE  = 'hd_rawdata_%06d_%03d.evio' % (RUN, FILE)
	MSSFILE   = '/mss/halld/%s/rawdata/Run%06d/%s' % (RUNPERIOD, RUN, EVIOFILE)
	OUTPUTDIR = '%s' % (OUTPUTTOP)
	
	# Make list of output directories. Normally, we wouldn't have
	# to make these, but if using a Globus account with a different
	# user than the one running swif2, the directories must be premade
	# with appropriate permissions
	outdirs = []
	outdirs += ['job_info']
	outdirs += ['dana_rest_coherent_peak/%06d' % RUN]
	outdirs += ['REST/%06d' % RUN]
	outdirs += ['exclusivepi0/%06d' % RUN]
	outdirs += ['omega/%06d' % RUN]
	outdirs += ['hists/%06d' % RUN]
	outdirs += ['p3pi_excl_skim/%06d' % RUN]
	outdirs += ['tree_bcal_hadronic_eff/%06d' % RUN]
	outdirs += ['tree_fcal_hadronic_eff/%06d' % RUN]
	outdirs += ['tree_PSFlux/%06d' % RUN]
	outdirs += ['tree_sc_eff/%06d' % RUN]
	outdirs += ['tree_tof_eff/%06d' % RUN]
	outdirs += ['tree_trackeff/%06d' % RUN]
	outdirs += ['tree_TS_scaler/%06d' % RUN]

	# Make map of local file(key) to output file(value)
	outfiles = {}
	outfiles['job_info.tgz'                ] = 'job_info/%06d/job_info_%06d_%03d.tgz' % (RUN, RUN, FILE)
	outfiles['dana_rest_coherent_peak.hddm'] = 'dana_rest_coherent_peak/%06d/dana_rest_coherent_peak_%06d_%03d.hddm' % (RUN, RUN, FILE)
	outfiles['dana_rest.hddm'              ] = 'REST/%06d/dana_rest_%06d_%03d.hddm' % (RUN, RUN, FILE)
	outfiles['hd_rawdata_%06d_%03d.exclusivepi0.evio' % (RUN, FILE)] = 'exclusivepi0/%06d/exclusivepi0_%06d_%03d.evio' % (RUN, RUN, FILE)
	outfiles['hd_rawdata_%06d_%03d.omega.evio' % (RUN, FILE)] = 'omega/%06d/omega_%06d_%03d.evio' % (RUN, RUN, FILE)
	outfiles['hd_root.root'                ] = 'hists/%06d/hd_root_%06d_%03d.root' % (RUN, RUN, FILE)
	outfiles['p3pi_excl_skim.root'         ] = 'p3pi_excl_skim/%06d/p3pi_excl_skim_%06d_%03d.root' % (RUN, RUN, FILE)
	outfiles['tree_bcal_hadronic_eff.root' ] = 'tree_bcal_hadronic_eff/%06d/tree_bcal_hadronic_eff_%06d_%03d.root' % (RUN, RUN, FILE)
	outfiles['tree_fcal_hadronic_eff.root' ] = 'tree_fcal_hadronic_eff/%06d/tree_fcal_hadronic_eff_%06d_%03d.root' % (RUN, RUN, FILE)
	outfiles['tree_PSFlux.root'            ] = 'tree_PSFlux/%06d/tree_PSFlux_%06d_%03d.root' % (RUN, RUN, FILE)
	outfiles['tree_sc_eff.root'            ] = 'tree_sc_eff/%06d/tree_sc_eff_%06d_%03d.root' % (RUN, RUN, FILE)
	outfiles['tree_tof_eff.root'           ] = 'tree_tof_eff/%06d/tree_tof_eff_%06d_%03d.root' % (RUN, RUN, FILE)
	outfiles['tree_trackeff.root'          ] = 'tree_trackeff/%06d/tree_trackeff_%06d_%03d.root' % (RUN, RUN, FILE)
	outfiles['tree_TS_scaler.root'         ] = 'tree_TS_scaler/%06d/tree_TS_scaler_%06d_%03d.root' % (RUN, RUN, FILE)

	# SLURM options
	SBATCH  = ['-sbatch']
	SBATCH += ['-A', PROJECT]
	SBATCH += ['--volume="/global/project/projectdirs/%s/launch:/launch"' % PROJECT]
	SBATCH += ['--image=%s' % IMAGE]
	SBATCH += ['--time=%s' % MAXTIME]
	SBATCH += ['--nodes=1']
	SBATCH += ['--tasks-per-node=1']
	SBATCH += ['--cpus-per-task=64']
	SBATCH += ['--qos=regular']
	SBATCH += ['-C', NODETYPE]
	SBATCH += ['-L', 'project']

	# Command for job to run
	CMD  = ['/global/project/projectdirs/%s/launch/run_shifter.sh' % PROJECT]
	CMD += ['--module=cvmfs']
	CMD += ['--']
	CMD += ['/launch/run_job_nersc.sh']
	CMD += [CONFIG]              # arg 1:  JANA config file
	CMD += ['sim-recon-2.27.0']  # arg 2:  sim-recon version

	# Make swif2 command
	SWIF2_CMD  = ['swif2']
	SWIF2_CMD += ['add-job']
	SWIF2_CMD += ['-workflow', WORKFLOW]
	SWIF2_CMD += ['-name', JOB_STR]
	SWIF2_CMD += ['-input', EVIOFILE, 'mss:'+MSSFILE]
	for src,dest in outfiles.iteritems(): SWIF2_CMD += ['-output', src, 'file:' + OUTPUTDIR + '/' + dest]
	SWIF2_CMD += SBATCH + ['::'] + CMD

	for d in outdirs: print 'mkdir -p ' + OUTPUTDIR + '/' + d
	print 'chmod -R 777 ' + OUTPUTDIR
	print ' '.join(SWIF2_CMD)
	
	if not TESTMODE:
		for d in outdirs: subprocess.check_call(['mkdir', '-p', OUTPUTDIR + '/' + d])
		subprocess.check_call(['chmod', '-R', '777', OUTPUTDIR])
		subprocess.check_call(SWIF2_CMD)

#----------------------------------------------------
def GetNumEVIOFiles(RUN):

	# Access RCDB to get the number of EVIO files for this run.
	# n.b. the file numbers start from 0 so the last valid file
	# number will be one less than the value returned
	global RCDB
	if not RCDB :
		try:
			RCDB = 'mysql://' + RCDB_USER + '@' + RCDB_HOST + '/rcdb'
			cnx = mysql.connector.connect(user=RCDB_USER, host=RCDB_HOST, database='rcdb')
			cur = cnx.cursor()  # using dictionary=True crashes when running on ifarm (??)
		except Exception as e:
			print 'Error connecting to RCDB: ' + RCDB
			print str(e)
			sys.exit(-1)


	Nfiles = 0
	sql  = 'SELECT int_value from conditions,condition_types WHERE condition_type_id=condition_types.id'
	sql += ' AND condition_types.name="evio_files_count" AND run_number=' + str(RUN);
	cur.execute(sql)
	c_rows = cur.fetchall()
	if len(c_rows)>0 : Nfiles = int(c_rows[0][0])

	return Nfiles

#----------------------------------------------------

# --------------- MAIN --------------------

# Loop over runs
for RUN in RUNS:

	maxfile = MAXFILENO+1
	Nfiles = GetNumEVIOFiles(RUN)
	if Nfiles < maxfile : maxfile = Nfiles
	
	# Loop over files, creating job for each
	for FILE in range(0,maxfile):
		MakeJob(RUN, FILE)



