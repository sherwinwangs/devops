NGINX
-----------------------------------------------------------------------------
reference": https://github.com/jdauphant/ansible-role-nginx

- Requires Ansible 2.1
- Expects CentOS/RHEL 6 hosts
- Official Download: http://nginx.org/download/

### Initial Site Setup

First we configure the entire stack by listing our hosts in the 'hosts'
inventory file, grouped by their purpose:

	[lvs]
	192.168.3.201
	192.168.3.202
	
	[nginx]
	192.168.3.211
	192.168.3.212
	
	[tomcat]
	192.168.3.221
	192.168.3.222
	192.168.3.223

After which we execute the following command to deploy the site:

		ansible-playbook -i hosts site.yml

The deployment can be verified by accessing the IP address of your load
balancer host in a web browser: http://<ip-of-lb>:8888. Reloading the page
should have you hit different webservers.

### Removing and Adding a Node

Removal and addition of nodes to the cluster is as simple as editing the
hosts inventory and re-running:

        ansible-playbook -i hosts site.yml


### Rolling Update

Rolling updates are the preferred way to update the web server software or
deployed application, since the load balancer can be dynamically configured
to take the hosts to be updated out of the pool. This will keep the service
running on other servers so that the users are not interrupted.

In this example the hosts are updated in serial fashion, which means that
only one server will be updated at one time. If you have a lot of web server
hosts, this behaviour can be changed by setting the 'serial' keyword in
webservers.yml file.

Once the code has been updated in the source repository for your application
which can be defined in the group_vars/all file, execute the following
command:

	 ansible-playbook -i hosts rolling_update.yml

	 You can optionally pass: -e webapp_version=xxx to the rolling_update
	 playbook to specify a specific version of the example webapp to deploy.

