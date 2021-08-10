#!/bin/bash
#############################################################################
# Run regression tests for the current SuiteName program against the values
# currently stored in the PDB for Suiteness.  Also run against the previous
# version of SuiteName to see if they produce the same outputs.
#
# Must be run in an environment where "phenix.suitename" points at the
# new CCTBX version of SuiteName and where the monomer libraries can be
# found so that the mp_geo program works.
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
# The first argument, if present, specifies the modulo of 8 to use when
# deciding whether the script should run a file.  (It used to specify
# VERBOSE="yes").

MODULO=""
if [ "$1" != "" ] ; then MODULO="$1" ; fi

######################
# Pull the XML validation records
if [ -n "$VERBOSE" ] ; then echo "Syncing validaton records" ; fi
#./get_validation.sh

######################
# Pull the mMCIF files
#./get_mmCIF.sh

#####################
# Make sure the suitename submodule is checked out

echo "Updating submodule"
git submodule update --init
(cd suitename; git pull) &> /dev/null

orig="0105199a20122dc1e6d3be64fc839ed039a7e54f"
echo "Building $orig"
(cd suitename; git checkout $orig) &> /dev/null
mkdir -p build_new
(cd build_new; cmake -DCMAKE_BUILD_TYPE=Release ../suitename/C; make) &> /dev/null
orig_exe="./build_new/suitename"
new_exe="phenix.suitename"


######################
# For each validation file, see if we can extract the required record.  If so,
# run suitename on the mmCIF file and see if they match.

total=0
count=0
failed=0
old_vs_new=0
pdb_vs_cif=0
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
  # See if our modulo parameter tells us to skip it.
  if [ "$MODULO" != "" ] ; then
    mod=$(("$count" % 8))
    if [ "$mod" -ne "$MODULO" ] ; then
      echo "Skipping $f, modulo = $mod"
      continue
    fi
  fi

  ##############################################
  # Now run mp_geo on the input file and send its output to suitename.
  # Parse the report from suitename to get the value rounded to three
  # significant digits.

  # Get the full mmCIF file name
  d2=`echo $f | cut -d/ -f 2`
  d3=`echo $f | cut -d/ -f 3`
  name=$d3
  cname=mmCIF/$d2/$name.cif.gz
  if [ -n "$VERBOSE" ] ; then echo "Comparing $cname" ; fi

  # Decompress the file after making sure the file exists.
  if [ ! -f $cname ] ; then continue ; fi
  temp=$$
  ciffile="$temp.cif"
  pdbfile="$temp.pdb"
  gunzip < $cname > $ciffile

  # Convert the file to PDB format because CIF files give mmtbx.mp_geo problems that
  # the corresponding converted PDB files do not.
  iotbx.cif_as_pdb $ciffile > /dev/null
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error running iotbx.cif_as_pdb on $name, value $val ($failed failures out of $count)"
    continue
  fi

  # Run mp_geo on the PDB file to get the angles.
  # If the program returns failure, skip other tests on the file.
  t2file="./outputs/$name.dangle"
  mmtbx.mp_geo rna_backbone=True $pdbfile > $t2file
  #java -Xmx512m -cp ~/src/MolProbity/lib/dangle.jar dangle.Dangle rnabb $ciffile > $t2file
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error running mp_geo on $name, value $val ($failed failures out of $count)"
    continue
  fi

  ########
  # Run the new version of SuiteName on the CIF and PDB versions.
  # Report failure if it happens.
  $new_exe -report $ciffile 2>/dev/null > ./outputs/$name.cif
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error computing suiteness from CIF for $name ($failed failures out of $count)"
  fi
  $new_exe -report $pdbfile 2>/dev/null > ./outputs/$name.pdb
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error computing suiteness from PDB for $name ($failed failures out of $count)"
  fi

  ########
  # Test for unexpected differences between the PDB and CIF outputs.
  d=`diff outputs/$name.cif outputs/$name.pdb | wc -c`
  if [ $d -ne 0 ]; then
    let "pdb_vs_cif++"
    echo "PDB vs. CIF comparison failed for $name ($pdb_vs_cif out of $count)"
  fi

  ########
  # Run both versions of SuiteName on the file, storing them for later comparison.
  # Report failure if it happens.
  $orig_exe -report -pointIDfields 7 -altIDfield 6 < $t2file 2>/dev/null > ./outputs/$name.report.orig
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error computing orig suiteness for $name ($failed failures out of $count)"
  fi

  $new_exe -report -pointIDfields 7 -altIDfield 6 < $t2file 2>/dev/null > ./outputs/$name.report.new
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error computing new suiteness for $name ($failed failures out of $count)"
  fi

  ########
  # Test for unexpected differences between the old and new outputs.
  d=`diff outputs/$name.report.orig outputs/$name.report.new | python3 filter_report_diff_low_order_bit.py |& wc -c`
  if [ $d -ne 0 ]; then
    let "old_vs_new++"
    echo "Old vs. new comparison failed for $name ($old_vs_new out of $count)"
  fi

  ########
  # Run both versions of SuiteName with -string -oneline, storing them for later comparison.
  # Report failure if it happens.
  $orig_exe -string -oneline -pointIDfields 7 -altIDfield 6 < $t2file 2>/dev/null > ./outputs/$name.string.orig
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error computing orig string suiteness for $name ($failed failures out of $count)"
  fi

  $new_exe -string -oneline -pointIDfields 7 -altIDfield 6 < $t2file 2>/dev/null > ./outputs/$name.string.new
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error computing new string suiteness for $name ($failed failures out of $count)"
  fi

  ########
  # Test for unexpected differences between the old and new outputs.
  d=`diff outputs/$name.string.orig outputs/$name.string.new | wc -c`
  if [ $d -ne 0 ]; then
    let "old_vs_new++"
    echo "Old vs. new string comparison failed for $name ($old_vs_new out of $count)"
  fi

  ########
  # Run both versions of SuiteName with -kinemage, storing them for later comparison.
  # Report failure if it happens.
  $orig_exe -kinemage -pointIDfields 7 -altIDfield 6 < $t2file 2>/dev/null > ./outputs/$name.kinemage.orig
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error computing orig kinemage suiteness for $name ($failed failures out of $count)"
  fi

  $new_exe -kinemage -pointIDfields 7 -altIDfield 6 < $t2file 2>/dev/null > ./outputs/$name.kinemage.new
  if [ $? -ne 0 ] ; then
    let "failed++"
    echo "Error computing new kinemage suiteness for $name ($failed failures out of $count)"
  fi

  ########
  # Remove expected differences between the two files.
  grep -v suitename < outputs/$name.kinemage.orig > outputs/$name.kinemage.orig.cleaned
  grep -v suitename < outputs/$name.kinemage.new > outputs/$name.kinemage.new.cleaned

  ########
  # Test for unexpected differences between the old and new outputs.
  d=`diff outputs/$name.kinemage.orig.cleaned outputs/$name.kinemage.new.cleaned | python3 filter_kinemage_diff_low_order_bit.py |& wc -c`
  if [ $d -ne 0 ]; then
    let "old_vs_new++"
    echo "Old vs. new kinemage comparison failed for $name ($old_vs_new out of $count)"
  fi

  ########
  # Read one of the reports back in for comparison against the PDB results.
  suite=`cat ./outputs/$name.report.orig`

  # Parse to pull out average suiteness== 0.694 (for one particular file)
  sval=`echo "$suite" | grep "For all" | awk '{print $7}'`
  # Remove blank lines.

  # Report failure on this file if it happens.
  if [ `echo $sval | wc -w` -ne 1 ] ; then
    let "failed++"
    echo "Error computing suiteness for $name ($failed failures out of $count)"
    # Skip comparing the results if we could not compute them.
    continue
  fi

  # Compare to see if we got the same results.
  # Use the basic calculator (bc) with the floating-point (-l) option to determine
  # whether the absolute value of the difference is larger than half of a significant
  # digit.
  diff=`echo "define abs(x) {if (x<0) {return -x}; return x;} ; abs($val-$sval)>0.005" | bc -l`
  if [ "$diff" -ne 0 ] ; then
    let "differed++"
    echo "$name PDB value = $val SuiteName value = $sval ($differed different, $failed failed of $count/$total)"
  fi

  # Remove the temporary files
  rm $ciffile
  rm $pdbfile

done

echo
ret=0
if [ $pdb_vs_cif -ne 0 ]
then
  echo "$pdb_vs_cif files differed between PDB and CIF out of $count that had suiteness scores"
  let "ret+=$pdb_vs_cif"
fi
if [ $old_vs_new -ne 0 ]
then
  echo "$old_vs_new files differed between old and new out of $count that had suiteness scores"
  let "ret+=$old_vs_new"
fi
if [ $differed -ne 0 ]
then
  echo "$differed files differed out of $count that had suiteness scores"
  let "ret+=$differed"
fi
if [ $failed -ne 0 ]
then
  echo "$failed files failed out of $count that had suiteness scores"
  let "ret+=$failed"
fi

if [ $ret -eq 0 ]
then
  echo "Success!"
fi
exit $ret

