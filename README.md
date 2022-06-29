# Traffic Mirroring using VXLAN

VXLAN can be used to send mirrored traffic from a Linux server to a network
traffic analytics tool.  This can be achieved by attaching a 2nd network
interface to the server and setting up a VXLAN tunnel.  Traffic from the primary
interface can be sent through the VXLAN tunnel to a remote endpoint for
monitoring and analysis.

The Bash script [vxlan-setup.sh](vxlan-setup.sh) automates the VXLAN setup
process on Debian 11.  The script has been tested in AWS with a t2.micro
instance.

## Usage

1. Start the instance with only the primary network interface attached.
2. Run `vxlan-setup.sh` without any arguments:
   ```
   $ sudo ./vxlan-setup.sh
   ```
3. You will be prompted to attach a 2nd network interface.  Attach the
   interface and wait for setup to complete:
   ``` 
   Attach 2nd network interface (or Ctrl-C to quit):
     waiting for interface .........................................
     found eth1 172.31.2.206
   eth1 setup complete. Reboot.
   ```
4. Reboot instance.
5. Run `vxlan-setup.sh` a 2nd time, this time providing the IP address of the
   remote endpoint that will receive mirrored traffic:
   ```
   $ sudo ./vxlan-setup.sh 172.31.1.23
   Setting up VXLAN: remote IP 172.31.1.23
   VXLAN setup complete. Reboot.
6. Reboot instance.

VXLAN setup is now complete.

All traffic received or transmitted by the primary interface will be mirrored to
the remote monitoring tool, using the VXLAN tunnel created with the secondary
interface.
