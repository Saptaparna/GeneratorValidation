#!/bin/sh

max=100
for i in `seq 1 $max`
do
    source step1_createConfigsValidation.csh 5000 $i 
    source submitCondorValidation.csh 5000 $i 
done
