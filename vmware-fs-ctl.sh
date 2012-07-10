#!/bin/bash

# This is a start|stop|restart|status script for running a headless OS in VmWare Fusion on OSx.
# It will also handle mounting/unmounting of the OS´s root filesystem.
#
# It might work well on other *nix systems whith small modifications. Be sure to 
# check location of vmrun executable at least.
#
# vmrun manual http://www.vmware.com/pdf/vix180_vmrun_command.pdf
# Related tips http://communities.vmware.com/message/1648085
#
# Creds go out to David Tiselius for the nicely working mount command details,
# and WoodyZ of VmWare community fame http://communities.vmware.com/people/WoodyZ
# for the details on tailoring your VM for headless use.


# ------------------------------------------------------------
# Setup Environment
# ------------------------------------------------------------
# Where are the VmWare image located?
readonly VMWARE_IMAGE="/Users/martin/Virtual-machines/testserver.vmwarevm/testserver.vmx"
# What local mountpoint to use for the OS´s root filesystem?
readonly FS_MOUNTPOINT="/Users/martin/Volumes/deveditor"
# Location of vmrun executable should not need alteration on standard OSx VmWare Fusion install,
# but check location of vmrun in case your system varies from that.
readonly VMRUN="/Library/Application Support/VMware Fusion/vmrun"


# ------------------------------------------------------------
# Internal defaults
# ------------------------------------------------------------
ROUTE=$1
RUNNING_IMAGES=`sudo "$VMRUN" -T ws list`
VM_RUNNING=0
FS_MOUNTED=0


# Sets the two variables $VM_RUNNING and $FS_MOUNTED that
# indicates wheather guest OS is running an if its fs is mounted
status() {
    # Check to see if $VMWARE_IMAGE is in the list of running images.
    if [[ "$RUNNING_IMAGES" =~ "$VMWARE_IMAGE" ]]
    then
        VM_RUNNING=1
        #  Check to see if fs is also mounted?
        MOUNTED=`mount`
        if [[ "$MOUNTED" =~ "$FS_MOUNTPOINT" ]]
        then
            FS_MOUNTED=1
        fi
    fi
}

# Starts the guest OS and if sucessfull,
# proceeds to mounting routine.
runGuest() {
    # If image is not already running.
    if [[ "$VM_RUNNING" == 0 ]]
    then
        echo "STARTING GUEST OS: In progress ..."
        # Actual start command using vmrun
        "$VMRUN" -T fusion start "$VMWARE_IMAGE" nogui
        # Now we will probe vmware to see if the image got to a start,
        # but before that, give vmware some gracetime to be able to initialize.
        # Have never seen a successful start actually being missed by the "list"-command
        # som a "sleep" might not even be needed.
        sleep 1s
        RUNNING_IMAGES=`"$VMRUN" -T ws list`
        if [[ "$RUNNING_IMAGES" =~ "$VMWARE_IMAGE" ]]
        then
            VM_RUNNING=1
            echo "STARTING GUEST OS: Success."
            mountFs
        else
            echo "STARTING GUEST OS: Failed!"
        fi
    # Image is running since before, go to mount.
    else
        echo "STARTING GUEST OS: Already running, going to mount ..."
        mountFs
    fi
}

# Starts by calling unmount routine then stops guest OS.
stopGuest() {
    unMountFs
    echo "STOPPING GUEST OS: ..."
    if [[ "$VM_RUNNING" == 1 ]]
    then
        STOP_RESULT=`"$VMRUN" -T fusion stop "$VMWARE_IMAGE"`
        if [[ $STOP_RESULT -eq 0 ]]
        then
            VM_RUNNING=0
            echo "STOPPING GUEST OS: Success."
        else
            echo "STOPPING GUEST OS: Opps, something vent wrong when halting."
        fi
    else
        echo "STOPPING GUEST OS: Guest OS is not running."
    fi
}

# Trying to mount the guest OS fs at $FS_MOUNTPOINT
# Only to be run by 'runGuest'
mountFs() {
    # First check if vm is running.
    if [[ "$VM_RUNNING" == 1 ]]
    then
        # Then check if is already mounted
        if [[ "$FS_MOUNTED" == 0 ]]
        then
            # If not, try mounting.
            echo "MOUNT: In progress. This might take some time if OS is starting up."
            MOUNT_RESULT=`sudo mount -t nfs -o hard,intr -o -P deveditor:/ "$FS_MOUNTPOINT"`
            if [[ $MOUNT_RESULT -eq 0 ]]
            then
                FS_MOUNTED=1
                echo "MOUNT: Success. mountpoint: $FS_MOUNTPOINT"
            else
                echo "MOUNT: Opps, something vent wrong."
            fi
        else
            echo "MOUNT: Already mounted."
        fi
    else
        echo "MOUNT: Not mounted, guest OS is not running."
    fi
}

# Trying to unmount the guest OS fs from $FS_MOUNTPOINT
# Only to be run by 'stopGuest'
unMountFs() {
    # First check if vm is running.
    if [[ "$VM_RUNNING" == 1 ]]
    then
        # Then check if fs is actually mounted.
        if [[ "$FS_MOUNTED" == 0 ]]
        then
            echo "UNMOUNT: In progress ..."
            UNMOUNT_RESULT=`sudo umount -f "$FS_MOUNTPOINT"`
            if [[ $UNMOUNT_RESULT -eq 0 ]]
            then
                FS_MOUNTED=0
                echo "UNMOUNT: Success"
            # else
                # Skipping output, umount will output a gracefull errormessage by itself.
                # echo "UNMOUNT: Opps, something vent wrong when unmounting."
            fi
        else
            echo "UNMOUNT: Fs not mounted"
        fi
    else
        echo "UNMOUNT: Guest OS not running."
    fi
}

# Prints out the result of "status" in a readable maner.
echoStatus() {
    # OS running?
    if [[ "$VM_RUNNING" == 1 ]]
    then
        echo "Guest OS is running. ($VMWARE_IMAGE)"
    else
        echo "Guest OS is NOT running. (missleading if not run via sudo)"
    fi
    # Mounted?
    if [[ "$FS_MOUNTED" == 1 ]]
    then
        echo "Guest OS filesystem mounted. ($FS_MOUNTPOINT)"
    else
        echo "Guest OS filesystem is NOT mounted. (missleading if not run via sudo)"
    fi
}


# First of all, determine status
status

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
        echo "Usage: [sudo] start-fusion-dev {start|stop|restart|status}"
    ;;
esac
