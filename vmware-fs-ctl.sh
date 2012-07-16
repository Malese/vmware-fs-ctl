#!/bin/bash

# This is a start|stop|restart|status bash script for running a headless OS in VmWare Fusion on OSx.
# It will also handle mounting/unmounting of the OS´s root filesystem.
# On first run, it will create a directory and a history and error log-file.
#
# It might work well on other *nix systems whith small modifications. Be sure to 
# check location of vmrun executable at least.
# Currently not POSIX-compatible due to [[ .. ]] tests for example.
#
# vmrun manual http://www.vmware.com/pdf/vix180_vmrun_command.pdf
# Related tips http://communities.vmware.com/message/1648085
#
# Creds go out to David Tiselius for the nicely working mount command details,
# and WoodyZ of VmWare community fame http://communities.vmware.com/people/WoodyZ
# for the details on tailoring your VM for headless use.


# ------------------------------------------------------------
# Setup Environment, make your changes here.
# ------------------------------------------------------------
# Where are the VmWare image located? .vmx-file or similar.
readonly VMWARE_IMAGE="/Users/martin/Virtual-machines/testserver.vmwarevm/testserver.vmx"
# What local mountpoint to use for the OS´s root filesystem?
readonly FS_MOUNTPOINT="/Users/martin/Volumes/deveditor"
# Location of vmrun executable should not need alteration on standard OSx VmWare Fusion install,
# but check location of vmrun in case your system varies from that.
readonly VMRUN="/Library/Application Support/VMware Fusion/vmrun"
# Log files. Changes are optional.
# A directory $LOG_IN_DIR/vmware-fs-ctl will be created.
readonly LOG_IN_DIR="/var/log"


# ------------------------------------------------------------
# Internal defaults
# ------------------------------------------------------------
ROUTE=
QUIET=0
LOG_DIR=$LOG_IN_DIR/vmware-fs-ctl


validateArgs() {
    for p in "$@"
    do
        case $p in
            "start")
                ROUTE=$p
            ;;
            "stop")
                ROUTE=$p
            ;;
            "restart")
                ROUTE=$p
            ;;
            "status")
                ROUTE=$p
            ;;
            "q")
                QUIET=1
            ;;
        esac
    done
}

init() {
    # Create log-dir if not already there
    [[ ! -d $LOG_DIR ]] && mkdir $LOG_DIR
    # Create log-files if not already there
    if [[ -d $LOG_DIR ]]
    then
        [[ ! -f $LOG_DIR/history.log ]] && { touch $LOG_DIR/history.log; message "Creating history-logfile. This message should reside in file $LOG_DIR/history.log if all went well."; }
        [[ ! -f $LOG_DIR/error.log ]] && { touch $LOG_DIR/error.log; message "Creating error-logfile. There should now be a file $LOG_DIR/error.log if all went well."; }
    else
        echo "Error: Could not create log-files directory $LOG_DIR. Permissions?"
        exit
    fi
}

# Output to stdout and history-log.
message() {
    [ $QUIET -eq 0 ] && echo $1
    echo $(date) $1 >> $LOG_DIR/history.log
}

# Starts the guest OS and if sucessfull,
# proceeds to mounting routine.
runGuest() {
    # If image is not already running.
    "$VMRUN" -T ws list|grep -q "$VMWARE_IMAGE"
    if [ $? -eq 0 ]
    then  
        # Image is running since before, go to mount.
        message "STARTING GUEST OS: Already running, going to mount ..."
        mountFs
    else
        message "STARTING GUEST OS: In progress ..."
        # Actual start command using vmrun
        # Errors from vmrun goes to STDOUT instead of STDERR, and successfull
        # operation does not give output, so every return message goes to error.log
        "$VMRUN" -T fusion start "$VMWARE_IMAGE" nogui 2>&1> $LOG_DIR/error.log
        # Now we will probe vmware to see if the image got to a start,
        # but before that, give vmware some gracetime to be able to initialize.
        # Have never seen a successful start actually being missed by the "list"-command
        # so a "sleep" might not even be necessary.
        sleep 1s
        "$VMRUN" -T ws list|grep -q "$VMWARE_IMAGE"
        if [ $? -eq 0 ]
        then
            message "STARTING GUEST OS: Success."
            mountFs
        else      
            message "STARTING GUEST OS: Failed! see $LOG_DIR/error.log"
        fi
    fi
}

# Starts by calling unmount routine then stops guest OS.
stopGuest() {
    "$VMRUN" -T ws list|grep -q "$VMWARE_IMAGE"
    if [ $? -eq 0 ]
    then
        unMountFs
        message "STOPPING GUEST OS: ..."
        "$VMRUN" -T fusion stop "$VMWARE_IMAGE" 2>&1> $LOG_DIR/error.log
        if [ $? -eq 0 ]
        then
            message "STOPPING GUEST OS: Success."
        else
            message "STOPPING GUEST OS: Failed! see $LOG_DIR/error.log"
        fi
    else
        message "STOPPING GUEST OS: Guest OS is not running."
    fi
}

# Trying to mount the guest OS fs at $FS_MOUNTPOINT
# Only to be run by 'runGuest'
mountFs() {
    # Check if is already mounted
    mount|grep -q "$FS_MOUNTPOINT"
    if [ $? -eq 0 ]
    then
        message "MOUNT: Already mounted."
    else    
        # If not, try mounting.
        message "MOUNT: In progress. This might take some time if OS is starting up."
        mount -t nfs -o hard,intr -o -P deveditor:/ "$FS_MOUNTPOINT" 2> $LOG_DIR/error.log
        if [ $? -eq 0 ]
        then
            message "MOUNT: Success. mountpoint: $FS_MOUNTPOINT"
        else
            message "MOUNT: Error mounting, see $LOG_DIR/error.log"
        fi
    fi
}

# Trying to unmount the guest OS fs from $FS_MOUNTPOINT
# Only to be run by 'stopGuest'
unMountFs() {
    # Check if fs is actually mounted.
    mount|grep -q "$FS_MOUNTPOINT"
    if [ $? -eq 0 ]
    then
        message "UNMOUNT: In progress ..."
        umount -f "$FS_MOUNTPOINT" 2> $LOG_DIR/error.log
        if [ $? -eq 0 ]
        then
            message "UNMOUNT: Success"
        else
            message "UNMOUNT: Error unmounting, see $LOG_DIR/error.log"
        fi
    else
        message "UNMOUNT: Fs was not mounted"
    fi
}

# Prints out the result of "status" in a readable maner.
echoStatus() {
    # OS running?
    "$VMRUN" -T ws list|grep -q "$VMWARE_IMAGE"
    if [ $? -eq 0 ]
    then
        message "Guest OS is running. ($VMWARE_IMAGE)"
    else
        message "Guest OS is NOT running. (missleading if not run via sudo)"
    fi
    # Mounted?
    mount|grep -q "$FS_MOUNTPOINT"
    if [ $? -eq 0 ]
    then
        message "Guest OS filesystem mounted. ($FS_MOUNTPOINT)"
    else      
        message "Guest OS filesystem is NOT mounted. (missleading if not run via sudo)"
    fi
}


# Parse arguments
validateArgs $@

# Create logfiles if they dont already exists.
init


case $ROUTE in
    "start")
        runGuest
    ;;
    "stop")
        stopGuest
    ;;
    "restart")
        stopGuest
        runGuest
    ;;
    "status")
        echoStatus
    ;;
    *)
        message "Usage: sudo start-fusion-dev {start|stop|restart|status} [q]"
    ;;
esac
