#!/bin/bash
# Patching for bug fix - https://msdata.visualstudio.com/HDInsight/_git/granola/pullrequest/434016

set -eux
scriptName="fix_hdinsightlogging.sh"
versionNumber="2.0"
logger -p user.info "$scriptName $versionNumber - Starting."

fix_hdinsightlogging_bug() {
    logger -p user.info "$scriptName $versionNumber - Fixing bug in $1."
    if grep -Fq "if enable_console_logger and not stream_handler_found:" $1; then
        logger -p user.info "$scriptName $versionNumber - File $1 is already patched."
        return 0
    fi

    sudo sed -i 's/if stream_handler_found and syslog_handler_found:/if not syslog_handler_found:/' $1
    sudo sed -i '/if not syslog_handler_found:/{n;N;d}' $1
    sudo sed -i 's/#add syslog handler if we are on linux./\t#add syslog handler if we are on linux./' $1
    sudo sed -i 's/    _add_syslog_handler_with_retry(logger, syslog_facility)/\t_add_syslog_handler_with_retry(logger, syslog_facility)/' $1
    sudo sed -i 's/if enable_console_logger:/if enable_console_logger and not stream_handler_found:/' $1
    logger -p user.info "$scriptName $versionNumber - Completed fixing bug in $1."
}

file_list=$(sudo find /usr -name "hdinsightlogging.py")
for file in $file_list
do
    fix_hdinsightlogging_bug $file
done


logger -p user.info "$scriptName $versionNumber - Completed. Restarting Ambari-agent..."
(sleep 6; kill -9 $(cat /var/run/ambari-agent/ambari-agent.pid)) &
