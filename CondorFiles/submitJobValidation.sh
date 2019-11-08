#!/bin/sh

max=1000
for i in `seq 1 $max`
do
    source step1_createConfigsValidation.csh 50 $i
    source submitCondorValidation.csh 50 $i
done
