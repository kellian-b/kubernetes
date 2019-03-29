# kubernetes
<h1>Deploy Kubernetes Cluster in a new subnet from scratch (with own PXE and DHCP server)</h1>
	<p><b>Hardware configuration</b></p>
	<ul>
		<li>1 Master server: 2GB RAM</li>
		<li>3 Slaves server: 1GB RAM</li>
		<li>1 Switch</li>
		<br>
	<li>OS: Ubuntu 18.04 Server LTS</li>
</ul>
<p><b>Network organization:</b></p>
	<ul>
		<li>Master: It welcome DHCP/PXE server, iptables script, LXC Remote Control, Ansible playbooks. It have 2 network interfaces (1 LAN & 1 WAN) and plays the gateway for slaves which will want to have Internet access</li>
		<li>Slaves: They will hosts LXC/Docker container to start services from scratch, allowing them to not loose ressources... </li>
		<li>Switch: It interconnect Master and Slaves</li>
	</ul>
<p><b>Tasks order:</b></p>
<p><i>PS: All steps are first done by hand to get used with the different tools. If you're not a beginner, you can directly go to the step 12, to automate all the previous one.</i></p>
<br>
	<ol>
		<li>Deploying OS on bare metal </li>
		<li>Configuring a DHCP server (on Master) which gives IP address to slaves</li>
		<li>Configuring iptables to allow Slaves to have Internet access</li>
		<li>SSH configuration with Password Authentication</li>
		<li>LXD install on slaves</li>
		<li>Configuring LXD Remote on Master</li>
		<li>Configuring a LXC profile which allows container to get IP address from the DHCP server</li>
		<li>SSH configuration with PubKey Authentication</li>
		<li>Configuring fail2ban to counter Brute Force attacks</li>
		<li>Configuring PXE/tftpd-hpa to automate installation from scratch</li>
		<li>Kubernetes Cluster install</li>
		<br>
		<li>Ansible: Let's do it again from scratch !</li>
  	</ol>
	

<h2>1- Deploying OS on bare metal </h2>
<p>Which OS ? </p>

<p>We decided to run our server on Ubuntu 18.04 Server LTS. Why?<br>
	Because we are students and we don't want to use old versions which will not be used in the next years. We want a <u>updated kernel</u> which will be <b>functionnal</b> during some years.</p>
<p>In addition to that, security is in the midddle of this version, with deployment of patch to be protected about Spectre and Meltdown flaws.<br>
So let's go make your bootable USB key and join us at the second step!</p>

<h2>2- Configuring a DHCP server (on Master) which gives IP address to slaves</h2>
<p>We want our own subnet where all our machines will be.
	
To do so, we'll have to install isc-dhcp-server:

	apt install isc-dhcp-server

Once it is installed, edit the file dhcpd.conf:

	nano /etc/dhcp/dhcpd.conf
	
And you can create your own subnet as such :

	subnet 192.168..0 netmask 255.255.255.0 {	#You can change the subnet for your own, as x.x.x.0
  	range 192.168.100.15 192.168.100.115;
  	option domain-name-servers 147.99.64.102, 147.99.0.248;	 #DNS addresses
  	option domain-name "sio.internal.lan";
  	option subnet-mask 255.255.255.0;
  	option routers 192.168.100.12;	#The default gateway that will be used by the machines inside your subnet
	default-lease-time 600;
	max-lease-time 7200;
	}
	
We now need to tell the dhcp service on which interface it needs to listen to give ip addresses. To do so, simply configure the file :

	nano /etc/default/isc-dhcp-server
	
<b> /!\ WARNING /!\ </b> Be sure that the interface you indicate isn't the one connected to the already existing subnet of the company (such is the case in our context) or the dhcp server will give ip addresses to everybody in the company instead of the machines in your private subnet, causing a loss of internet in the company.<br>
Add those two lines, indicating the right interface (in our case, the interface connected to our subnet is enp1s0):

	INTERFACESv4="enp1s0"
	INTERFACESv6="enp1s0"
	
Your DHCP server will now give an ip to any machine connected on his interface enp1s0.

<h2>3- Configuring iptables to allow Slaves to have Internet access</h2>
<br>

To allow the machines inside the subnet to have internet access, we need to add some iptables rules. To do so, we got a script  implamenting several iptables rules : See the <b>script_iptables.sh<b/> file in our repository. To execute this scipt, use the command <b>bash</b> followed by the path to your script (for us it was in /home/sio-master/) :
	
	bash /home/sio-master/script_iptables.sh
	
The iptables rules are effective immediately but they won't be effective anymore after a reboot of your master.
<br>
To resolve that issue, you can create a service that will launch on StartUp :

	cd /etc/systemd/system/
	nano script_iptables.service
	
Now edit that .service file as such :

	[Unit]
	Description=Startup   #A simple description of what the service does

	[Service]
	ExecStart=/home/sio-master/script_iptables.sh   #Executes this script when the system starts

	[Install]
	WantedBy=default.target

Then enter the following command to be sure that your service will be effective on StartUp:

	systemctl daemon-reload
	systemctl enable script_iptables.service
	
Your script for iptables rules will now execute itself when you restart the master, and your machines inside the subnet will have internet access.

<h2>4- SSH configuration with Password Authentication</h2>
<p>We want have SSH connection between our Master and their Slaves to remote control them.</p><br>
To do that, we need to install SSH packages on both Master and Slaves with the command "apt install SSH".
<br>
Now, we just check if, in the file "/etc/ssh/sshd_config", the line "PasswordAuthentication" is uncommented.
In our case, we want to have an entire control of our machines, and we will set "PermitRootLogin" and "PasswordAuthentication" as "yes".
<br>
Be aware that if your password have special character or number, SSH connection could be failed (we have encountered this problem).
<br>
We will configure authentication by key later on.
<br>


<h2>5- LXD install</h2>
<p><b>Why?</b><br>
	We want to evaluate if it is possible to deploy a Kubernetes cluster. If this is the case, the Kubernetes cluster can be integrated into a computing cluster, 100% made up of LXC containers.<br>
We therefore want to familiarize ourselves with the LXC/LXD tools. </p>
<p>So, you can skip LXD steps (5/6/7) if you don't need to learn the basics of LXC.</p>
<p>First, let's install LXD package with "apt install lxd" command.<br>
After the install is complete, do a "lxd init" to initialize your lxd. You can let all the default settings or change it as you wish.</p>

<p>This is a list of basic LXC commands:<br>
	
	[...]

<h2>6- Configuring LXD Remote on Master</h2>
<p>The advantage of LXD is that you can lauch container remotly. It can be very useful if you want to start services from scratch on different computers, as a secundary DHCP server, a WEB server...</p>
<p>To do that, we will order to lxc (on both Master and Slaves) to listen on a specific port. This is the commands whichs allow to start container on Slaves from the Master:<br>
	
	lxc config set core.https_address [::]:8443

We can define now a password to protect our port:<br>
	
	lxc config set core.trust_password yourpassword
	
Now that the daemon configuration is done on both ends, you can add a slave server to your local client with:<br>

	lxc remote add sio-slave2 192.168.100.26
	
You can then list your remotes and you'll see "sio-slave2" listed there:<br>

	lxc remote list
	+-----------------+------------------------------------------+---------------+-----------+--------+--------+
	|      NAME       |                   URL                    |   PROTOCOL    | AUTH TYPE | PUBLIC | STATIC |
	+-----------------+------------------------------------------+---------------+-----------+--------+--------+
	| images          | https://images.linuxcontainers.org       | simplestreams |           | YES    | NO     |
	+-----------------+------------------------------------------+---------------+-----------+--------+--------+
	| local (default) | unix://                                  | lxd           | tls       | NO     | YES    |
	+-----------------+------------------------------------------+---------------+-----------+--------+--------+
	| sio-slave2      | https://192.168.100.26:8443              | lxd           | tls       | NO     | NO     |
	+-----------------+------------------------------------------+---------------+-----------+--------+--------+
	| ubuntu          | https://cloud-images.ubuntu.com/releases | simplestreams |           | YES    | YES    |
	+-----------------+------------------------------------------+---------------+-----------+--------+--------+
	| ubuntu-daily    | https://cloud-images.ubuntu.com/daily    | simplestreams |           | YES    | YES    |
	+-----------------+------------------------------------------+---------------+-----------+--------+--------+
	
So we have now a remote server defined, we can now launch a container remotly:

	lxc launch ubuntu:18.04 test
	
List tje running containers to verify that it works:

	lxc list sio-slave2
	
Finally, getting a shell into a remote container works just as you would expect:

	lxc exec sio-slave2:test bash
	
We can do many remote commands:
	
	lxc copy sio-slave2:test current
	lxc stop sio-slave2:test
	lxc move sio-slave2:test test2
	
	lxc snapshot sio-slave2:test current
	
<h2>7- Configuring a LXC profile which allows container to get IP address from the DHCP server</h2>
<p>Now, we wants our containers to get IP address from the DHCP server which is hosted on the Master. We need to create a specific profil and apply it to the container:
	
	lxc profile copy default lanprofile
	lxc profile list
	
We have copied the default LXC profile as a "lanprofile", we can see him with "lxc profile list".<br>
Now, let's see what is the default configuration of our profile:<br>

 	lxc profile show lanprofile

There are 2 values that we are going to change: "nictype" will become "macvlan" and "parent" will become our network interface. To be sure of our interface, do the following command:<br>

	ip route show default 0.0.0.0/0
	
	default via 192.168.1.1 dev enps5s12 proto static metric 1OO
	
We can see that our interface is "enp5s12". So, let's change what we said:<br>

	lxc profile device set lanprofile eth0 nictype macvlan
	lxc profile device set lanprofile eth0 parent enp5s12
	
We can now create containers by attaching the "lanprofile" profile to them. New containers can now get ip address from the DHCP server.<br>
We create the container "test" and attach it the "lanprofile" profile:<br>

	lxc launch -p lanprofile ubuntu:18.04 test
	
Now check that your container has recovered an address from your DHCP: <br></p>

	lxc exec test ip route

<h2>8- SSH configuration with PubKey Authentication</h2>
<p>We are now tired of having to enter a password each time we connect to SSH. We will therefore disable password authentication and configure key authentication.</p>
We have chosen to use rsa key because it is more secure.
<p> On our Master server, we generate a key and send it to our slaves:<br>
	
	ssh-keygen -t rsa
	ssh-copy-id 192.168.100.48
	ssh-copy-id 192.168.100.23
	ssh-copy-id 192.168.100.26
	
After that, you need to disable PasswordAuthentication by setting it to "no" and set the PubKeyAuthentication to "yes" in the ssh configuration file (/etc/ssh/sshd_config).<br>
You don't need to restart ssh service because the changes are applied instantly.</p>

<p>We have configured a SSH PubKey Authentication, we are more protected than a basic Password Authencation. However, if in the future, we wants to return to Password Authentication for practical reasons, we will be in a danger and vulnerable to Brute Force attacks.<br>
So, we wants to protect our SSH connection by configuring a protection against Brute Force attacks. Let's do this!</p>

<h2>9- Configuring fail2ban to counter Brute Force attacks</h2>
<p><b>What is fail2ban?</b><br>
	Fail2ban is a tool that allows you to automatically ban IP addresses if they do not respect the rules you define beforehand. For example, a person tries to connect in SSH on your server but this person fails to connect 4 times in succession. Fail2ban will ban its IP address so that this person no longer has the right to communicate with your server. Fail2ban knows that it must ban the IP after 4 failed attempts because it has been defined in its configuration files.</p>
	<p>We wants to protect our Master node, which host the principal service of the Network (DHCP server, iptables, PXE server...). It have a WAN interface and it exposed to have attacks.</p>
	
<p>First, install the package on your Master (if you want, you can install it on every computer in your network to protect all SSH connection.</p><br>

	apt install fail2ban
	
<p>Now, we need to create our own configuration file in "/etc/fail2ban/jail.d/". We'll call it "custom.conf".<br>
	
	nano /etc/fail2ban/jail.d/custom.conf

Now, insert the following text:

	[DEFAULT]
	findtime = 3600
	bantime = 24h
	maxretry = 3
	
	[sshd]
	enabled = true
	
findtime: define the time (second) during an anomaly is searched in logs<br>
bantime: duration of ban after the maxretry number<br>
maxretry: define how many fails we autorize before a jail<br></p>

<p>We have activate fail2ban on SSH with the section "[sshd]". You can activate fail2ban on the services which needs a password authentication and that you want to protect.</p>

<p>Now, restart the service and check if it is active:<br>
	
	service fail2ban restart
	fail2ban-client status



<h2>10- Configuring PXE/tftpd-hpa to automate installation from scratch</h2>
<h2>11- Kubernetes Cluster install</h2>
<h2>12- Ansible: Let's do it again from scratch !</h2>
