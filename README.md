vmware-fs-ctl
=============

Summary
-------
vmware-fs-ctl.sh is a start|stop|restart|status shell script for running a headless OS in VmWare Fusion on OSx and handle  mounting/unmounting of the OS´s root filesystem exported via NFS. BSD licensed.

It might work well on other \*nix systems whith small modifications. In that case, be sure to at least set the *VMRUN* config variable pointing out the location of the vmrun executable.

About
-----
Goals:
* Run virtual machine (VM) in a local install of VmWare Fusion (VF) on OSx.
* Run the VF/VM headless. which get VF out of the way and makes it more smooth to operate on it via command line.
* Mount the virtual machine´s filesytem to a local mountpoint.
* Speed up start, stop, restart, mount and unmount.

vmware-fs-ctl.sh handles all this.


Prerequisites
-------------
* Turn off superflous features in VM settings for the VM you want to run headless that aren't needed like Accelerate 3D Graphics. Do not have headless Virtual Machines automatically connect to or be connected to unneeded devices.
* Have the VM you want to run headless set up and run normaly via VmWare library GUI and try to permanently take care of any dialog boxes tha pops up. Also put *msg.autoAnswer = "TRUE"* in the VM´s .vmx-file. That will try to autoanswer any dialogs.
* When running headless you need SSH or similar to be able to communicate with and controll the VM. If in trouble, the vmrun utillity has a lot up it´s sleave to handle the VM.
* Shutdown VM.
* Delete the VM from VmWare´s library GUI, but be sure to keep the file. It´s ok to move it in and out of there later on, at least when not running.
* Quit VmWare
* Add '''/Library/Application\ Support/VMware\ Fusion to your $PATH for access to vmrun executable in your shell.
* Test the headless mode in Terminal using: *"/Library/Application Support/VMware Fusion/vmrun" -T fusion start "/absolute/path/to/your/image.vmx" nogui*
* For convenience, put the script in a location in your $PATH. Or add it´s location to $PATH.

After customizing the *VMWARE_IMAGE*, *FS_MOUNTPOINT* and possibly the *VMRUN* variables in the script, making it executable:

`$ [sudo] chmod +x vmware-fs-ctl.sh`

the script should be usable:

`$ sudo vmware-fs-ctl.sh {start|stop|restart|status}`

To begin with, try out status with the VM turned off to se it is running without errors.



Resources
---------
vmrun manual http://www.vmware.com/pdf/vix180_vmrun_command.pdf
Related tips http://communities.vmware.com/message/1648085

Acknowledgements
----------------
Creds go out to David Tiselius for the nicely working mount command details, and WoodyZ of VmWare community fame http://communities.vmware.com/people/WoodyZ for the details on tailoring your VM for headless use.