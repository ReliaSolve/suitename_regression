#!/bin/bash
rsync -rlpt -v -z --delete --port=33444 --include "*/" --include "*.xml.gz" --exclude "*" rsync.rcsb.org::ftp/validation_reports/ ./validation_reports

