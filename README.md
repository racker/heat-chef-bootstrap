# heat-chef-bootstrap
Heat user_data template to perform a Chef bootstrap

# Usage
Add resource values to your heat template for either `OS::Nova::Server` or some other server creation type such as `Rackspace::AutoScale::Group` in the user_data section.

Example:
```
  chef-client:
    type: OS::Heat::SwiftSignal
    properties:
      handle: { get_resource: chef-client_handle }
      timeout: 1800

  chef-client_handle:
    type: OS::Heat::SwiftSignalHandle

    type: "OS::Nova::Server"
    properties:
      name: { get_param: name }
      flavor: { get_param: flavor }
      image: { get_param: image }
      user_data:
        str_replace:
          template:
            get_file: https://raw.githubusercontent.com/racker/heat-chef-bootstrap/master/chef_bootstrap.sh
          params:
            "$chef_server_url": { get_param: chef_server_url }
            "$chef_version": { get_param: chef_version }
            "$chef_organization": { get_param: chef_organization }
            "$chef_environment": { get_param: chef_environment }
            "$chef_run_list": { get_param: chef_storage_role }
            "$chef_validation_key": { get_param: chef_validation_key }
            "$chef_encrypted_secret_key": { get_param: chef_encrypted_secret_key }
            wc_notify: { get_attr: ['chef-client_handle', 'curl_cli'] }
            "$chef_attributes": |
              "apache": {
                "listen": {
                  "##public_ip##": ["80]
                 }
              }
```

# Configuration
The following parameters should be configured in your template to string replace the script:

Parameter                 | Description
--------------------------|------------
chef_server_url           | The URL for your chef server. Default - `https://api.opscode.com/organizations/$chef_organization`
chef_version              | The chef version to bootstrap the server with. Required: Failure to provide will cause an error.
chef_organization         | Chef server organization to use. Required: Failure to provide will cause an error.
chef_environment          | Chef environment to bootstrap into. Required: Failure to provide will cause an error.
chef_run_list             | Run list of chef recipes or roles to bootstrap application servers. Required: Format as a quoted list, `"[recipe[cookbook], recipe[cookbook2]]"`
chef_attributes           | Attributes, in JSON form, to set for chef-client first boot. Optional, Default: `nil`
chef_validation_key       | Chef organization validation key. Required: Format as single line with literal newlines (\n)
chef_encrypted_secret_key | A encrypted_data_bag_secret to pass to the server. Optional, Default: `nil`
chef_node_name            | Chef client node name. Optional, Default : `$HOSTNAME`
wc_notify                 | Heat wait condition notification. Optional, Default : `{"status": "SUCCESS"`

# chef_attributes Helpers
There are a few key helpers provided by chef_bootstrap.sh to string replace variables
that are otherwise not available for a heat user_data template. This is due to the fact
that the templates are generated first in the heat engine and sent with cloud-init when
creating the resource. Attributes you may want to use in the template that are
not available are values such as the public and private ip addresses.

To use, define one of the following variables in your %chef_attributes% parameter when
calling the chef_bootstrap.sh file in your heat template. The chef_bootstrap.sh script
will perform a substitution for the variable automatically.

Variable                 | Description
-------------------------|------------
`##public_ip##`            | IP Address assigned to eth0
`##private_ip##`           | IP Address assigned to eth1
