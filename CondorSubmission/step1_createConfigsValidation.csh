#!/bin/csh                                                                                                                                                                         
cp cmsrunscript_ttbar_Template.py cmsrunscript_TTBar_NEVENT${1}_NPART${2}.py
sed -i "s/NEVENT/$1/g" cmsrunscript_TTBar_NEVENT${1}_NPART${2}.py
sed -i "s/NPART/$2/g" cmsrunscript_TTBar_NEVENT${1}_NPART${2}.py
