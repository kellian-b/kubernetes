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
  	option domain-name-servers x.x.x.x, x.x.x.x;	 #DNS addresses
  	option domain-name "sio.internal.lan";
  	option subnet-mask 255.255.255.0;
  	option routers 192.168.100.12;	#The default gateway that will be used by the machines inside your subnet
	default-lease-time 600;
	max-lease-time 7200;
	}
	
We now need to tell the dhcp service on which interface it needs to listen to give ip addresses. To do so, simply configure the file :

	nano /etc/default/isc-dhcp-server
	
<b> /!\ WARNING /!\ </b><br> 
Be sure that the interface you indicate isn't the one connected to the already existing subnet of the company (such is the case in our context) or the dhcp server will give ip addresses to everybody in the company instead of the machines in your private subnet, causing a loss of internet in the company.<br>
Add those two lines, indicating the right interface (in our case, the interface connected to our subnet is enp1s0):

	INTERFACESv4="enp1s0"
	INTERFACESv6="enp1s0"
	
Your DHCP server will now give an ip to any machine connected on his interface enp1s0.

<h2>3- Configuring iptables to allow Slaves to have Internet access</h2>
<br>

To allow the machines inside the subnet to have internet access, we need to add some iptables rules. To do so, we got a script  implamenting several iptables rules : See the <b>script_iptables.sh</b> file in our repository. To execute this scipt, use the command <b>bash</b> followed by the path to your script (for us it was in /home/sio-master/) :
	
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
	
You also need to allow ipv4 forwarding from the master. Edit the file <b>sysctl.conf</b> to uncomment the line <b>net.ipv4.ip_forward=1</b>:

	nano /etc/sysctl.conf
	
From :
	
	#net.ipv4.ip_forward=1
	
To:

	net.ipv4.ip_forward=1
	
Your script for iptables rules will now execute itself when you restart the master, and your machines inside the subnet will have internet access.

<h2>4- SSH configuration with Password Authentication</h2>
<p>We want have SSH connection between our Master and their Slaves to remote control them.</p><br>
To do that, we need to install SSH packages on both Master and Slaves:

	apt install ssh

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
	
	Create a container:
	lxc-launch ubuntu:18.04 mycontainer
	
	List existing containers:
	lxc-ls -f
	
	Get information about a container:
	lxc-info mycontainer
	
	Start a container:
	lxc-start -n mycontainer
	
	Stop a container:
	lxc-stop -n mycontainer
	
	Get a shell on the container:
	lxc-attach -n mycontainer OR lxc exec mycontainer bash
	
	Delete a container:
	lxc-destroy -n mycontainer

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

	lxc launch ubuntu:18.04 sio-slave2:test
	
List the running containers to verify that it works:

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
	
<br>
<b>How to get a fixed ip address :</b><br>
<br>
<b>Fist method: Changing the container's configuration</b><br>

<p>
<br>To have a fixed ip address on your container, you need to stop the container, then change its configuration :

	lxc stop mycontainer
	lxc network attach lxdbr0 mycontainer eth0 eth0
	lxc config device set mycontainer eth0 ipv4.address 192.168.100.64
	lxc start mycontainer
	
Then when you type the following command, you should have the address you configured as output (even thought when you input <i>"lxc list"</i> or when you enter you container and type in <i>"ip a"</i> the ip address will not be the one you configured):

	lxc config device get mycontainer eth0 ipv4.address
	
Your container now as for its ip the one you configured.

</p>
<b>Second method: On container launch</b><br>
<p><br>In your dhcp configuration, add the following lines choosing a custom MAC address that will identify your container, and you associate it to a fixed ip address. Add in <i>"/etc/dhcp/dhcpd.conf"</i> :

	host mycontainer { hardware ethernet 00:16:3e:aa:aa:01; fixed-address 192.168.100.64; }
	
Then when you launch your container, add the configuration input as such :

	lxc launch -p lanprofile ubuntu:18.04 -c volatile.eth0.hwaddr=00:16:3e:aa:aa:01 mycontainer
	
Your container will have the ip and hardware address you configured in your <i>dhcpd.conf</i> file.  

</p>
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
	Status
	|- Number of jail:	1
	`- Jail list:	sshd


<h2>10- Configuring PXE/tftpd-hpa to automate installation from scratch</h2>
<h2>11- Kubernetes Cluster install</h2>

<p>First of all, we need to install Docker with a validated version for Kubernetes on <b>ALL</b> of the nodes that will use Kubernetes.<br>
	
<b>Step 1 : Installing Docker</b>

Install packages to allow apt to use a repository over HTTPS:

	sudo apt-get install \
    	apt-transport-https \
    	ca-certificates \
    	curl \
    	software-properties-common

Add Docker’s official GPG key:

	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	
Verify that you now have the key with the fingerprint 9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88, by searching for the last 8 characters of the fingerprint.

	sudo apt-key fingerprint 0EBFCD88

Use the following command to set up the stable repository.

	sudo add-apt-repository \
   	"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   	$(lsb_release -cs) \
   	stable"

List the available versions.

	sudo apt-cache madison docker-ce

Install the version 18.06.0~ce~3-0~ubuntu which is validated by Kubernetes.

	sudo apt install docker-ce=18.06.0~ce~3-0~ubuntu

Verify that Docker CE is installed correctly by running the hello-world image.

	sudo docker run hello-world
	
Then enable docker in the system :

	systemctl enable docker
	
	

<b>Step 2 : Installing and Configuring Kubernetes</b>

You will have two types of nodes : 1 Master which we will name <b>kmaster</b> and 1 or 2 Slaves named <b>kslave1</b> and <b>kslave2</b>.

The aim is to launch docker containers on the slaves from the master. To do so, we have to enter some commands on both <b>ALL</b> the nodes :

First of all, synch the dates and times between the nodes (we have the habit of using ntpdate). If you don't do it, you will encounter several errors. Synch the time with the DNS server:

	apt install ntpdate
	ntpdate x.x.x.x #DNS ADDRESS
	
Next, get the Kubernetes signing key :

	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
	
Add the Kubernetes repository and install Kubernetes :

	apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
	apt install kubeadm
	
We need to disable swap memory on all your nodes (master & slave) because Kubernetes refuses to function on systems using swap memory :

	swappoff -a
	

<b>ON THE MASTER :</b>

Initialize the Kubernetes :

	root@kmaster:~$ kubeadm init --pod-network-cidr=192.168.0.0/16

The last line of the initialization should be a <i><b>kubeadm join</b></i> command like this one :

<b>kubeadm join 192.168.100.82:6443 --token qh53oq.hdi9qduevp98qsdf --discovery-token-ca-cert-hash    	sha256:2cdb9046232ae3ab1f7f5186a548c88e37bf65a72ef0dd99dd1a0504db55c4e2</b>

Execute the following commands to start using the Kubernetes cluster :

	mkdir -p $HOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config
	
Deploy a pod network :

	kmaster:~$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

Use the <b>kubectl</b> command to confirm that everything is up and ready :

	kmaster:~$ kubectl get pods --all-namespaces
	

<b>ON THE SLAVES : </b>

Use the <i> <b> kubeadm join </b> </i> command retrieved earlier from the master node to join the Kubernetes cluster :

	kslave1:~$ kubeadm join 192.168.100.82:6443 --token qh53oq.hdi9qduevp98qsdf --discovery-token-ca-cert-hash    	sha256:2cdb9046232ae3ab1f7f5186a548c88e37bf65a72ef0dd99dd1a0504db55c4e2
	

The slave should now have joined the Kubernetes cluster. To verify if it did, execute the following command on the master node :

	kmaster:~$ kubectl get nodes
	

<b> Deploy NGINX on the Kubernetes Cluster to test things out : </b>

From the master node <i> <b> kubectl create </b> </i> an nginx deployment :

	kmaster:~$ kubectl create deployment nginx --image=nginx
	
You can list all available deployments with :

	kmaster:~$ kubectl get deployments

For more information :

	kmaster:~$ kubectl describe deployment nginx
	
Then, make the NGINX container accessible via internet:

	kmaster:~$ kubectl create service nodeport nginx --tcp=80:80

This creates a public facing service on the host for the NGINX deployment. Because this is a nodeport deployment, kubernetes will assign this service a port on the host machine in the 32000+ range.

You can get the current services :

	kmaster:~$ kubectl get svc
	
Verify that the NGINX deployment is successful by using curl on the slave node:

	kmaster:~$ curl kslave1:32***
	
The outpout will show the unerndered "Welcome to nginx!" html page


<h2>12- Ansible: Let's do it again from scratch!</h2>

All we did can be automated with a predefined recipe: Ansible allows us to create playbooks which will contain the commands we did before. So, firts, install Ansible on your Master server:

	apt install ansible
	
<p><b>/!\WARNING/!\</b> Make sure that SSH PubKey AUthentication is working and PermitRootLogin set to "yes": Ansible works with SSH and we will order to Ansible to execute our commands with the Root user.</p>

<p>In /etc/ansible you can see that there is a file named "hosts". This file contains the declaration of our clients IP address. Let's create a group with our slaves and a group for our master:</p>

	nano /etc/ansible/hosts
	
	[...]
	[slaves]
	#sio-slave1
	192.168.100.10
	#sio-slave2
	192.168.100.20
	#sio-slave3
	192.168.100.30
	
	[slaves:vars]
	ansible_python_interpreter=/usr/bin/python3 #We want to use python3
		
	[master]
	#For security reasons, our Master IP is replaced by 1.2.3.4
	1.2.3.4
	
	[master:vars]
	ansible_python_interpreter=/usr/bin/python3 #We want to use python3
	
<p>Hosts file is essential, it's it which specify to Ansible the IP adress that playbooks must contact.<br>
Now, you can check if your Ansible success to contact your client with:
	
	ansible -m ping all
		
Ansible will try to ping the IP adress you specified. If it failed, it can be SSH connection problems.</p>
	
<p>That's all for the hosts file, now, we must configure our playbook which will automate everything we've done before.<br>
	In our case, we wants 2 playbooks: 1 for the Master, and 1 for the Slaves.
	I invite you to read the configuraton file higher up to configure it.</p>
	
<p>Once your playbooks are ready, you can deploy them:
	
	ansible-playbook -i hosts master-playbook.yml
	
Ansible permit you to follow the reading of the playbook, so you can see, at the end, if values have "changed" or if there are some problems.</p>
	
