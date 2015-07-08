#!/bin/sh
#
# This script runs all build service test suites depending on $SUBTEST
#

###############################################################################
# Script content for 'Build' step
###############################################################################
#
# Either invoke as described above or copy into an 'Execute shell' 'Command'.
#

set -xe

. `dirname $0`/obs_testsuite_common.sh

ret=0
export OBS_REPORT_DIR=results/
export HEADLESS=forsure

cd src/api

if test -z "$SUBTEST"; then
  export DO_COVERAGE=1
  export TESTOPTS="-v"
  bundle exec rake test:api || {
    cat tmp/backend_config/bs_srcserver.log;
    echo "REPSERVER";
    cat tmp/backend_config/bs_repserver.log;
    echo "ajax src?";
    cat tmp/backend_data/run/bs_srcserver.AJAX.died || echo "src ok";
    echo "ajax rep?";
    cat tmp/backend_data/run/bs_repserver.AJAX.died || echo "rep ok";
    exit 1;
  }
  bundle exec rake test:webui
  cat coverage/.last_run.json
  ruby -rcoveralls -e 'Coveralls.push!'
fi

case $SUBTEST in
  rake:*)
   SUBTEST=${SUBTEST/rake:/}
   bundle exec rake $SUBTEST --trace
   ;;
  api:*)
   SUBTEST=${SUBTEST/api:/}
   thetest=${SUBTEST/:*/}
   thename=${SUBTEST/*:/}
   bundle exec ruby -Itest test/$thetest --name=$thename || ret=1
   tail -n 6000 log/test.log
   ;;
esac

# print srcserver log (just for testing)
cat tmp/backend_config/bs_srcserver.log
cd ../..
cleanup
exit $ret

