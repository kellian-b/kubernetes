# kubernetes
<h1>Deploy Kubernetes Cluster in a new subnet from scratch (with own PXE and DHCP server)</h1>
	<p><b>Hardware configuration</b></p>
	<ul>
		<li>1 Master server: 2GB RAM</li>
		<li>3 Slaves server: 1GB RAM</li>
		<li>1 Switch</li>
		<br>
  <li>OS: Ubuntu 18.04 Server LTS: The version wich will be functionnal the next years</li>
</ul>

<p><b>Network organization:</b></p>
	<br>
	<ul>
		<li>Master: It welcome DHCP/PXE server, iptables script, LXC Remote Control, Ansible playbooks. It have 2 network interfaces (1 LAN & 1 WAN) plays the gateway for slaves which will want to have Internet access</li>
		<li>Slaves: They will hosts LXC/Docker container to start services from scratch, allowing them to not loose ressources... </li>
		<li>Switch: It interconnect Master and Slaves</li>
	</ul>
	<p><b>Tasks order:</b></p>
	<br>
	<ol>
		<li>Deploying bare metal OS</li>
		<li>Configuring a DHCP server (on Master) which gives IP addresss to slaves</li>
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
