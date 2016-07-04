#!/bin/bash

## Create backup from gitolite repositories, with optional GnuPG encryption.

## executable files
export GITOLITE="gitolite"
export GPG="gpg"
export GIT="git"


## functions
function clean_repos {
  echo -e "\n" $1;
  cd $1; $GIT fsck; $GIT gc --prune=now
}


## exports and variables
export -f clean_repos
export DATE=`date +%F-%H-%M-%S`  # result format: 2016-07-04-15-25-11
export BACKUP_DIR="/srv/gitolite"
export GITOLITE_REPO_DIR="/srv/gitolite/repositories"
export TEMP_DIR="/tmp"
export BACKUP_FILENAME="gitolite-$DATE.tar.xz"
export BACKUP_MESSAGE="please wait"
export COMPRESS_PARAMS="XZ_OPT=-9"
export GPG_PARAMS="--cipher-algo AES256"
export TAR_PARAMS="-Jcvf"
# export GPG_PASSWORD=""  # plain-text password
export GPG_PASSWORD=`cat archive_password.txt`  # password file


## main program
echo $BACKUP_MESSAGE | $GITOLITE writable @all off  # disable "git push" command
find $GITOLITE_REPO_DIR -name '*.git' -type d -exec bash -c 'clean_repos "$0"' {} \;
if [[ -n $GPG_PASSWORD ]]
then
  # encrypt archive
  mkdir -p $TEMP_DIR/repo_backup
  chmod 700 $TEMP_DIR/repo_backup
  export $COMPRESS_PARAMS; tar $TAR_PARAMS $TEMP_DIR/repo_backup/$BACKUP_FILENAME $GITOLITE_REPO_DIR
  echo $GPG_PASSWORD | $GPG $GPG_PARAMS --passphrase-fd 0 -c $TEMP_DIR/repo_backup/$BACKUP_FILENAME
  mv $TEMP_DIR/repo_backup/$BACKUP_FILENAME.gpg $BACKUP_DIR/
  rm -rf $TEMP_DIR/repo_backup
else
  # non-encrypt archive
  export $COMPRESS_PARAMS; tar $TAR_PARAMS $BACKUP_DIR/$BACKUP_FILENAME $GITOLITE_REPO_DIR
fi
$GITOLITE writable @all on  # enable "git push" command
