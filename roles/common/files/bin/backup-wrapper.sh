#!/bin/bash
# vim: set expandtab ts=4 sw=4 sts=4

# Check format with shfmt -i 4 -d <filename>

CMD="/usr/local/bin/autorestic"

# Function to prepend date/time to each line
prepend_datetime() {
    while IFS= read -r line; do
        printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$line"
    done
}

# Redirect stdout and stderr to logfile with date/time prepended
exec 3>&1
exec 4>&2 #save stderr
exec 1> >(prepend_datetime >>/tmp/backup-wrapper.log)
exec 2> >(prepend_datetime >&4) #send stderr to the saved stderr file descriptor.
echo "------------------------- Starting -------------------------"

# Set config location
if [ -f /etc/autorestic/autorestic.yml ]; then
    OPTS="-c /etc/autorestic/autorestic.yml "
else
    OPTS="-c ${HOME}/.autorestic.yml "
fi
# Use specific binary if available
if [ -x /usr/local/bin/restic ]; then
    OPTS+=" --restic-bin /usr/local/bin/restic "
fi
# Specify command and location
OPTS+=" backup -l hp-data@scalewayhp"

VAR_DIR="/var/opt/backup"
LAST_BACKUP_FILE="${VAR_DIR}/_last_backup"

check_last_run() {
    # returns 0 if file is older than 24 hours or does not exist.
    # otherwise returns 1

    fname=$1

    [[ -d "${VAR_DIR}" ]] || mkdir -p "${VAR_DIR}"

    # check existence
    [[ -f "$fname" ]] || return 0

    # find files older than 24 hours
    num=$(find "${VAR_DIR}" -wholename "$fname" -mmin +1440 | wc -l)

    # trim whitespaces
    num=$((num))

    if [[ "$num" -gt 0 ]]; then
        echo "$fname is 24 hours or older"
        return 0
    else
        #echo "$fname is newer than 24 hours."
        return 1
    fi
}

test_last_run() {
    # set ctime/mtime to 24 hours ago
    touch -t "$(date --date '-24 hours' '+%Y%m%d%H%M')" "${VAR_DIR}/_last_backup"
    check_last_run _last_backup

    # set ctime/mtime to 23 hours ago
    touch -t "$(date --date '-23 hours' '+%Y%m%d%H%M')" "${VAR_DIR}/_last_backup"
    check_last_run _last_backup
}

check_last_run $LAST_BACKUP_FILE
RC=$?
if [[ $RC = 0 ]]; then
    # LAST_BACKUP_FILE is older than 24 hours
    # OR does not exist
    echo "Starting backup: $CMD ${OPTS}"
    if "$CMD" ${OPTS}; then
        # update hc-ping if successful
        curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/ef99ad0d-556d-4894-b148-edb3daffe986
    else
        echo "RC: $?"
        curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/ef99ad0d-556d-4894-b148-edb3daffe986/fail

    fi
    # update timestamp even if backup failed.
    # For *me*, it is sufficient to restart a failed job once a day.
    # Otherwise, my mailbox gets flooded in case of transient errors such as a network failure
    touch -t "$(date -d '06:00' '+%Y%m%d%H%M')" "${LAST_BACKUP_FILE}"
else
    # echo "Last backup less than 24 hours ago. Will not start backup now."
    true
fi
echo "------------------------- End      -------------------------"
