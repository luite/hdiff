#!/bin/bash

DIR=$1
WD=$PWD
if [[ "$DIR" =~ index/data/(.*) ]]
then
  PKG=${BASH_REMATCH[1]}
else
  echo "not a package"
  exit 1
fi

echo "updating package $PKG"
# fixme: sort file by version number format
exec 8<"$DIR/versions"
while read -u8 LINE
do
  LEND=${LINE:28}
  DATE=${LINE:0:28}
  if [[ "$LEND" =~ ^([ ]?)([^ ]+)( )([^ ]+)( )([^ ]+)$ ]]
  then
    AUTHOR=${BASH_REMATCH[2]}
    VERSNO=${BASH_REMATCH[6]}
    if [[ "$DATE" =~ ^([ ]?)([A-Z][a-z]{2})([ ])([A-Z][a-z]{2})([ ]{1,2})([0-9]{1,2})([ ])([0-9\:]{8})( UTC )([0-9]{4})([ ]*)$  ]]
    then
      DAY=${BASH_REMATCH[2]}
      MONTH=${BASH_REMATCH[4]}
      MDAY=${BASH_REMATCH[6]}
      TIME=${BASH_REMATCH[8]}
      YEAR=${BASH_REMATCH[10]}
      RFCDATE="$DAY, $MDAY $MONTH $YEAR $TIME +0000"
    fi
    VERSFILE="$PKG-$VERSNO.tar.gz"
    ARCHFILE="archive/$PKG/$VERSFILE"
    if [ ! -e "$ARCHFILE" ]
    then
      echo "archive $ARCHFILE does not exist, fetching"
      mkdir "archive/$PKG"
      wget -O "$ARCHFILE" "http://hackage.haskell.org/packages/archive/$PKG/$VERSNO/$VERSFILE"
    fi
    GITDIR="git/$PKG"
    if [ ! -e "$GITDIR" ]
    then
      echo "no git repository for package yet, initializing"
      mkdir "$GITDIR"
      cd "$GITDIR"
      git init
      echo "$PKG - http://hackage.haskell.org/package/$PKG" > ".git/description"
      cd "$WD"
    fi
    cd "$GITDIR"
    TAG=`git tag -l "$VERSNO"`
    if [ "$TAG" == "$VERSNO" ]
    then
      echo "version already exists, skipping"
    else
      echo "version does not exist, adding"
      git rm -f -r *
      git clean -f
      tar --strip-components=1 -xzf "../../$ARCHFILE"
      git add -A -f
      GIT_COMMITTER_DATE=$RFCDATE
      export GIT_COMMITTER_DATE
      git commit -m"version $VERSNO" --date="$RFCDATE" --author="$AUTHOR <>"
      git tag -f "$VERSNO"
    fi
    echo "done with package version"
    cd "$WD"
  fi
done

