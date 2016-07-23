#!/bin/bash

## Create backup from gitolite repositories, with optional GnuPG encryption.

## executable files, use absolute paths
export GITOLITE="/usr/local/bin/gitolite"
export GPG="/usr/bin/gpg"
export GIT="/usr/bin/git"
export LOGGER="/usr/bin/logger"


## functions
function clean_repos {
  # test repository integrity and run garbage collection
  echo -e "\n $1"
  cd "$1" || exit -2
  $GIT fsck
  $GIT gc --prune=now
}

function delete_temp {
  # delete temporary directory and other required commands
  rm -rf "$TEMP_DIR"
}

function script_exit_common {
  # common exit function: success and faultly operation
  delete_temp
  $GITOLITE writable @all on  # enable "git push" command
}

function script_exit_ok {
  # exit function: success operation
  script_exit_common ok "$*"
  if [[ BACKUP_FILE_COUNTER_LIMIT -gt 0 ]]; then
    # delete old backup files
    OIFS="$IFS"  # backup IFS
    IFS=$'\n'
    export BACKUP_FILES=( $(ls -1crp "$BACKUP_DIR" | grep -v / ) )  # get file list, reverse sort by ctime
    export BACKUP_FILES_NUMBER=${#BACKUP_FILES[@]}  # number of files
    i="0"
    while [ $i -lt $((BACKUP_FILES_NUMBER-BACKUP_FILE_COUNTER_LIMIT)) ]; do
      rm -f "$BACKUP_DIR/${BACKUP_FILES[$i]}"
      if [[ ! -e "$BACKUP_DIR/${BACKUP_FILES[$i]}" ]]; then
        echo "backup file deleted: ${BACKUP_FILES[$i]}"
        $LOGGER "gitolite backup - success: backup file deleted: ${BACKUP_FILES[$i]}"
      else
        echo "backup file not deleted: ${BACKUP_FILES[$i]}"
        $LOGGER "gitolite backup - error: backup file not deleted: ${BACKUP_FILES[$i]}"
        exit -1
      fi
      i=$((i+1))
    done
    IFS="$OIFS"  # restore original IFS
  fi
  echo $1
  $LOGGER "gitolite backup - success: $1"
  exit 0
}

function script_exit_error {
  # exit function: faultly operation
  script_exit_common error "$*"
  echo $1
  $LOGGER "gitolite backup - error: $1"
  exit -1
}


## exports and variables
export -f clean_repos
export DATE=$(date "+%F-%H-%M-%S")  # current date, result format: 2016-07-04-15-25-11
export BACKUP_DIR="/srv/gitolite/backup"  # backup destination directory
export GITOLITE_REPO_DIR="/srv/gitolite/repositories"  # source gitolite directory
export TEMP_DIR="/tmp/gitolite_backup"  # temporary directory
export BACKUP_FILENAME="gitolite-$DATE.tar.xz"  # backup filename
export BACKUP_FILE_COUNTER_LIMIT="2"  # maximum count of backup files, 0: not delete old files
export GIT_PUSH_DISABLED_MESSAGE="please wait"  # "git push" disabled message
export COMPRESS_PARAMS="XZ_OPT=-9"  # compression type and level
export GPG_PARAMS="--cipher-algo AES256" # gpg command-line parameters
export TAR_PARAMS="-Jcvf"  # tar command-line parameters
# export GPG_PASSWORD=""  # use plain-text password for encrypted backup
# export GPG_PASSWORD=`cat archive_password.txt`  # use password file for encrypted backup


## main program
if [ ! -d "$GITOLITE_REPO_DIR" -o ! -r "$GITOLITE_REPO_DIR" ]; then
  script_exit_error "source directory not exist or not readable"
fi
echo "$GIT_PUSH_DISABLED_MESSAGE" | $GITOLITE writable @all off  # disable "git push" command
if [ $? -ne 0 ]; then
  script_exit_error "gitolite error"
fi
find "$GITOLITE_REPO_DIR" -name '*.git' -type d -exec bash -c 'clean_repos "$0"' {} \;
mkdir -p "$BACKUP_DIR"
if [[ -n $GPG_PASSWORD ]]; then
  # encrypt archive
  mkdir -p "$TEMP_DIR"
  chmod 700 "$TEMP_DIR"
  export $COMPRESS_PARAMS; tar $TAR_PARAMS "$TEMP_DIR/$BACKUP_FILENAME" "$GITOLITE_REPO_DIR"
  if [[ ! -e $TEMP_DIR/$BACKUP_FILENAME ]]; then
    script_exit_error "backup file not exist: $BACKUP_FILENAME"
  fi
  echo "$GPG_PASSWORD" | $GPG $GPG_PARAMS --no-tty --passphrase-fd 0 -c "$TEMP_DIR/$BACKUP_FILENAME" > /tmp/gpg.txt 2>/tmp/gpg_e.txt
  if [[ ! -e "$TEMP_DIR/$BACKUP_FILENAME.gpg" ]]; then
    script_exit_error "gpg file not exist: $BACKUP_FILENAME.gpg"
  fi
  mv "$TEMP_DIR/$BACKUP_FILENAME.gpg" "$BACKUP_DIR/"
else
  # non-encrypt archive
  export $COMPRESS_PARAMS; tar $TAR_PARAMS "$BACKUP_DIR/$BACKUP_FILENAME" "$GITOLITE_REPO_DIR"
  if [[ ! -e "$BACKUP_DIR/$BACKUP_FILENAME" ]]; then
    script_exit_error "backup file not exist: $BACKUP_FILENAME"
  fi
fi
script_exit_ok "backup complete: $BACKUP_FILENAME"
