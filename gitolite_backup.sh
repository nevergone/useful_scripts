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

function delete_temp {
  rm -rf $TEMP_DIR
}

function script_ok {
  echo $1
  logger "gitolite backup - success: " $1
  delete_temp
  $GITOLITE writable @all on  # enable "git push" command
  exit 0
}

function script_error {
  echo $1
  logger "gitolite backup - error: " $1
  delete_temp
  $GITOLITE writable @all on  # enable "git push" command
  exit -1
}


## exports and variables
export -f clean_repos
export DATE=`date +%F-%H-%M-%S`  # result format: 2016-07-04-15-25-11
export BACKUP_DIR="/srv/gitolite"
export GITOLITE_REPO_DIR="/srv/gitolite/repositories"
export TEMP_DIR="/tmp/repo_backup"
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
  mkdir -p $TEMP_DIR
  chmod 700 $TEMP_DIR
  export $COMPRESS_PARAMS; tar $TAR_PARAMS $TEMP_DIR/$BACKUP_FILENAME $GITOLITE_REPO_DIR
  if [[ ! -e $TEMP_DIR/$BACKUP_FILENAME ]]
  then
    script_error "backup file not exist: $BACKUP_FILENAME"
  fi
  echo $GPG_PASSWORD | $GPG $GPG_PARAMS --passphrase-fd 0 -c $TEMP_DIR/$BACKUP_FILENAME
  if [[ ! -e $TEMP_DIR/$BACKUP_FILENAME.gpg ]]
  then
    script_error "gpg file not exist: $BACKUP_FILENAME.gpg"
  fi
  mv $TEMP_DIR/$BACKUP_FILENAME.gpg $BACKUP_DIR/
else
  # non-encrypt archive
  export $COMPRESS_PARAMS; tar $TAR_PARAMS $BACKUP_DIR/$BACKUP_FILENAME $GITOLITE_REPO_DIR
  if [[ ! -e $BACKUP_DIR/$BACKUP_FILENAME ]]
  then
    script_error "backup file not exist: $BACKUP_FILENAME"
  fi
fi
script_ok "backup complete: $BACKUP_FILENAME"