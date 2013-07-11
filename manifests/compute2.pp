#
# == Class: openstack::compute2
#
# Manifest to install/configure nova-compute
#
# [purge_nova_config]
#   Whether unmanaged nova.conf entries should be purged.
#   (optional) Defaults to false.
#
# === Examples
#
# class { 'openstack::nova::compute':
#   internal_address   => '192.168.2.2',
#   vncproxy_host      => '192.168.1.1',
#   nova_user_password => 'changeme',
# }

class openstack::compute2 (
  # Required Network
  $internal_address,
  # Required Nova
  $nova_user_password,
  # Required Rabbit
  $rabbit_password,
  # DB
  $nova_db_password,
  $db_host                       = '127.0.0.1',
  # Nova Database
  $nova_db_user                  = 'nova',
  $nova_db_name                  = 'nova',
  # Network
  $public_interface              = undef,
  $private_interface             = undef,
  $fixed_range                   = undef,
  $network_manager               = 'nova.network.manager.FlatDHCPManager',
  $network_config                = {},
  $multi_host                    = false,
  $enabled_apis                  = 'ec2,osapi_compute,metadata',
  # Quantum
      # $quantum                       = true,
      # $quantum_user_password         = false,
      # $quantum_admin_tenant_name     = 'services',
      # $quantum_admin_user            = 'quantum',
      # $enable_ovs_agent              = true,
      # $enable_l3_agent               = false,
      # $enable_dhcp_agent             = false,
      # $quantum_auth_url              = 'http://127.0.0.1:35357/v2.0',
      # $keystone_host                 = '127.0.0.1',
      # $quantum_host                  = '127.0.0.1',
      # $ovs_local_ip                  = false,
  # Nova
  $nova_admin_tenant_name        = 'services',
  $nova_admin_user               = 'nova',
  $purge_nova_config             = false,
  $libvirt_vif_driver            = 'nova.virt.libvirt.vif.LibvirtGenericVIFDriver',
  # Rabbit
  $rabbit_host                   = '127.0.0.1',
  $rabbit_user                   = 'openstack',
  $rabbit_virtual_host           = '/',
  # Glance
  $glance_api_servers            = false,
  # Virtualization
  $libvirt_type                  = 'kvm',
  # Avance
  $avance_conn_url = undef,
  $avance_conn_username = undef,
  $avance_conn_password = undef,
  $avance_inject_image = undef,
  # VNC
  $vnc_enabled                   = true,
  $vncproxy_host                 = undef,
  $vncserver_listen              = false,
  # cinder / volumes
      # $manage_volumes                = true,
      # $cinder_db_password            = false,
      # $cinder_db_user                = 'cinder',
      # $cinder_db_name                = 'cinder',
      # $volume_group                  = 'cinder-volumes',
      # $iscsi_ip_address              = '127.0.0.1',
      # $setup_test_volume             = false,
  # General
  $migration_support             = false,
  $verbose                       = true,
  $enabled                       = true

) {

  if $vncserver_listen {
    $vncserver_listen_real = $vncserver_listen
  } else {
    $vncserver_listen_real = $internal_address
  }


  #
  # indicates that all nova config entries that we did
  # not specifify in Puppet should be purged from file
  #
  if ! defined( Resources[nova_config] ) {
    if ($purge_nova_config) {
      resources { 'nova_config':
        purge => true,
      }
    }
  }

  #$nova_sql_connection = "mysql://${nova_db_user}:${nova_db_password}@${db_host}/${nova_db_name}"

  class { 'nova':
    #sql_connection      => $nova_sql_connection,
    rabbit_userid       => $rabbit_user,
    rabbit_password     => $rabbit_password,
    image_service       => 'nova.image.glance.GlanceImageService',
    glance_api_servers  => $glance_api_servers,
    verbose             => $verbose,
    rabbit_host         => $rabbit_host,
    rabbit_virtual_host => $rabbit_virtual_host,
  }

  # Install / configure nova-compute
  class { '::nova::compute':
    enabled                       => $enabled,
    vnc_enabled                   => $vnc_enabled,
    vncserver_proxyclient_address => $internal_address,
    vncproxy_host                 => $vncproxy_host,
  }

  # # Configure libvirt for nova-compute
  # class { 'nova::compute::libvirt':
  #   libvirt_type      => $libvirt_type,
  #   vncserver_listen  => $vncserver_listen_real,
  #   migration_support => $migration_support,
  # }

  class { 'nova::compute::avanceserver':
    avanceapi_connection_url => $avance_conn_url,
    avanceapi_connection_username => $avance_conn_username,
    avanceapi_connection_password => $avance_conn_password,
    avanceapi_inject_image => $avance_inject_image,
  )


  # if the compute node should be configured as a multi-host
  # compute installation
    if ! $fixed_range {
      fail('Must specify the fixed range when using nova-networks')
    }

    if $multi_host {
      include keystone::python
      nova_config {
        'DEFAULT/multi_host':      value => true;
        'DEFAULT/send_arp_for_ha': value => true;
      }
      if ! $public_interface {
        fail('public_interface must be defined for multi host compute nodes')
      }
      $enable_network_service = true
      class { 'nova::api':
        enabled           => true,
        admin_tenant_name => $nova_admin_tenant_name,
        admin_user        => $nova_admin_user,
        admin_password    => $nova_user_password,
        enabled_apis      => $enabled_apis,
      }
    } else {
      $enable_network_service = false
      nova_config {
        'DEFAULT/multi_host':      value => false;
        'DEFAULT/send_arp_for_ha': value => false;
      }
    }

    class { 'nova::network':
      private_interface => $private_interface,
      public_interface  => $public_interface,
      fixed_range       => $fixed_range,
      floating_range    => false,
      network_manager   => $network_manager,
      config_overrides  => $network_config,
      create_networks   => false,
      enabled           => $enable_network_service,
      install_service   => $enable_network_service,
    }
  }

    # set in nova::api
  if ! defined(Nova_config['DEFAULT/volume_api_class']) {
      nova_config { 'DEFAULT/volume_api_class': value => 'nova.volume.cinder.API' }
    }
  }

}
