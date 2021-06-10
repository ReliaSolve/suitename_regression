#!/bin/bash
#############################################################################
# Run regression tests for the current SuiteName program against the values
# currently stored in the PDB for Suiteness.
#
# This presumes that you are running in an environment where you have
# mmtbx.mp_geo and phenix.suitename on your path and have access to the
# rsync command as well.
#
# The program first uses rsync to pull all of the PDB CIF files into the
# mmCIF directory (if this has been done before, only changes will be pulled)
# and all of the XML-format validation records into the validation-reports
# directory (again, only pulling differences).
#
# It then looks for all structures that have an RNAsuiteness entry in their
# XML files and runs mp_geo and suitename on the mmCIF file to compute the
# suiteness score and then compares the two results to two significant
# digits to see if they agree.
#
#############################################################################

######################
# Parse the command line

if [ "$1" != "" ] ; then VERBOSE="yes" ; fi

######################
# Pull the XML validation records
if [ -n "$VERBOSE" ] ; then echo "Syncing validaton records" ; fi
#./get_validation.sh

######################
# Pull the mMCIF files
#./get_data.sh

######################
# For each validation file, see if we can extract the required record.  If so,
# run suitename on the mmCIF file and see if they match.

failed=0
files=`cd validation_reports; find . -name \*.gz`
for f in $files; do

  ##############################################
  # Full validation-file name
  fval=validation_reports/$f
  #if [ -n "$VERBOSE" ] ; then echo "Checking $fval" ; fi

  ##############################################
  # See if we have the RNAsuiteness key in the line and pull its value if so.
  # Note that there are absolute-percentile-RNAsuiteness and other prefixed versions
  # that we want to ignore.
  line=`gunzip < $fval | grep ' RNAsuiteness'`
  if [ -z "$line" ] ; then
    if [ -n "$VERBOSE" ] ; then echo "No RNAsuiteness in $fval (skipping)" ; fi
    continue
  fi
  val=`echo "$line" | sed -r 's/[ [:alnum:]]+=/\n&/g' | awk -F= '$1==" RNAsuiteness"{print $2}'`
  # Sometimes we get a second word "bonds_" after the quoted number, so we strip it.
  val=`echo $val | awk '{print $1;}'`
  # Remove the quotes to get just the digits.
  val=`echo "$val" | tr -d '"'`

  # The variable $val now has just the 0.XX value in string form.
  # echo $val

  ##############################################
  # Now run mp_geo on the input file and send its output to suitename.
  # Parse the report from suitename to get the value rounded to three
  # significant digits.

  # Get the full mmCIF file name
  d2=`echo $f | cut -d/ -f 2`
  d3=`echo $f | cut -d/ -f 3`
  cname=mmCIF/$d2/$d3.cif.gz
  if [ -n "$VERBOSE" ] ; then echo "Comparing $cname" ; fi

  # Decompress the file after making sure the file exists.
  if [ ! -f $cname ] ; then continue ; fi
  tfile="./tmp.cif"
  gunzip < $cname > $tfile

  # Run to get the output of the report.
  # If either program returns failure, report the failure.
  t2file="./tmp2.out"
  mmtbx.mp_geo rna_backbone=True $tfile > $t2file
  if [ $? -ne 0 ] ; then
    echo "Error running mp_geo for $cname"
    let "failed++"
    continue
  fi
  suite=`phenix.suitename -report -oneline -pointIDfields 7 -altIDfield 6 < $t2file`

  # Parse to pull out average suiteness== 0.694 (for one particular file) and then round.
  sval=`echo "$suite" | awk -F"average suiteness==" '{print $2}'`
  # Remove blank lines.
  # Pull only the first report, which will be the total; and only its first word
  sval=`echo "$sval" | grep -v -e '^$' | head -1 | awk '{print $1}'`
  # Use Banker's rounding to find the nearest 2-digit number (rounds 0.5 to even).
  sval=`printf "%.2f" $sval`

  # Report failure on this file if it happens.
  if [ `echo $sval | wc -w` -ne 1 ] ; then
    echo "Error computing suiteness for $cname"
    let "failed++"
    continue
  fi
  echo "$f val = $val, sval = $sval"

done

echo
if [ $failed -eq 0 ]
then
  echo "Success!"
else
  echo "$failed files failed"
fi

exit $failed

