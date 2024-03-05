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
# [*vcs*]
#   Choice of version control system
#
# [*vcsignore*]
#   To add or remove lines to and from a vcs' respective ignore file
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
  Array[Hash] $vcsignore = [],
  ) {

  case $vcs {
    'hg': {
      require ::mercurial
      $ignorefile="/etc/.hgignore"
    }
    'git': {
      require ::git
      $ignorefile="/etc/.gitignore"
    }
    default: {
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

  $vcsignore.each | $str | {
    $ignored_file=$str['entry']
    $cmd=$str['cmd']

    case $cmd {
      'ins': {
        augeas { "etckeeper_ignore_${ignored_file}":
          lens    => "Simplelines.lns",
          incl    => $ignorefile,
          context => "/files/${ignorefile}",
          onlyif  => "match *['${ignored_file}'] size == 0",
          # eerst label maken, dan setten. gewoon nieuw inserten kan niet.
          # de last functie zet laatste entry met bepaald label, binnen de context is dit "alles" (*)
          # volgnummers zijn arbitrair maar hebben bij inladen geen leading zero ...
          changes => ["ins 003 after *[last()]", "set 003 ${ignored_file}"],
          require => [Exec['etckeeper-init'], Package['etckeeper']],
        }
      }
      'rm': {
        augeas { "etckeeper_ignore_${ignored_file}":
          lens    => "Simplelines.lns",
          incl    => $ignorefile,
          context => "/files/${ignorefile}",
          changes => ["rm *['${ignored_file}']"],
          require => [Exec['etckeeper-init'], Package['etckeeper']],
        }
      }
      default: {
        fail("${cmd} is niet aanvaard")
      }
    }
  }

  exec { 'etckeeper-init':
    command => 'etckeeper init',
    path    => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    cwd     => '/etc',
    creates => "/etc/.${vcs}",
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
  if ( $facts['os']['name'] == 'Debian' and Integer($facts['os']['release']['major']) <= 11 ) {
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
