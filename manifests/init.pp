# == Class: etckeeper
#
# Configure and install etckeeper. Works for debian-like and
# redhat-like systems.
#
# === Parameters
#
# [*etckeeper_author*]
#   Author name to use when committing (user.name).
#   Default: false (do not set)
#
# [*etckeeper_email*]
#   Email to use when committing (user.email).
#   Default: false (do not set)
#
# === Variables
#
# [*etckeeper_high_pkg_mgr*]
#   OS dependent config setting, HIGHLEVEL_PACKAGE_MANAGER.
#
# [*etckeeper_low_pkg_mgr*]
#   OS dependent config setting, LOWLEVEL_PACKAGE_MANAGER.
#
# === Examples
#
#   include etckeeper
#
# To set the author and email for git commits:
#
#   class { 'etckeeper':
#     etckeeper_author => 'root',
#     etckeeper_email  => "root@${::fqdn}",
#   }
#
# === Authors
#
# Thomas Van Doren
#
# === Copyright
#
# Copyright 2012, Thomas Van Doren, unless otherwise noted
#
class etckeeper (
  $etckeeper_author = false,
  $etckeeper_email = false,
  $vcs = git,
  ) {

  case $vcs {
    'hg': {
      require ::mercurial
    }
    'git': {
      require ::git
    }
  }

  # HIGHLEVEL_PACKAGE_MANAGER config setting.
  $etckeeper_high_pkg_mgr = $facts[os][name] ? {
    /(?i-mx:ubuntu|debian|linuxmint)/                 => 'apt',
    /(?i-mx:centos|fedora|redhat|oraclelinux|amazon)/ => 'yum',
    /(?i-mx:rocky|almalinux)/                         => 'yum',
  }

  # LOWLEVEL_PACKAGE_MANAGER config setting.
  $etckeeper_low_pkg_mgr = $facts[os][name] ? {
    /(?i-mx:ubuntu|debian|linuxmint)/                 => 'dpkg',
    /(?i-mx:centos|fedora|redhat|oraclelinux|amazon)/ => 'rpm',
    /(?i-mx:rocky|almalinux)/                         => 'rpm',
  }

  Package {
    ensure => present,
  }

  package { 'etckeeper':
    require => File['etckeeper.conf'],
  }

  file { '/etc/etckeeper':
    ensure => directory,
    mode   => '0755',
  }

  file { 'etckeeper.conf':
    ensure  => present,
    path    => '/etc/etckeeper/etckeeper.conf',
    owner   => root,
    group   => root,
    mode    => '0644',
    content => template('etckeeper/etckeeper.conf.erb'),
  }

  exec { 'etckeeper-init':
    command => 'etckeeper init',
    path    => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    cwd     => '/etc',
    creates => '/etc/.git',
    require => Package['etckeeper'],
  }

  file { 'etckeeper-cron-daily':
    ensure  => present,
    path    => '/etc/cron.daily/etckeeper',
    owner   => root,
    group   => root,
    mode    => '0755',
    content => template('etckeeper/cron_daily.erb'),
  }

  file { 'etckeeper-daily-script':
    ensure  => present,
    path    => '/etc/etckeeper/daily',
    owner   => root,
    group   => root,
    mode    => '0755',
    content => template('etckeeper/script_daily.erb'),
  }

  # Bugfix on Debian: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=884987
  if ( $operatingsystem == 'Debian' and Integer($facts['os']['release']['major']) <= 11 ) {
    file { 'etckeeper-precommit-problemfiles':
        ensure  => present,
        path    => '/etc/etckeeper/pre-commit.d/20warn-problem-files',
        owner   => root,
        group   => root,
        mode    => '0755',
        content => template('etckeeper/Debian-20warn-problem-files'),
    }
  }
}
