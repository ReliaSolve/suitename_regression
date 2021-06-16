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

total=0
count=0
failed=0
differed=0
files=`cd validation_reports; find . -name \*.gz`
for f in $files; do

  ##############################################
  # We found a file.
  let "total++"
  mod=`echo "$total % 1000" | bc`
  if [ "$mod" -eq 0 ] ; then
    echo "Checked $total files..."
  fi

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

  ##############################################
  # We found a file to check.
  let "count++"

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

  # Convert the file to PDB format because CIF files give mmtbx.mp_geo problems that
  # the corresponding converted PDB files do not.
  iotbx.cif_as_pdb $tfile > /dev/null
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error running iotbx.cif_as_pdb on $d3, value $val ($failed failures out of $count)"
    continue
  fi

  # Run mp_geo on the PDB file to get the angles and feed that to SuiteName to output the report.
  # If either program returns failure, report this as a failure.
  t2file="./tmp2.out"
  mmtbx.mp_geo rna_backbone=True "./tmp.pdb" > $t2file
  #java -Xmx512m -cp ~/src/MolProbity/lib/dangle.jar dangle.Dangle rnabb $tfile > $t2file
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error running mp_geo on $d3, value $val ($failed failures out of $count)"
    continue
  fi
  suite=`phenix.suitename -report -pointIDfields 7 -altIDfield 6 < $t2file`

  # Parse to pull out average suiteness== 0.694 (for one particular file)
  sval=`echo "$suite" | grep "For all" | awk '{print $7}'`
  # Remove blank lines.

  # Report failure on this file if it happens.
  if [ `echo $sval | wc -w` -ne 1 ] ; then
    let "failed++"
    echo "Error computing suiteness for $d3 ($failed failures out of $count)"
    continue
  fi

  # Compare to see if we got the same results.
  # Use the basic calculator (bc) with the floating-point (-l) option to determine
  # whether the absolute value of the difference is larger than half of a significant
  # digit.
  diff=`echo "define abs(x) {if (x<0) {return -x}; return x;} ; abs($val-$sval)>0.005" | bc -l`
  if [ "$diff" -ne 0 ] ; then
    let "differed++"
    echo "$d3 PDB value = $val SuiteName value = $sval ($differed different, $failed failed of $count/$total)"
    continue
  fi

done

echo
if [ $differed -ne 0 ]
then
  echo "$differed files differed out of $count that had suiteness scores"
  exit $differed
fi
if [ $failed -ne 0 ]
then
  echo "$failed files failed out of $count that had suiteness scores"
  exit $failed
fi

echo "Success!"
exit 0

