# heat-chef-bootstrap
Heat user_data template to perform a Chef bootstrap

# Usage
Add resource values to your heat template for either `OS::Nova::Server` or some other server creation type such as `Rackspace::AutoScale::Group` in the user_data section.

Example:
```
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
            "%chef_server_url%": { get_param: chef_server_url }
            "%chef_version%": { get_param: chef_version }
            "%chef_organization%": { get_param: chef_organization }
            "%chef_environment%": { get_param: chef_environment }
            "%chef_run_list%": { get_param: chef_storage_role }
            "%chef_validation_key%": { get_param: chef_validation_key }
            "%chef_encrypted_secret_key%": { get_param: chef_encrypted_secret_key }
```

# Configuration
The following parameters should be configured in your template to string replace the script:

Parameter                 | Description
--------------------------|------------
chef_server_url           | The URL for your chef server. Default - `https://api.opscode.com/organizations/`
chef_version              | The chef version to bootstrap the server with. Default: `12.5`
chef_organization         | Chef server organization to use. Required
chef_environment          | Chef environment to bootstrap into. Required
chef_run_list             | Run list of chef recipes or roles to bootstrap application servers. Required
chef_attributes           | Attributes, in JSON form, to set for chef-client first boot. Optional
chef_validation_key       | Chef organization validation key. Required
chef_encrypted_secret_key | A encrypted_data_bag_secret to pass to the server. Optional 
wc_notify                 | Heat wait condition notification. Optional, Default : `{"status": "SUCCESS"'
