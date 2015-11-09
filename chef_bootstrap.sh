#!/bin/bash
LOGFILE="/var/log/cloud-init-chef-bootstrap.setup.$$"
CHEFRUNLOGFILE="/var/log/cloud-init-chef-bootstrap.first-run.$$"

# Initial timestamp and debug information
date > $LOGFILE
echo "Starting cloud-init bootstrap" >> $LOGFILE
echo "chef_version parameter: $chef_version" >> $LOGFILE
echo "organization parameter: $chef_organization" >> $LOGFILE
echo "run list parameter: $chef_run_list" >> $LOGFILE

# Infer the Chef Server's URL if none was passed
if [ "$chef_server_url" ]; then
  echo "chef_server_url parameter: $chef_server_url" >> $LOGFILE
  chef_url="$chef_server_url"
else
  echo "chef_server_url parameter: not passed" >> $LOGFILE
  chef_url="https://api.opscode.com/organizations/$chef_organization"
fi

# Store the validation key in /etc/chef/validator.pem
echo "Storing validation key in /etc/chef/validator.pem"
mkdir /etc/chef /var/log/chef &>/dev/null
printf '%b\n' "$chef_validation_key" > /etc/chef/validator.pem

# Store the encrypted_data_bag_secret if provided
if [ -n "$chef_encrypted_secret_key" ]; then
  echo "Storing data bag secret in /etc/chef/encrypted_data_bag_secret"
  printf '%b\n' "$chef_encrypted_secret_key" >/etc/chef/encrypted_data_bag_secret
fi

# Cook a minimal client.rb for getting the chef-client registered
echo "Creating a minimal /etc/chef/client.rb" >> $LOGFILE
printf '%s\n' \
"log_level        :info
log_location     STDOUT
chef_server_url  \"$chef_url\"
validation_key         \"/etc/chef/validator.pem\"
validation_client_name \"$chef_organization-validator\"
environment      \"$chef_environment\"" > /etc/chef/client.rb

# Cook the first boot file
echo "Creating a minimal /etc/chef/first-boot.json" >> $LOGFILE
printf '{\n  "run_list":$chef_run_list' > /etc/chef/first-boot.json

if [ -n "$chef_attributes" ]; then
  # Replace helper values
  public_ip=$(/sbin/ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}')
  private_ip=$(/sbin/ip -4 -o addr show dev eth1| awk '{split($4,a,"/");print a[1]}')
  chef_attributes=$(printf "$chef_attributes" | sed "s/##public_ip##/$public_ip/g")
  chef_attributes=$(printf "$chef_attributes" | sed "s/##private_ip##/$private_ip/g")
  printf ',\n$chef_attributes' >> /etc/chef/first-boot.json
fi

# Close JSON of file
printf '\n}' >> /etc/chef/first-boot.json

# Install chef-client through omnibus (if not already available)
if [ ! -f /usr/bin/chef-client ]; then
  echo "Installing chef using omnibus installer" >> $LOGFILE
  # adjust to install the latest vs. a particular version
  curl -L https://www.opscode.com/chef/install.sh | bash -s -- -v $chef_version >>$LOGFILE
  echo "Installation of chef complete" >> $LOGFILE
else
  echo "Existing chef found and is being used" >> $LOGFILE
  echo "Existing chef version: $(chef-client --version)" >> $LOGFILE
fi

# Kick off the first chef run
echo "Executing the first chef-client run"
if [ -f /usr/bin/chef-client ]; then
  echo "First Chef client run" >> $LOGFILE
  count=0
  try=2
  while [ $count -lt $try ]; do
    /usr/bin/chef-client -j /etc/chef/first-boot.json >> $CHEFRUNLOGFILE
    if [ $? -eq 0 ]; then
      wc_notify --data-binary '{"status": "SUCCESS"}'
      let count=$try
    else
      let count=count+1
      echo "chef-client execution failed, will try $try times count: $count" >> $LOGFILE
      if [ $count -eq $try ]; then
        wc_notify --data-binary '{"status": "FAILURE"}'
      fi
    fi
  done
fi

# Script complete. Log final timestamp
date >> $LOGFILE
