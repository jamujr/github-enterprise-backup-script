#!/bin/sh
#
# Backup Script for GitHub Enterprise Server
#
# To use:
#   - ensure the server running this script has authorized ssh access
#   - update the custom variables below to fit your needs
#   - create cron job to run on a schedule
#
# created: 2013.05.17 by jamujr
# updated: 2013.05.17


# Custom variables
#
SERVER="server.domain.com"                         # This is the name or ip of our server.
GZNAME="github-enterprise-backup"                  # This is the name appended to the date for our zipped file.
FL2KEP=8                                           # This is the number of files to keep in the BAKUPS folder.
DIROUT="/media/backups/current/";                  # This is the directory where we output our backup files.
BAKUPS="/media/backups/githubbackup";              # This is the directory where we package the outputted files.


# Create our backup files
#
echo "1) Exporting GitHub Enterprise backup"
ssh "admin@"$SERVER "'ghe-export-authorized-keys'" > $DIROUT"authorized-keys.json"
ssh "admin@"$SERVER "'ghe-export-es-indices'" > $DIROUT"es-indices.tar"
ssh "admin@"$SERVER "'ghe-export-mysql'" | gzip > $DIROUT"enterprise-mysql-backup.sql.gz"
ssh "admin@"$SERVER "'ghe-export-redis'" > $DIROUT"backup-redis.rdb"
ssh "admin@"$SERVER "'ghe-export-repositories'" > $DIROUT"enterprise-repositories-backup.tar"
ssh "admin@"$SERVER "'ghe-export-settings'" > $DIROUT"settings.json"
ssh "admin@"$SERVER "'ghe-export-ssh-host-keys'" > $DIROUT"host-keys.tar"


# Package our files by the date
#
echo "2) Packaging the files"
CURRENT_DATE="$(date +%Y.%m.%d)";      # Finds the current date
mkdir -p $BAKUPS                       # Create backup folder if not already there for backup storage
FILENAME=$GZNAME"-"$CURRENT_DATE.tgz   # Generate our filename
tar -c $DIROUT | gzip > $FILENAME      # Compress our directory
mv $FILENAME $BAKUPS/                  # Moves our compressed file into the final backup folder


# Keeps the last 'FL2KEP' of files
#
echo "3) Location clean up"
cd $BAKUPS
for i in `ls -t * | tail -n+2`; do
ls -t * | tail -n+$(($FL2KEP + 1)) | xargs rm -f
done

# Exit our script
#
echo "--done--"
exit 0 
