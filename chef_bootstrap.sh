#!/bin/bash
LOGFILE="/var/log/cloud-init-chef-bootstrap.setup.$$"
CHEFRUNLOGFILE="/var/log/cloud-init-chef-bootstrap.first-run.$$"

# Initial timestamp and debug information
date > $LOGFILE
echo "Starting cloud-init bootstrap" >> $LOGFILE
echo "chef_version parameter: %chef_version%" >> $LOGFILE
echo "organization parameter: %chef_organization%" >> $LOGFILE
echo "run list parameter: %chef_run_list%" >> $LOGFILE

# Infer the Chef Server's URL if none was passed
CHEFSERVERURL='%chef_server_url%'
if [ -n $CHEFSERVERURL ]; then
  echo "chef_server_url parameter: not passed" >> $LOGFILE
  CHEFSERVERURL="https://api.opscode.com/organizations/%chef_organization%"
else
  echo "chef_server_url parameter: $CHEFSERVERURL" >> $LOGFILE
  CHEFSERVERURL="%chef_server_url%"
fi

# Store the validation key in /etc/chef/validator.pem
echo "Storing validation key in /etc/chef/validator.pem"
mkdir /etc/chef /var/log/chef &>/dev/null
cat >/etc/chef/validator.pem <<EOF
%chef_validation_key%
EOF

# Store the encrypted_data_bag_secret if provided
if [ -n %chef_encrypted_secret_key% ]; then
  echo "Storing data bag secret in /etc/chef/encrypted_data_bag_secret"
  cat >/etc/chef/encrypted_data_bag_secret <<EOF
%chef_encrypted_secret_key%
EOF
fi

# Cook a minimal client.rb for getting the chef-client registered
echo "Creating a minimal /etc/chef/client.rb" >> $LOGFILE
touch /etc/chef/client.rb
cat >/etc/chef/client.rb <<EOF
  log_level        :info
  log_location     STDOUT
  chef_server_url  "$CHEFSERVERURL"
  validation_key         "/etc/chef/validator.pem"
  validation_client_name "%chef_organization%-validator"
  environment      "%chef_environment%"
EOF

# Cook the first boot file
echo "Creating a minimal /etc/chef/first-boot.json" >> $LOGFILE
touch /etc/chef/first-boot.json
printf "{\n  \"run_list\":[\"%chef_run_list%\"]" > /etc/chef/first-boot.json

if [ -n '%chef_attributes%' ]; then
  # Replace helper values
  public_ip=$(/sbin/ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}')
  private_ip=$(/sbin/ip -4 -o addr show dev eth1| awk '{split($4,a,"/");print a[1]}')
  chef_attributes=$(printf '%chef_attributes%' | sed "s/##public_ip##/$public_ip/g")
  chef_attributes=$(printf '%chef_attributes%' | sed "s/##private_ip##/$private_ip/g")
  printf ",\n$chef_attributes" >> /etc/chef/first-boot.json
fi

# Close JSON of file
printf '\n}' >> /etc/chef/first-boot.json

# Install chef-client through omnibus (if not already available)
if [ ! -f /usr/bin/chef-client ]; then
  echo "Installing chef using omnibus installer" >> $LOGFILE
  # adjust to install the latest vs. a particular version
  curl -L https://www.opscode.com/chef/install.sh | bash -s -- -v %chef_version% >>$LOGFILE
  echo "Installation of chef complete" >> $LOGFILE
else
  echo "Existing chef found and is being used" >> $LOGFILE
  echo "Existing chef version: $(chef-client --version)" >> $LOGFILE
fi

# Kick off the first chef run
echo "Executing the first chef-client run"
if [ -f /usr/bin/chef-client ]; then
  echo "First Chef client run" >> $LOGFILE
  /usr/bin/chef-client -j /etc/chef/first-boot.json >> $CHEFRUNLOGFILE
fi

# Script complete. Log final timestamp
date >> $LOGFILE

# Heat wait condition
wc_notify --data-binary '{"status": "SUCCESS"}'
