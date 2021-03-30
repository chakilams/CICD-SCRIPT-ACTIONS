#!/bin/sh

# Parameters:
# 1. cluster type (default and only option right now = spark)
# 2. secondary storage url

# Example: 
# STORAGE_URL="wasb://sparkcon-2020-08-03t18-17-37-853z@sparkconhdistorage.blob.core.windows.net"
# CLUSTER_TYPE="spark"

trap "Clean_up" 0 1 2 3 13 15 # EXIT HUP INT QUIT PIPE TERM

# redirect script output to system logger with file basename
exec 1> >(logger -s -t $(basename $0)) 2>&1

Help()
{
   echo ""
   echo "Example Usage: $0 -s wasb://sparkcon-2020-08-03t18-17-37-853z@sparkconhdistorage.blob.core.windows.net"
   echo -e "\t-s secondary_url"
   exit 1 # Exit script after printing help
}

Parameter_Checks_Node_Select()
{
    # check to make sure storage account and container are provided
    if [[ -z "${STORAGE_URL}" ]]; then
        echo "Connector HBase: Secondary storage url required."
        Help
        exit 1
    else
        # make sure only one wn is completing the work
        hostname > /tmp/shc-lock
        sudo timeout 15 hdfs dfs -copyFromLocal /tmp/shc-lock /tmp && LOCK_ACQUIRED=true || LOCK_ACQUIRED=false
        if [ "$LOCK_ACQUIRED" = false ]; then
            echo "Connector HBase: set up will be performed by another worker node in this cluster. Exiting..."
            exit 0
        fi
    fi
}

# remove key & lock & tmp files if exists
Clean_up()
{
    exit_status=$?
    sudo rm -f /tmp/shc-lock
    sudo rm -f /tmp/hbase-hostname
    sudo rm -f /tmp/hbase-etc-hosts
    if [ "$LOCK_ACQUIRED" = true ]; then
        sudo hdfs dfs -rm -f /tmp/shc-lock
        if [[ ! -z "${STORAGE_URL}" && ! "$exit_status" = 0 ]]; then
            sudo timeout 15 hdfs dfs -rm -r -f $STORAGE_URL/shc/
            echo "Connector HBase: set up failed, removing folders on secondary storage location $STORAGE_URL. "
        fi
    fi
    echo "Connector HBase: Clean up temporary files. Exitting with code $exit_status."
    exit "$exit_status"
}

Spark_Flow()
{ 
     #  take ip mapping in /etc/hosts file and copy to a temporary file
    sudo rm -f /tmp/hbase-etc-hosts
    sed -n '/ip6-allhosts/,$p' /etc/hosts | sed '1d' >> /tmp/hbase-etc-hosts

    # get hostname of the cluster
    sudo rm -f /tmp/hbase-hostname
    sudo hostname | cut -d '-' -f2 >> /tmp/hbase-hostname

    # set timeout, if failed after 15 seconds print error msg, copy one file first to identify the first and only wn 
    # allowed to perform this the rest of the script
    echo "Connector HBase: Copying hbase IP mapping, hostname, current time to secondary storage account $STORAGE_URL... "
    if [[ "$(hostname -f)" == *"securehadooprc"* ]]; then
        uploadFiles="/etc/hbase/conf/hbase-site.xml /tmp/hbase-etc-hosts /tmp/hbase-hostname"
    else
        uploadFiles="/etc/hbase/conf/hbase-site.xml /tmp/hbase-hostname"
    fi
    sudo timeout 15 hdfs dfs -mkdir -p $STORAGE_URL/shc/
    sudo timeout 15 hdfs dfs -copyFromLocal -f $uploadFiles \
        $STORAGE_URL/shc/ && TIMED_OUT=false || TIMED_OUT=true
    if [ "$TIMED_OUT" = true ]; then
        echo "Connector HBase: File upload to $STORAGE_URL timed out. Make sure the correct Spark storage account has been added to HBase as secondary storage account."
        exit 1
    fi
}

# ======================================= MAIN =======================================

echo "Connector HBase: Set up begins..."

CLUSTER_TYPE="spark"
# get script parameters
while getopts "s::t::" opt
do
    case "$opt" in
        s ) STORAGE_URL="$OPTARG" ;;
        t ) CLUSTER_TYPE="$OPTARG" ;;
        ? )
            Help
            exit 0
            ;;
    esac
done

# check script parameters & select node to perform file uploads
Parameter_Checks_Node_Select

case "${CLUSTER_TYPE,,}" in
    "spark" )
        Spark_Flow
        ;;
    * )
        echo "Connector HBase: The cluster type you've entered is not supported by this script."
        exit 1 
        ;;
esac

echo "Connector HBase: Set up completed successfully. "
exit 0
