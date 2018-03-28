#!/bin/bash
#
# 
#
# tmp to store downloaded files
tmpstore=/tmp/pgrestore
awsfile=~/.aws/config
mkdir -p $tmpstore
chmod 777 $tmpstore

# provide give more info
function info {
  echo "More info..."
  echo "https://sites.google.com/a/researchresearch.com/technical/internal-it/backups/s3backup"
}

# provide to configure AWS Access
function configurecli { 
  local checkid=$(grep "XXXXXXXXXXXXXXXXX" $awsfile 2>/dev/null)
  if [ -e "$awsfile" -a ! -z "$checkid" ] # if file exists and contains the right config
  then
    echo "AWS User Id installed correctly..."
  else
    echo -n "Configuring aws..."
    mkdir ~/.aws
    touch $awsfile
   if [[ $? -ne 0 ]]
   then
     echo "Cannot create config file $awsfile, please investigate"
     exit 3
   fi
   echo "[profile s3backup]" >> $awsfile
   echo "aws_access_key_id = XXXXXXXXXXXXXXXXX" >> $awsfile
   echo "aws_secret_access_key = zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz" >> $awsfile
   echo "region = eu-est-1" >> $awsfile
   echo "completed."
  fi
}

# provide install cli if required
function installcli {
  echo "More info..."
  echo "http://docs.aws.amazon.com/cli/latest/userguide/installing.html"
  oscheck="$(uname)"
  if [[ "$oscheck" == "Linux" ]]
    then
    read -n1 -r -p 'Press any key to Install the AWS CLI Using Pip or Ctrl-C to Cancel....'
    sudo apt-get update
    sudo apt-get -y install python-pip
    sudo pip install awscli
    configurecli
  elif [[ "$oscheck" == "Darwin" ]]
  then
    read -n1 -r -p 'Press any key to Install the AWS CLI using the bundled installer or Ctrl-C to Cancel....'
    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
    unzip awscli-bundle.zip
    sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
    configurecli
  else    
    echo "No Linux or Apple"
  fi
}

# ensure aws cli installed and sensible version
function checkcli {
  local awscheck=$(aws --version 2>&1 | awk '{print $1}')
  # split up version string
  local awscliver="${awscheck##aws-cli/}"
  local awscliversion="${awscliver%\.*}"  # removes patch version as we don't care
  local awsclimajor="${awscliversion%%\.*}"
  local awscliminor="${awscliversion##*\.}"
  # check major version >1  OR (major version is 1 and minor version is >10)
  if [ "$awsclimajor" -gt "1" -o "$awsclimajor" -eq "1" -a "$awscliminor" -gt "9" ]
  then
    echo "aws-cli installed"
  else
    echo "aws cli > 1.10 required..."
    installcli
  fi
}

# ensure gpg installed
function checkgpg {
  oscheck="$(uname)"
    if [[ "$oscheck" == "Darwin" ]]
      then
      gpgcheck="$(gpg --version 2>&1)"
      if [ "$?" -ne "0" ]
        then
        echo "GnuPG required..."
        echo "Install GPG Suite https://gpgtools.org/"
        read -n1 -r -p 'Press any key to open your browser and downlaod GPG Suite'
        open https://gpgtools.org/
      exit
    fi
  fi
}

# Import GPG keys
function importgpg {
  checkgpg
  checkkey=$(gpg --list-secret-key | grep Admin | awk 'END { print $NF }')
  if [[ "$checkkey" != "<admin@domain.com>" ]]
    then
    echo "Import GPG Key in progress..."    
    git archive --remote=git@git.domain.com:repository/utilityscripts.git HEAD:s3backup/key secring.gpg.tar.gz | tar -x
    if [[ "$?" != "0" ]]
      then
      echo "You must have access to Git..."
      exit
    fi
    tar -xzf secring.gpg.tar.gz
    gpg --import secring.gpg
    if [[ "$?" == "0" ]]
      then
      echo "GPG keys imported...."
      rm *.gpg*
    else
      echo "GPG keys failure (exit status $?)"
      rm *.gpg*
    fi
  else
    echo "GPG keyring are installed correctly."
  fi
}

# provide database list download options
function listdb {
  printf 'Please select one of the following database'
  echo
  echo "1) database1"
  echo "2) database2"
  echo "3) database3"
  echo "4) database4"

  read -r db

  case $db in
    database1|1)
      $0 database1
      ;;
    database2|2)
      $0 database2
      ;;
    database3|3)
      $0 database3
      ;;
    database4|4)
      $0 database4
      ;;
    *)
      echo "Unknown database..."
  esac
}

# provide help if asked
function usage {
  echo "$0 help                   - Shows this help."
  echo "$0 --listdb               - List Databases."
  echo "$0 --checkcli             - Check AWS CLI version."
  echo "$0 --installcli           - Install AWS CLI."
  echo "$0 --importgpg            - Check GPG installed and Import GPG Keys."
  echo "$0 <database>             - Download and decrypt specified database."
  echo
  info
  exit
}

db="$1"
bucket=s3backups

if [ "$1" == "--checkcli" ]; then checkcli ; exit ; fi
if [ "$1" == "--installcli" ]; then installcli ; exit ; fi
if [ "$1" == "--importgpg" ]; then importgpg ; exit ; fi
if [ "$1" == "--configurecli" ]; then configurecli ; exit ; fi  ##### only for testing
if [ "$1" == "--listdb" ]; then listdb ; exit ; fi

if [ "$1" == "-h" -o "$1" == "--help" -o "$1" == "help" -o "$1" == "" ]
  then
  usage
elif [ "$1" == "database1" -o "$1" == "database2" -o "$1" == "database3" -o "$1" == "database4" ]
  then

  # main
  
  checkcli
  importgpg

  echo "Processing $db..."

  # Setup AWS profile variable
  awsopts=
  if grep -q 's3backup' $awsfile
  then
    awsopts='--profile s3backup'
  fi

  # grab latest backup filename
  latestdata=$(aws s3 $awsopts ls s3://$bucket/$db/ | awk 'END { print $NF }')
      
  # if it failed $latestcheck should be non-zero and $latestdata should contain the error message
  if [ "$latestdata" == "" ]
    then
    echo "S3 connection error, does that database exist? ($db)."
    echo "Reported exit status ($latestcheck) and error;"
    exit
  fi

  # in theory we should now have the filename as the last text of the output
  latest=${latestdata##* }
  
  # check it's the right date
  echo "Using backup $latest."
  
  # grab the backup, should be near enough the right one
  echo "Attempting quiet download."
  aws s3 $awsopts cp s3://$bucket/$db/$latest $tmpstore/
  if [ "$?" == "0" ]; then 
    echo "Download Completed"
  else
    echo "Download failure (exit status $?)"
    exit
  fi
  
  # and decrypt move decypted file to local folder and clean up downloaded files
  echo "GPG Admin Passphrase in PasswordManager..."
  read -sp "Enter Passphrase: " pass
  echo "${pass}" | gpg --passphrase-fd 0 --batch -d --output $tmpstore/${latest%%.gpg} --decrypt $tmpstore/$latestdata
    if [ "$?" == "0" ]; then 
      echo "Decrypt Completed"
      cp ${tmpstore}/${latest%%.gpg} . 
      rm ${tmpstore}/${latest%%.gpg}*
  else
    echo "Decrypt failure (exit status $?)" 
    echo "Check the Secret and Public keyring are installed correctly."
    echo "Run $0 --importgpg"
    info
  fi
else
  listdb
fi
