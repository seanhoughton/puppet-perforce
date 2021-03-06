# perforce::sdp_base class
#
# @summary Used to manage the base SDP installation
#
# @example
#   class { '::perforce::sdp_base':
#    osuser => 'perforce',
#    osgroup => 'perforce',
#    p4_dir => '/p4',
#   }
#
# @param osuser            Operating system user that will own the SDP directories and executables.
# @param osuser_password   Operating system password (only used if osuser_manage is `true`).
# @param osgroup           Operating system group that will own the SDP directories and executables.
# @param osuser_manage     If true, this module will create and manage user and group.
# @param p4_dir            The base SDP directory. Defaults to `/p4` on Linux systems.
# @param depotdata_dir.    The mountpoint for the Perforce depot data.
# @param metadata_dir.     The mountpoint for the Perforce metadata.
# @param logs_dir          The mountpoint for the Perforce and SDP log files. This mountpoint must already exist.
# @param sslprefix         The default ssl prefix to use (e.g. `ssl:`).
# @param sdp_version       The SDP version to manage
# @param staging_base_path The location where the binaries will be staged on the local node's filesystem.
# @param default_file_mode The default rwx mode for managed files
#
#
class perforce::sdp_base (
  $osuser               = $perforce::params::osuser,
  $osuser_password      = $perforce::params::osuser_password,
  $osgroup              = $perforce::params::osgroup,
  $osuser_manage        = true,
  $p4_dir               = $perforce::params::p4_dir,
  $depotdata_dir        = $perforce::params::depotdata_dir,
  $metadata_dir         = $perforce::params::metadata_dir,
  $logs_dir             = $perforce::params::logs_dir,
  $sslprefix            = $perforce::params::sslprefix,
  $sdp_version          = $perforce::params::sdp_version,
  $staging_base_path    = $perforce::params::staging_base_path,
  $default_file_mode    = $perforce::params::default_file_mode,
) inherits perforce::params {

  case $::kernel {
    'Linux': {
      class {'perforce::sdp_base_unix':
      }
    }
    'Windows': {
      class {'perforce::sdp_base_windows':
      }
    }
    default: {
      fail("${::kernel} is not supported with this module")
    }
  }


  File {
    ensure => 'file',
    owner  => $osuser,
    group  => $osgroup,
    mode   => $default_file_mode,
  }

  if $osuser_manage {
    if !defined(Group[$osgroup]) {
      group { $osgroup:
        ensure => 'present'
      }
    }

    if !defined(User[$osuser]) {
      if $perforce::params::sdp_type == 'Unix' {
        user { $osuser:
          ensure   => 'present',
          password => $osuser_password,
          gid      => $osgroup,
          home     => $p4_dir,
        }
      } else {
        user { $osuser:
          ensure   => 'present',
          password => $osuser_password,
          groups   => $osgroup,
        }
      }
    }
  }

  ensure_resource('file', splitpath($p4_dir), { ensure => 'directory' })
  ensure_resource('file', splitpath("${depotdata_dir}/p4"), { ensure => 'directory' })
  ensure_resource('file', splitpath("${metadata_dir}/p4"), { ensure => 'directory' })
  ensure_resource('file', splitpath("${logs_dir}/p4"), { ensure => 'directory' })

  if(!defined(Class['staging'])) {
    class { 'staging':
      path  => $staging_base_path,
    }
  }

  staging::file { $perforce::params::sdp_distro:
    source => "puppet:///modules/perforce/${perforce::params::sdp_distro}"
  }

  staging::extract { $perforce::params::sdp_distro:
    target  => $depotdata_dir,
    creates => "${depotdata_dir}/sdp",
    require => Staging::File[$perforce::params::sdp_distro],
  }

  file { "${p4_dir}/Version":
    source  => "file:///${depotdata_dir}/sdp/Version",
    require => Staging::Extract[$perforce::params::sdp_distro],
  }

  file { "${depotdata_dir}/common":
    source  => "file:///${depotdata_dir}/sdp/Server/${perforce::params::sdp_type}/p4/common",
    recurse => true,
    require => Staging::Extract[$perforce::params::sdp_distro],
  }

  if $perforce::params::sdp_type == 'Unix' {
    file { "${depotdata_dir}/common/bin/create_links.sh":
      mode    => '0700',
      source  => 'puppet:///modules/perforce/create_links.sh',
      require => Staging::Extract[$perforce::params::sdp_distro],
    }
  }

  file { "${p4_dir}/common":
    ensure => 'symlink',
    target => "${depotdata_dir}/common",
  }

  file { "${p4_dir}/sdp":
    ensure => 'symlink',
    target => "${depotdata_dir}/sdp",
  }

  file { "${p4_dir}/ssl":
    ensure => 'directory',
  }

  file { "${p4_dir}/common/config":
    ensure => 'directory',
  }

  file { "${p4_dir}/common/bin/p4_vars":
    content => template('perforce/p4_vars.erb')
  }

  file { '/var/log/p4':
    ensure => 'directory',
    owner  => $osuser,
    group  => $osgroup
  }

  if $adminpass {
    file { "${p4_dir}/common/bin/adminpass":
      mode    => '0400',
      content => $adminpass,
    }
  }

}
