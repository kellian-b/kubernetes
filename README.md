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
<b>Network organization:</b>
<br>
	<ul>
		<li>Master: It welcome DHCP/PXE server, iptables script, LXC Remote Control, Ansible playbooks. It have 2 network interfaces (1 LAN & 1 WAN) and plays the gateway for slaves which will want to have Internet access</li>
		<li>Slaves: They will hosts LXC/Docker container to start services from scratch, allowing them to not loose ressources... </li>
		<li>Switch: It interconnect Master and Slaves</li>
	</ul>
<b>Tasks order:</b>
<br>
<i>PS: All steps are first done by hand to get used with the different tools. If you're not a beginner, you can directly go to the step 12, to automate all the previous one</i>
<br>
	<ol>
		<li>Deploying OS on bare metal </li>
		<li>Configuring a DHCP server (on Master) which gives IP address to slaves</li>
		<li>Configuring iptables to allow Slaves to have Internet access</li>
		<li>SSH configuration with Password Authentication</li>
		<li>LXD install on slaves</li>
		<li>Configuring LXD Remote on Master</li>
		<li>Confiuring a LXC profile which allows container to get IP address from the DHCP server</li>
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
