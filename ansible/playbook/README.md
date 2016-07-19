# reconfigure whole infrastructure:
ansible-playbook -i production site.yml

# just reconfiguring ntp on everything
ansible-playbook -i production site.yml --tags ntp  
ansible-playbook -i production site.yml --tags "ntp,network"
ansible-playbook -i production site.yml --skip-tags "nameserver"

# apply tags to roles
roles:
  - { role: nginx, port:80, tags: { "web", "foo"} }

# just reconfiguring nginx
ansible-playbook -i production nginx.yml

# vars prompt
- hosts: all

  vars_prompt: 
    - name: "release_version"
      prompt: "Product release version"
      default: "1.0"

    - name: "some_password"
      prompt: "Enter password"
      private: yes

    - name: "my password"
      prompt: "Enter password"
      private: yes
      encrypt: "md5_crypt"
      confirm: yes
      slat_size: 7

# serial exec
- name: test play
  hosts: webservers
  serial: 3
  serial: "30%"
  max_fail_percentage: 30

# run at first server
- command: /opt/server/test.py
  when: inventory_hostname == webserver[0]

# Custon module
# ansible api

# my webserver in boson(further limit selected hosts to an additional pattern) 
 ansible-playbook -i production --limit boston
# just the first 10, and then the next 10
 ansible-playbook -i production --limit boston[0-10]
 ansible-playbook -i production --limit boston[11-20]

--list-hosts          outputs a list of matching hosts; does not execute anything else
--list-tags           list all available tags
--list-tasks          list all tasks that would be executed
