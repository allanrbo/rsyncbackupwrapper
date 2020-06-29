# rsyncbackupwrapper

Rsync for backup, one directory per day, deduplication with hard links.

This script is designed to run on the destination backup server. It connects to the server you are backing up via SSH keys.

Copy startbackup.sh to your backup server. Customize the values in the top.
