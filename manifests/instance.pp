# perforce::instance defined type
#   - used to manage an instance of a p4d or p4broker in an sdp setting
define perforce::instance (
  $ensure           = undef, # one setting for all managed services
  # p4d settings
  $p4port           = '1666',  # just the port number
  $dns_name         = undef,   # DNS name of this server
  $server_id        = undef,
  $master_id        = 'master', # ID of the master
  $ssl              = false,
  $case_sensitive   = false,
  $p4d_version      = undef,
  # p4broker_settings
  $p4brokerport     = undef,
  $p4broker_version = undef,
  $p4broker_target  = undef,
  $depots_mountpoint = undef,  # option symlink to a mountpoint folder
  $adminuser        = $perforce::params::adminuser,
  $adminpass        = $perforce::params::adminpass,
  $servicepass      = $perforce::params::servicepass,
  $mailto           = undef,
  $mailfrom         = undef,
  $mailhost         = undef,
  $license          = undef
) {

  $instance_name = $title

  if $ssl {
    $ssl_prefix = 'ssl:'
  } else {
    $ssl_prefix = ''
  }

  case $ensure {
    'running': {
      $service_ensure = 'running'
      $service_enable = true
    }
    'stopped': {
      $service_ensure = 'stopped'
      $service_enable = false
    }
    default: {
      # undefined means don't manage
      #fail("Unknown ensure value '${ensure}'. Must be one of [running,stopped]")
    }
  }

  $osuser        = $perforce::sdp_base::osuser
  $osgroup       = $perforce::sdp_base::osuser
  $p4_dir        = $perforce::sdp_base::p4_dir
  $depotdata_dir = $perforce::sdp_base::depotdata_dir
  $metadata_dir  = $perforce::sdp_base::metadata_dir
  $logs_dir      = $perforce::sdp_base::logs_dir

  $p4_common     = "${p4_dir}/common"

  File {
    owner => $osuser,
    group => $osgroup,
    mode  => '0600',
  }

  # the perforce::sdp_base class ensures that the base software is installed and
  # available, so this needs to be declared
  if(!defined(Class['perforce::sdp_base'])) {
    fail('Usage: must declare perforce::sdp_base class before
          using this resource.')
  }

  # manage instance directory structure
  file { ["${depotdata_dir}/p4/${title}",
          "${depotdata_dir}/p4/${title}/bin",
          "${depotdata_dir}/p4/${title}/ssl",
          "${logs_dir}/p4/${title}",
          "${logs_dir}/p4/${title}/logs",
          "${logs_dir}/p4/${title}/logs/journals.rep"]:
      ensure => directory,
  }

  # manage top-level instance link
  if(!defined(File["${p4_dir}/${title}"])) {
    file { "${p4_dir}/${title}":
      ensure => 'link',
      target => "${depotdata_dir}/p4/${title}",
    }
  }

  # manage journals
  file { "${p4_dir}/${title}/journals.rep":
    ensure => 'link',
    target => "${logs_dir}/p4/${title}/journals.rep"
  }

  # manage link to instance log directory
  file { "${p4_dir}/${title}/logs":
    ensure => 'link',
    target => "${logs_dir}/p4/${title}/logs",
  }

  if $::kernel == 'Linux' {
    # add a link in standard linux log folder
    file { "/var/log/p4/${title}":
      ensure => 'link',
      target => "${logs_dir}/p4/${title}/logs"
    }
  }

  file { "${depotdata_dir}/common/config/.p4passwd.p4_${title}.admin":
    ensure  => 'file',
    content => $adminpass,
    require => File["${depotdata_dir}/common"]
  }

  file { "${depotdata_dir}/common/config/.p4passwd.p4_${title}.service":
    ensure  => 'file',
    content => $servicepass,
    require => File["${depotdata_dir}/common"]
  }

  ###################################################################
  ### MANAGE THE P4D INSTANCE
  if($p4port != undef) {

    if(!defined(Class['perforce::client'])) {
      fail('Usage: must declare perforce::client class before
            using this resource.')
    }

    if(!defined(Class['perforce::server'])) {
      fail('Usage: must declare perforce::server class before
            using this resource.')
    }


    if $p4d_version == undef {
      $p4d_instance_version = $perforce::sdp_base::p4d_version
    } else {
      $p4d_instance_version = $p4d_version
    }

    # manage instance directory p4d structure
    file { ["${depotdata_dir}/p4/${title}/checkpoints",
            "${depotdata_dir}/p4/${title}/tmp",
            "${metadata_dir}/p4/${title}",
            "${metadata_dir}/p4/${title}/db1",
            "${metadata_dir}/p4/${title}/db1/save",
            "${metadata_dir}/p4/${title}/db2",
            "${metadata_dir}/p4/${title}/db2/save",
            "${metadata_dir}/p4/${title}/offline_db"]:
        ensure => directory,
    }

    # optional symlink to depot mount
    if $depots_mountpoint != undef {
      file { "${depotdata_dir}/p4/${title}/depots":
        ensure  => 'link',
        target  => $depots_mountpoint,
        require => File[$depots_mountpoint]
      }
    } else {
      file { "${depotdata_dir}/p4/${title}/depots":
        ensure => 'directory'
      }
    }

    # manage server.id file if set
    if $serverid != undef {
      file { "${p4_dir}/${title}/root/server.id":
        ensure  => 'file',
        content => "${server_id}\n",
      }
    }

    if $license != undef {
      file { "${p4_dir}/${title}/root/license":
        ensure  => 'file',
        content => $license,
        mode    => '0600'
      }
    }

    # manage link to online directory
    file { "${p4_dir}/${title}/root":
      ensure => 'link',
      target => "${metadata_dir}/p4/${title}/db1",
    }

    # manage link to offline_db directory
    file { "${p4_dir}/${title}/offline_db":
      ensure => 'link',
      target => "${metadata_dir}/p4/${title}/db2",
    }

    # manage instance p4d service
    if $::kernel == 'Linux' {
      # service script
      file { "p4d_${title}_service":
        ensure => 'link',
        path   => "/etc/init.d/p4d_${title}",
        target => "${p4_dir}/${title}/bin/p4d_${title}_init",
        owner  => 'root',
        group  => 'root',
      }
      if $ensure != undef {
        # service
        service {"p4d_${title}":
          ensure => $service_ensure,
          enable => $service_enable,
        }
        $service_notifies = [Service["p4d_${title}"]]
      }
      else {
        $service_notifies = []
      }
    } else {
      $service_notifies = []
    }

    # manage instance variables file
    file { "p4_${title}.vars":
      ensure  => 'file',
      path    => "${p4_common}/config/p4_${title}.vars",
      mode    => '0700',
      content => template('perforce/instance_vars.erb'),
      notify  => $service_notifies,
    }

    # manage link to appropriate p4 client
    file { "p4_${title}":
      ensure => 'link',
      path   => "${p4_dir}/${title}/bin/p4_${title}",
      target => "${p4_common}/bin/p4_${p4d_instance_version}_bin",
      notify => $service_notifies,
    }

    # manage link to instance-specific p4d
    file { "p4d_${title}_bin":
      ensure => 'link',
      path   => "${p4_common}/bin/p4d_${title}_bin",
      target => "${p4_common}/bin/p4d_${p4d_instance_version}_bin",
      notify => $service_notifies,
    }

    # manage instance wrapper
    file { "p4d_${title}":
      ensure  => 'file',
      path    => "${p4_dir}/${title}/bin/p4d_${title}",
      content => template('perforce/instance_script.erb'),
      mode    => '0700',
      notify  => $service_notifies,
    }

    # manage instance init script
    file { "p4d_${title}_init":
      ensure  => 'file',
      path    => "${p4_dir}/${title}/bin/p4d_${title}_init",
      content => template('perforce/p4d_instance_init.erb'),
      mode    => '0700',
      notify  => $service_notifies,
    }

  } ### END MANAGE P4D INSTANCE

  ###################################################################
  ### MANAGE THE P4BROKER INSTANCE
  if($p4brokerport != undef) {

    if($p4brokerport != undef) {
      if(!defined(Class['perforce::broker'])) {
        fail('Usage: must declare perforce::broker class before
              using this resource.')
      }
    }

    if $p4broker_version == undef {
      $p4broker_instance_version = $perforce::sdp_base::p4broker_version
    } else {
      $p4broker_instance_version = $p4broker_version
    }

    if $p4broker_target == undef {
      if $p4port != undef {
        $target_port = "${ssl_prefix}localhost:${p4port}"
      } else {
        fail('unable to determine target port for p4broker')
      }
    } else {
      $target_port = $p4broker_target
    }

    # manage instance p4d service
    if($::kernel == 'Linux') {
      # service script
      file { "p4broker_${title}_service":
        ensure => 'link',
        path   => "/etc/init.d/p4broker_${title}",
        target => "${p4_dir}/${title}/bin/p4broker_${title}_init",
        owner  => 'root',
        group  => 'root',
      }
      # service
      service {"p4broker_${title}":
        ensure => $service_ensure,
        enable => $service_enable,
      }
    }

    # manage link to appropriate p4 client
    file { "p4broker_${title}":
      ensure => 'link',
      path   => "${p4_dir}/${title}/bin/p4broker_${title}",
      target => "${p4_common}/bin/p4broker_${p4broker_instance_version}_bin",
      notify => Service["p4broker_${title}"],
    }

    # manage link to instance-specific p4d
    file { "p4broker_${title}_bin":
      ensure => 'link',
      path   => "${p4_common}/bin/p4broker_${title}_bin",
      target => "${p4_common}/bin/p4broker_${p4broker_instance_version}_bin",
      notify => Service["p4broker_${title}"],
    }

    # manage instance variables file
    file { "p4_${title}.broker.cfg":
      ensure  => 'file',
      path    => "${p4_common}/config/p4_${title}.broker.cfg",
      mode    => '0700',
      content => template('perforce/broker_cfg.erb'),
      notify  => Service["p4broker_${title}"],
    }

    # manage instance init script
    file { "p4broker_${title}_init":
      ensure  => 'file',
      path    => "${p4_dir}/${title}/bin/p4broker_${title}_init",
      content => template('perforce/p4broker_instance_init.erb'),
      mode    => '0700',
      notify  => Service["p4broker_${title}"],
    }

  } ### END MANAGE P4BROKER INSTANCE








}
