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
  if [ -n "$VERBOSE" ] ; then echo "Checking $fval" ; fi

  # See if we have the RNAsuiteness key in the line and pull its value if so.
  # Note that there are absolute-percentile-RNAsuiteness and other prefixed versions
  # that we want to ignore.
  line=`gunzip < $fval | grep ' RNAsuiteness'`
  if [ -z "$line" ] ; then continue ; fi
  val=`echo "$line" | sed -r 's/[ [:alnum:]]+=/\n&/g' | awk -F= '$1==" RNAsuiteness"{print $2}'`
  # Sometimes we get a second word "bonds_" after the quoted number, so we strip it.
  val=`echo $val | awk '{print $1;}'`
  # Remove the quotes to get just the digits.
  val=`echo "$val" | tr -d '"'`

  # The variable $val now has just the 0.XX value in string form.
  echo $val

  # mmtbx.mp_geo rna_backbone=True F:/data/Richardsons/4z4d.cif
  # phenix.suitename -report -oneline -pointIDfields 7 -altIDfield 6

done

echo
if [ $failed -eq 0 ]
then
  echo "Success!"
else
  echo "$failed files failed"
fi

exit $failed

