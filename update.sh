#!/bin/bash
# this requires bash 4.x
# incremental must be run at least every day,
# and only checks the last 500 uploaded packages

if [[ $1 == "--incremental" ]]
then
  INCREMENTAL=true
else
  INCREMENTAL=false
fi

if $INCREMENTAL ; then
  echo "doing an INCREMENTAL update"
else
  echo "doing a FULL update"
fi

cd /home/hdiff/hdiff

LOGMODBEFORE=`stat -c %Y index/log`
pushd "index"
wget -N http://hackage.haskell.org/packages/archive/00-index.tar.gz
wget -N http://hackage.haskell.org/packages/archive/log
popd
LOGMODAFTER=`stat -c %Y index/log`
if [[ $LOGMODBEFORE == $LOGMODAFTER ]]
then
  echo "log not modified, no changes"
  exit 0
fi

rm -rf index/data
mkdir index/data
echo "unpacking index"
tar -xzC index/data -f "index/00-index.tar.gz"

CURRENT=`date --utc +%s`
echo "processing uploadlog"
if [ $INCREMENTAL ]
then
  tail -500 index/log > index/log.incr
  exec 9<index/log.incr
else
  exec 9<index/log
fi

declare -A UPDATED
while read -u9 LINE
do
  LEND=${LINE:29}
  if [[ "$LEND" =~ ^([ ]*)([^ ]+)( )([^ ]+)( )([^ ]+)$ ]]
  then
    PKG=${BASH_REMATCH[4]}
    if [ ! $INCREMENTAL ]
    then
      echo $LINE >> "index/data/$PKG/versions"
    else
      UPDATED=`date --utc --date "${LINE:0:28}" +%s`
      # accept only packages less than a day old
      if [[ $((CURRENT-UPDATED)) -lt 86400 ]]
      then
        echo $LINE >> "index/data/$PKG/versions"
        echo "new package: $PKG"
        UPDATED[$PKG]=1
      fi
    fi
  fi
done

echo "updating packages"
if [ ! $INCREMENTAL ]
then
  find index/data -maxdepth 1 -type d -exec ./update-package.sh {} \;
else
  for PKG in "${!UPDATED[@]}"
  do
    if [[ $PKG != "0" ]] ; then
      echo "updating $PKG"
      ./update-package.sh "index/data/$PKG"
    fi
  done
fi

tail -20 index/log > index/latestupdates

