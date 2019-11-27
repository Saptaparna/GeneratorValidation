#!/bin/bash

### settings to modify
# specify batch system 
BATCH=condor # SGE LSF 
# number of jobs 
NJOBS=1
# number of events per job 
NEVTS=10  
# path to submit jobs 
WORKDIR=`pwd -P`
# path for private fragments not yet in cmssw
#FRAGMENTDIR=${WORKDIR}/fragments
FRAGMENTDIR=${WORKDIR}/
# release setup 
SCRAM_ARCH=slc6_amd64_gcc630
RELEASE=CMSSW_9_3_8
# path to store output files
ODIR=${WORKDIR}/samples

# define output tags as well as corresponding gridpacks and shower fragments 
OTAGLIST=()
GRIDPACKLIST=() 
GENFRAGMENTLIST=()

OTAGLIST+=( dyee012j_2p6p1 )
GRIDPACKLIST+=( ${WORKDIR}/lv_bwcutoff_WJetsToLNu_HT-incl_VMG5_260_simplifiedProcCard_2Jets_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz )
#GRIDPACKLIST+=( ${WORKDIR}/gridpacks/dyee012j_5f_LO_261_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz )
#GENFRAGMENTLIST+=( /afs/cern.ch/work/r/rxiao/private/generator_validation/Hadronizer_TuneCUETP8M1_13TeV_MLM_5f_max2j_LHE_pythia8_cff ) 
GENFRAGMENT=Hadronizer_TuneCUETP8M1_13TeV_MLM_5f_max4j_LHE_pythia8_cff # wjets/zjets
#GENFRAGMENT=Hadronizer_TuneCUETP8M1_13TeV_aMCatNLO_FXFX_5f_max2j_max0p_LHE_pythia8_cff # zjets fxfx
#GENFRAGMENT=Hadronizer_TuneCUETP8M1_13TeV_aMCatNLO_FXFX_5f_max2j_max1p_LHE_pythia8_cff # ttbar fxfx 
### done with settings 


### setup release 
if [ -r ${WORKDIR}/${RELEASE}/src ] ; then 
    echo release ${RELEASE} already exists
else
    scram p CMSSW ${RELEASE}
fi
cd ${WORKDIR}/${RELEASE}/src
eval `scram runtime -sh`


### checkout generator configs 
git-cms-addpkg --quiet Configuration/Generator


### copy additional fragments if needed 
#if [ -d "${FRAGMENTDIR}" ]; then 
#    cp ${FRAGMENTDIR}/*.py ${CMSSW_BASE}/src/Configuration/Generator/python/. 
#fi


### scram release 
scram b 


### start tag loop for setups to be validated  
NTAG=`echo "scale=0; ${#OTAGLIST[@]} -1 " | bc` 

for ITAG in `seq 0 ${NTAG}`; do
    OTAG=${OTAGLIST[${ITAG}]}
    GRIDPACK=${GRIDPACKLIST[${ITAG}]}
    #GENFRAGMENT=${GENFRAGMENTLIST[${ITAG}]}
    
    ### move to python path 
    cd ${CMSSW_BASE}/src/Configuration/Generator/python/
    
    ### check that fragments are available 
    echo "Check that fragments are available ..."
    echo ${GENFRAGMENT}.py
    if [ ! -s ${GENFRAGMENT}.py ] ; then 
	echo "... cannot find ${GENFRAGMENT}.py"
	exit 0;
    else
	echo "... found required fragments!"
    fi
    
    ### create outputpath 
    if [ "${ITAG}" == 0 ] ; then
	ODIR=${ODIR}/${OTAG}
    else
	ODIR=${ODIR}/../${OTAG}
    fi
    mkdir -p ${ODIR}
    
    ### create generator fragment 
    CONFIG=${OTAG}_cff.py
    if [ -f ${CONFIG} ] ; then 
	rm ${CONFIG} 
    fi
    
    cat > ${CONFIG} <<EOF
import FWCore.ParameterSet.Config as cms
externalLHEProducer = cms.EDProducer('ExternalLHEProducer', 
args = cms.vstring('${GRIDPACK}'),
nEvents = cms.untracked.uint32(5000),
numberOfParameters = cms.uint32(1),  
outputFile = cms.string('cmsgrid_final.lhe'),
scriptName = cms.FileInPath('GeneratorInterface/LHEInterface/data/run_generic_tarball_cvmfs.sh')
)
EOF
    cat ${GENFRAGMENT}.py >> ${CONFIG}
    
       
    ### make validation fragment 
    cmsDriver.py Configuration/Generator/python/${CONFIG} \
	-n ${NEVTS} --mc --no_exec --python_filename cmsrun_${OTAG}.py \
	-s LHE,GEN,VALIDATION:genvalid_all --datatier GEN,GEN-SIM,DQMIO --eventcontent LHE,RAWSIM,DQM \
	--conditions auto:run2_mc_FULL --beamspot Realistic8TeVCollision 


    ### move to submission directory 
    cd ${WORKDIR}


    ### prepare submission script 
    cat > subscript_${OTAG}.sh <<EOF 
#!/bin/bash
pushd ${CMSSW_BASE}/src/
eval \`scram runtime -sh\`
popd
if [ ! -z ${TMPDIR} ] ; then 
cd ${TMPDIR}
fi 
mkdir -p tmp_\${OTAG}_\${OFFSET}
cd tmp_\${OTAG}_\${OFFSET}
echo "execute job in path $PWD"
cp ${CMSSW_BASE}/src/Configuration/Generator/python/cmsrun_${OTAG}.py .
### adjust random numbers 
LINE=\`egrep -n Configuration.StandardSequences.Services_cff cmsrun_${OTAG}.py | cut -d: -f1 \`
SEED=\`echo "5267+\${OFFSET}" | bc\`
sed -i "\${LINE}"aprocess.RandomNumberGeneratorService.generator.initialSeed=\${SEED} cmsrun_${OTAG}.py  
SEED=\`echo "289634+\${OFFSET}" | bc\`
sed -i "\${LINE}"aprocess.RandomNumberGeneratorService.externalLHEProducer.initialSeed=\${SEED} cmsrun_${OTAG}.py  
### run config 
cmsRun cmsrun_${OTAG}.py || exit $? ; 
### copy output 
#if [ $? -eq 0 ]; then
#cp *_inDQM.root \${ODIR}/\${OTAG}_\${OFFSET}.root 
#else
#echo "Generation problems please check log file carefully!"
#fi 
#cd ../
#rm -rf tmp_\${OTAG}_\${OFFSET}
EOF
    # adjust rights 
    chmod 755 subscript_${OTAG}.sh

#########updated submit jobs
   IJOBS=1
   while [ "${IJOBS}" -le "${NJOBS}" ]; do
	   if [ ! -s ${ODIR}/${OTAG}_${IJOBS}.root ] ; then

cat>condor_${OTAG}_${IJOBS}.jdl<<EOF
universe = vanilla
Executable = subscript_${OTAG}.sh
Requirements = (OpSysAndVer =?= "CentOS7")
request_disk = 10000000
request_memory = 4000
Should_Transfer_Files = YES
WhenToTransferOutput = ON_EXIT
transfer_input_files = subscript_${OTAG}.sh, ${CMSSW_BASE}/src/Configuration/Generator/python/cmsrun_${OTAG}.py
#transfer_output_files = ${ODIR}/${OTAG}_${IJOBS}.root
#transfer_output_files = ${OTAG}_${IJOBS}.root
transfer_output_files = dyee012j_2p6p1_cff_py_LHE_GEN_VALIDATION_inDQM.root 

notification = Never 
Output = ${ODIR}/${OTAG}_${IJOBS}.stdout
Error = ${ODIR}/STDERR_${OTAG}_${IJOBS}.stderr
Log = ${ODIR}/LOG_${OTAG}_${IJOBS}.log
x509userproxy = ${X509_USER_PROXY}
Queue 1
EOF

condor_submit condor_${OTAG}_${IJOBS}.jdl

 


fi
IJOBS=$(($IJOBS+1))
done #end of jobs loop




    ### clean up 
    # rm subscript_${OTAG}.sh 

done # end of tag loop 
