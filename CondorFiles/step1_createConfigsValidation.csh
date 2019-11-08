#!/bin/csh                                                                                                                                                                         
cp TTbar012Jets_5f_NLO_FXFX_Madgraph_LHE_13TeV_cff_py_LHE_Template.py cmsrunscript_TTBar_NEVENT${1}_NPART${2}.py
sed -i "s/NEVENT/$1/g" cmsrunscript_TTBar_NEVENT${1}_NPART${2}.py
sed -i "s/NPART/$2/g" cmsrunscript_TTBar_NEVENT${1}_NPART${2}.py
