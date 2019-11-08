#!/bin/tcsh
echo $PWD

echo ${1}
echo ${2}

cat>Job_${1}_${2}_directional.csh<<EOF
#!/bin/tcsh
tar -zxvf CMSSW_11_0_0_pre2.tar.gz
setenv SCRAM_ARCH slc7_amd64_gcc700 
cd CMSSW_11_0_0_pre2/src
scramv1 b ProjectRename
source /cvmfs/cms.cern.ch/cmsset_default.csh
#setenv SCRAM_ARCH "slc7_amd64_gcc700";
cmsenv
scramv1 b
cd -
cmsRun  cmsrunscript_TTBar_NEVENT${1}_NPART${2}.py >& step1_cmsrunscript_TTBar_NEVENT${1}_NPART${2}_output.txt
EOF

chmod 775 Job_${1}_${2}_directional.csh

cat>condor_${1}_${2}.jdl<<EOF
universe = vanilla
Executable = Job_${1}_${2}_directional.csh
Requirements = (OpSysAndVer =?= "CentOS7")
request_disk = 10000000
request_memory = 4000
Should_Transfer_Files = YES
WhenToTransferOutput = ON_EXIT
transfer_input_files = Job_${1}_${2}_directional.csh, cmsrunscript_TTBar_NEVENT${1}_NPART${2}.py, CMSSW_11_0_0_pre2.tar.gz
transfer_output_files = FullFragment_TTBar_ForValidation_py_LHE_GEN_VALIDATION_n${1}_part${2}.root, FullFragment_TTBar_ForValidation_py_LHE_GEN_VALIDATION_n${1}_part${2}_inRAWSIM.root, FullFragment_TTBar_ForValidation_py_LHE_GEN_VALIDATION_n${1}_part${2}_inDQM.root 
notification = Never 
Output = CondorJobs/STDOUT_${1}_${2}.stdout
Error = CondorJobs/STDERR_${1}_${2}.stderr
Log = CondorJobs/LOG_${1}_${2}.log
x509userproxy = ${X509_USER_PROXY}
Queue 1
EOF

condor_submit condor_${1}_${2}.jdl
