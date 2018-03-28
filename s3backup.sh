#!/bin/bash
#
# Backup to AWS S3
# written by adimicoli@hotmail.com - May 2016
#

bucket=s3backups
database=databasename
folder=foldername
day=$(date +%H_%u)
date=$(date +%Y_%m_%d_%H)
dumpfile="databasename_${date}.dump"
log=/var/log/backups/"${dumpfile}.log"

echo "Backup Started $(date)" >> $log

pg_dump -Fc -U postgres $database -f $dumpfile
if [ "$?" -ne "0" ]; then
    echo "Cannot create $dumpfile file, please investigate" >> $log
else
    echo "$dumpfile file create with success!!" >> $log
    dumpexit=0
fi

gpg -e -r ServerAdmin ${dumpfile}
if [ "$?" -ne "0" ]; then
    echo "Cannot create $dumpfile.gpg file, please investigate" >> $log
else
    echo "$dumpfile.gpg file create with success!!" >> $log
    gpgexit=0
fi

/usr/local/bin/aws s3 cp --quiet ${dumpfile}.gpg s3://$bucket/$folder/${dumpfile}.gpg
if [ "$?" -ne "0" ]; then
    echo "Upload ./${dumpfile}.gpg to AWS failed, please investigate" >> $log
else
    echo "Upload ./${dumpfile}.gpg to AWS has been completed with successful!!" >> $log
    uploadexit=0
fi

if [ $day = 09_1 ]; then
    /usr/local/bin/aws s3 sync --quiet s3://$bucket/$folder/ s3://$bucket/backupstorage/$folder --exclude "*" --include "${dumpfile}.gpg"
fi

echo "Bachup Finished $(date)" >> $log

if [ -z $dumpexit ] || [ -z $gpgexit ] || [ -z $uploadexit ]; then
    mailaddr=admin@domain.com
    status=Failed
else
    mailaddr=support@domain.com
    status=Success
fi

mail -s "AWS S3 Backup $database Database - $status" $mailaddr < $log
find /var/log/backups -name "${folder}_*.log" -ctime +3 -delete
rm ${dumpfile}.gpg
rm ${dumpfile}
