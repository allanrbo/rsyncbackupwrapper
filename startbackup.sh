#!/bin/bash

function runBackup() {
    if [ "$#" -ne 5 ]; then
        echo "wrong arg count"
        return 1
    fi

    ssh_key=$1
    ssh_port=$2
    ssh_user_host=$3
    remote_src_dir=$4
    local_dst_dir=$5

    echo "Running backup from $ssh_user_host:$remote_src_dir to $local_dst_dir"

    # Dont run if already currently running.
    if ps aux | grep rsync | grep $local_dst_dir > /dev/null 2>&1 ; then
        echo "Already running. Exiting."
        exit 0;
    fi

    backups=$local_dst_dir
    mkdir -p $backups

    # If there was a previous successful backup, then let rsync use it for hard linking, for deduplication.
    latest=$(ls -1 --reverse $backups | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}_[0-9]{2}_[0-9]{2}\$" | head -1)
    link_dest_arg=
    if [[ "$latest" != "" ]]; then
        echo "Latest successful backup: $latest"
        link_dest_arg="--link-dest $backups/$latest"
    fi

    date=`date "+%Y-%m-%dT%H_%M_%S"`
    dst=$backups/incomplete_$date

    # If there was more than one previously incomplete backup, remove all but newest.
    ls -1 $backups | grep -E "^incomplete_[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}_[0-9]{2}_[0-9]{2}\$" | head -n -1 | while read line; do rm -fr $backups/$line ; done

    # If there was a previously incomplete backup and it was newer than newest successful backup, then resume it.
    incomplete=$(ls -1 --reverse $backups | grep -E "^incomplete_[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}_[0-9]{2}_[0-9]{2}\$" | head -1)
    if [[ "$incomplete" != "" ]]; then
      if [[ $(echo $incomplete | sed 's/incomplete_//g') > "$latest" ]]; then
        echo "Resuming incomplete backup: $incomplete. Renaming $incomplete to incomplete_$date."
        mv "$backups/$incomplete" $dst
      else
        echo "Incomplete backup $incomplete was older than latest backup. Deleting."
        rm -fr "$backups/$incomplete"
      fi
    fi

    rsync -aP \
      --delete \
      $link_dest_arg \
      --no-perms \
      --no-owner \
      --no-group \
      -e "ssh -i $ssh_key -p $ssh_port" \
      $ssh_user_host:$remote_src_dir/ \
      $dst/ && \
    mv $dst $backups/$date

    # Delete old. Just keep 20 newest.
    ls -1 $backups | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}_[0-9]{2}_[0-9]{2}\$" | head -n -20 | while read line; do  find $backups/$line -type d -exec chmod 755 '{}' \; ;  rm -fr $backups/$line ; done
    # TODO optimization: instead of just deleting an old dir, we could have reused it in the top of the script, and let rsync update it for us.
}

date
ssh_key="/home/user1/.ssh/id_rsa_backupserver1_to_myserver1"
ssh_port="31272"
ssh_user_host="user1@myserver1.example.com"
remote_src_dir="/srv/myfiles"
local_dst_dir="/srv/backups/myfiles"
runBackup $ssh_key $ssh_port $ssh_user_host $remote_src_dir $local_dst_dir
date
