# perforce::server class
#   - used to manage the p4d binary
class perforce::server (
  String $p4d_version           = $perforce::params::p4d_version,
  String $p4d_executable        = $perforce::params::p4d_executable,
  String $source_location_base  = $perforce::params::source_location_base,
  String $dist_dir              = $perforce::params::dist_dir,
  Optional[String] $install_dir = undef,
  String $staging_base_path     = $perforce::params::staging_base_path,
  Boolean $refresh_staged_file  = $perforce::params::refresh_staged_file,
  String $default_install_dir   = $perforce::params::default_install_dir,
  String $default_os_user       = $perforce::params::default_os_user,
  String $default_os_group      = $perforce::params::default_os_group,
) inherits perforce::params {

  $p4d_version_short = regsubst($p4d_version, '^20', '', 'G')
  $source_location   = "${source_location_base}/r${p4d_version_short}/${dist_dir}/${p4d_executable}"

  if(!defined(Class['staging'])) {
    class { 'staging':
      path  => $staging_base_path,
    }
  }

  $staged_file_location = "${staging_base_path}/${module_name}/${p4d_executable}"

  if $refresh_staged_file {
    file {'clear_staged_p4d':
      ensure => 'absent',
      path   => $staged_file_location,
    }
  }

  staging::file { $p4d_executable:
    source => $source_location,
  }

  if $install_dir == undef {
    if defined(Class['perforce::sdp_base']) {
      $actual_install_dir = "${perforce::sdp_base::p4_dir}/common/bin"
      $p4d_owner = $perforce::sdp_base::osuser
      $p4d_group = $perforce::sdp_base::osgroup
      exec { 'create_p4d_links':
        command     => "${perforce::sdp_base::p4_dir}/common/bin/create_links.sh p4d",
        cwd         => "${perforce::sdp_base::p4_dir}/common/bin",
        refreshonly => true,
        user        => $p4d_owner,
        group       => $p4_group,
        subscribe   => File['p4d'],
      }
    } else {
      $actual_install_dir = $default_install_dir
      $p4_owner = $default_os_user
      $p4_group = $default_os_group
    }
  } else {
    $actual_install_dir = $install_dir
    $p4_owner = $default_os_user
    $p4_group = $default_os_group
  }

  if !defined(File[$actual_install_dir]) {
    notice("### managing dir: ${actual_install_dir}")
    file { $actual_install_dir:
      ensure => 'directory',
      owner  => $p4_owner,
      group  => $p4_group,
      mode   => '0777',
      before => File['p4d'],
    }
  }

  file {'p4d':
    ensure  => file,
    path    => "${actual_install_dir}/${p4d_executable}",
    mode    => '0700',
    owner   => $p4d_owner,
    group   => $p4d_group,
    source  => "file:///${staged_file_location}",
    require => Staging::File[$p4d_executable],
  }

}
