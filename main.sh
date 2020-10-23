#
# Bash script to automate Ansible Tower Deployment
# Suwardi - wardilee@icloud.com
#  
#!/bin/bash

# Define variables
YML_CREATE_ORG_FILE=/var/lib/awx/projects/Test-yml/org_crt.yml
YML_CREATE_INVPRJ_FILE=/var/lib/awx/projects/Test-yml/inventory_proj.yml
YML_PROJ_DIR=/var/lib/awx/projects

ORGANIZATION_NAME=ORG-49
INVENTORY=Invent-49
PROJECT_NAME=Project-49
PROJECT_PATH=Directory49
JOBTEMPLATE=JOBTemp-49


# Flexible ip address of tower host
HOSTIP=`sudo ip addr | grep 192.168 | awk '{ print $2 }' | cut -d'/' -f1`

# Set Tower IP & test ping
if ( tower-cli config host $HOSTIP ); then
       echo "Tower IP set to $HOSTIP"
else
       echo "Failed set tower IP"
       exit ${1}
fi


if ( ping -c1 $HOSTIP > /dev/null 2>&1 ); then
        echo "ping successful"
else
        echo "Tower unreachable"
        exit ${1}
fi

# Create organization from playbook
# with tower api

if [[ -f "$YML_CREATE_ORG_FILE" ]]; then
        echo "Creating tower organization $ORGANIZATION_NAME"
 	 ansible-playbook --connection=local --extra-vars "host_ip='${HOSTIP}' \
		org_name='${ORGANIZATION_NAME}'" "$YML_CREATE_ORG_FILE"  
        tower-cli organization list
else
        echo "File $YML_CREATE_ORG_FILE not found"
	 exit ${1}
fi

#sleep 10

# Get Organization ID
ORGID=`tower-cli organization list | grep $ORGANIZATION_NAME | awk '{ print $1 }'`

# Create Tower inventory with Tower api
if [[ -f "$YML_CREATE_INVPRJ_FILE" ]]; then

	# Create Tower Inventory
	echo "Creating tower inventory with $YML_CREATE_INVPRJ_FILE"
	ansible-playbook --connection=local --tags "inventory_post" --extra-vars \
		 "host_ip='${HOSTIP}' inv_name='${INVENTORY}' org_id='${ORGID}'" $YML_CREATE_INVPRJ_FILE 

	# Listing inventory
	tower-cli inventory list
	
 
 	# Create Tower project
        echo "Creating tower Project with $YML_CREATE_INVPRJ_FILE"

	if [[ ! -d "$YML_PROJ_DIR/$PROJECT_PATH" ]]; then
		mkdir "$YML_PROJ_DIR/$PROJECT_PATH"
	fi

        ansible-playbook --connection=local --tags "project_post" --extra-vars \
        	"host_ip='${HOSTIP}' proj_name='${PROJECT_NAME}' org_id='${ORGID}' \
          	proj_path='${PROJECT_PATH}'" $YML_CREATE_INVPRJ_FILE

	# Listing project
        tower-cli project list



	# Create Tower job template
	echo "Creating tower Job Template with $YML_CREATE_INVPRJ_FILE"
	INVENTORY_ID=`tower-cli inventory list | grep $INVENTORY | awk '{ print $1 }'`
	PROJ_ID=`tower-cli project list | grep $PROJECT_NAME | awk '{ print $1 }'`
	#PLAYBOOK_YML="$YML_PROJ_DIR/$PROJECT_PATH/hello.yml"
	PLAYBOOKY="hello.yml"
	echo -e "---\n- hosts: localhost\n  gather_facts: false\n  foo: \"Hello world\"" > $PLAYBOOKY

	ansible-playbook -vvv --connection=local --tags "jobtemplate_post" --extra-vars \
		"host_ip='${HOSTIP}' job_templ_name='${JOBTEMPLATE}' proj_id='${PROJ_ID}' \
		playbook_path='${PLAYBOOKY}' inv_id='${INVENTORY_ID}'" $YML_CREATE_INVPRJ_FILE

	# Listing job template
	tower-cli job_template list

	# Running job with Tower
	tower-cli job launch -J $JOBTEMPLATE

else
        echo "File $YML_CREATE_INVPRJ_FILE not found"
	exit ${1}
fi





