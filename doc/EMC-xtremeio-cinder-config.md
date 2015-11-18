# How-To configure EMC XtremeIO cinder support inside rpc-openstack

# Install cinder volumes service inside containers

### Changing cinder volumes service to run inside containers /etc/openstack_deploy/env.d/cinder.yml

``` 
 is_metal: false
```

# Adding cinder nodes to rpc-opentstackn inventory

### Adding cinder nodes inside /etc/openstack_deploy/openstack_user_config.yml

This is a example configuration using the storage protocol iSCSI
Cinder volume service only talk to the XMS management IP via HTTPS
The actual iSCSI data is running from each nova-compute host (br-storage ideally)
to the XtremeIO storage controller heads

```
storage_hosts:
  infra01:
    ip: 172.29.236.50
    container_vars:
      cinder_backends:
        limit_container_types: cinder_volume
        xtremio:
          volume_driver: cinder.volume.drivers.emc.xtremio.XtremIOISCSIDriver
          san_ip: 1.2.3.4 #XMS management IP
          san_login: openstackadmin
          san_password: osadmin
          volume_backend_name: xtrem01
          xtremio_cluster_name: xtrem01

  infra02:
    ip: 172.29.236.51
    container_vars:
      cinder_backends:
        limit_container_types: cinder_volume
        xtremio:
          volume_driver: cinder.volume.drivers.emc.xtremio.XtremIOISCSIDriver
          san_ip: 1.2.3.4 #XMS management IP
          san_login: openstackadmin
          san_password: osadmin
          volume_backend_name: xtrem01
          xtremio_cluster_name: xtrem01

  infra03:
    ip: 172.29.236.52
    container_vars:
      cinder_backends:
        limit_container_types: cinder_volume
        xtremio:
          volume_driver: cinder.volume.drivers.emc.xtremio.XtremIOISCSIDriver
          san_ip: 1.2.3.4 #XMS management IP
          san_login: openstackadmin
          san_password: osadmin
          volume_backend_name: xtrem01
          xtremio_cluster_name: xtrem01
```

# EMC storage specific config to nova and cinder 

## Adding override inside /etc/openstack_deploy/user_extras_variables.yml

```
cinder_cinder_conf_overrides:
  DEFAULT:
    use_multipath_for_image_xfer: true
        
nova_nova_conf_overrides:
  DEFAULT:
    use_cow_images: false
```
