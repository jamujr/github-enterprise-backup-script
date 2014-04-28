#!/bin/sh
#
# Backup Script for GitHub Enterprise Server
#
# To use:
#   - ensure the server running this script has authorized ssh access
#   - update the custom variables below to fit your needs
#   - create cron job to run on a schedule
#
#
# Note:
#   To use the Amazon S3 option you will need to install and configure
#   the s3cmd utility.  For Ubuntu 12.04 the following is useful:
#
# - import signing key
#   $ wget -O- -q http://s3tools.org/repo/deb-all/stable/s3tools.key | sudo apt-key add -
#
# - add repo to sources
#   $ sudo wget -O/etc/apt/sources.list.d/s3tools.list http://s3tools.org/repo/deb-all/stable/s3tools.list
#
# - refresh cache and install
#   $ sudo apt-get update && sudo apt-get install s3cmd
#
# - configure s3cmd
#   $ s3cmd --configure
#
# - Be sure to have your S3 bucket, access key, secret key, and encryption password ready!
# - Use the Amazon portal to adjust the 'Lifecycle' rules as needed.
#
#   To combine part-ed files back use the cat utility.
#   cat filename.part* > filename.tgz
#
#   Also please note that if using the s3cmd to upload files you will need to use the s3cmd
#   to download files since they are encrypted!!
#
# ref:
#   https://enterprise.github.com/help/articles/backing-up-enterprise-data
#   http://s3tools.org/s3cmd
#
#
# created: 2013.05.17 by jamujr
# updated: 2013.05.20
# version: 1.2

# Custom variables
#
SERVER=${SERVER:-"server.domain.com"}              # This is the name or ip of our server.
GZNAME=${GZNAME:-"github-enterprise-backup"}       # This is the name appended to the date for our zipped file.
FL2KEP=${FL2KEP:-8}                                # This is the number of files to keep in the BAKUPS folder.
DIROUT=${DIROUT:-"/backups/current/"}              # This is the directory where we output our backup files.
BAKUPS=${BAKUPS:-"/backups/archive"}               # This is the directory where we package the outputted files.
SLPTME=${SLPTME:-35}                               # This is the number of minutes to sleep while the export runs.


# Amazon S3 variables
#
USES3B=${USES3B:-false}                            # To enable Amazon S3 upload set to true. (must have s3cmd; see notes above)
S3FLDR=${S3FLDR:-"s3://your-s3-bucket-name"}       # This is the Amazon S3 Bucket location for uploads.
UPFLDR=${UPFLDR:-"/backups/upload/"}               # This is the directory where we stage files before uploading.
SPLTSZ=${SPLTSZ:-2}                                # This is the size in GB that we split files into before uploading.


# Save our script path
SCRIPTPATH=`pwd`


# Clean up our tmp folder for work space
rm -rf /tmp/*


# Create our backup files
#
echo "1) Exporting GitHub Enterprise backup"
ssh "admin@"$SERVER "'ghe-maintenance -s'"
ssh "admin@"$SERVER "'ghe-export-authorized-keys'" > $DIROUT"authorized-keys.json"
ssh "admin@"$SERVER "'ghe-export-es-indices'" > $DIROUT"es-indices.tar"
ssh "admin@"$SERVER "'ghe-export-mysql'" | gzip > $DIROUT"enterprise-mysql-backup.sql.gz"
ssh "admin@"$SERVER "'ghe-export-redis'" > $DIROUT"backup-redis.rdb"
ssh "admin@"$SERVER "'ghe-export-settings'" > $DIROUT"settings.json"
ssh "admin@"$SERVER "'ghe-export-ssh-host-keys'" > $DIROUT"host-keys.tar"
ssh "admin@"$SERVER "'ghe-export-repositories'" > $DIROUT"enterprise-repositories-backup.tar"
ssh "admin@"$SERVER "'ghe-export-pages'" > $DIROUT"enterprise-pages-backup.tar"
sleep $SLPTME"m"
ssh "admin@"$SERVER "'ghe-maintenance -u'"


# Package our files by the date
#
echo "2) Packaging the files"
CURRENT_DATE="$(date +%Y.%m.%d)"       # Finds the current date
mkdir -p $BAKUPS                       # Create backup folder if not already there for backup storage
FILENAME=$GZNAME"-"$CURRENT_DATE.tgz   # Generate our filename
cd $DIROUT                             # Jump into folder so the verify in tar can see files within
tar cvfW $FILENAME *                   # Create our tar image
mv $FILENAME $BAKUPS/                  # Moves our compressed file into the final backup folder
cd $SCRIPTPATH                         # Jump back to our script folder


# Keeps the last 'FL2KEP' of files
#
echo "3) Location clean up"
cd $BAKUPS
for i in `ls -t * | tail -n+2`; do
ls -t * | tail -n+$(($FL2KEP + 1)) | xargs rm -f
done


# Backup to Amazon S3
#
if $USES3B ; then
   echo "4) Uploading to S3 Bucket"
   case $BAKUPS in */) BAKUPS="$BAKUPS";; *) BAKUPS="$BAKUPS/";; esac   # ensure our path ends with /
   case $S3FLDR in */) S3FLDR="$S3FLDR";; *) S3FLDR="$S3FLDR/";; esac   # ensure our path ends with /
   case $UPFLDR in */) UPFLDR="$UPFLDR";; *) UPFLDR="$UPFLDR/";; esac   # ensure our path ends with /
   mkdir -p $UPFLDR                                                     # ensure our upload folder is created
   rm -rf $UPFLDR*                                                      # ensure our upload folder is clean
   split -b $SPLTSZ"G" $BAKUPS$FILENAME $UPFLDR$FILENAME".part-"        # split our file so s3cmd will not choke
   s3cmd put --encrypt --recursive $UPFLDR $S3FLDR                      # use s3cmd to send files to s3 storage
fi

# Do some clean up
#
rm -rf $UPFLDR*                        # clean up our upload folder
rm -rf /tmp/*                          # clean up any left overs in tmp

# Exit our script
#
echo "--done--"
exit 0
