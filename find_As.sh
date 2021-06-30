#!/bin/bash
#############################################################################
# Look for all instances of atoms or hetatms named 'A', which indicate that
# there is ambiguity between N and OH.  Count the number of them found in
# any mmCIF file in an rsync mirror of the PDB.
#############################################################################

######################
# Parse the command line

if [ "$1" != "" ] ; then VERBOSE="yes" ; fi

######################
# For each mmCIF file, count the number of A's found and print if they are
# nonzero.

total=0
foundAFiles=0
foundAs=0
dirs=`cd mmCIF; find * -type d`
for d in $dirs; do

  files=`cd mmCIF/$d; find . -name \*.gz`
  for f in $files; do

    ##############################################
    # We found a file.
    let "total++"
    mod=`echo "$total % 1000" | bc`
    if [ "$mod" -eq 0 ] ; then
      echo "Checked $total files..."
    fi

    As=`gunzip < mmCIF/$d/$f | grep '^ATOM \|^HETATM ' | awk '{print $4}' | grep ^A$ | wc -l`
    if [ "$As" -ne 0 ] ; then
      let "foundAFiles++"
      let "foundAs+=$As"
      echo "Found $As As in $f"
    fi

  done

done

echo "Found $total files"
echo "Found $foundAFiles files with As"
echo "Found $foundAs As"

exit 0

