if $server_values == undef {
  $server_values = hiera('server', false)
}

$www_domain = $server_values['domain'] ? {
  undef   => 'hackdinium.dev',
  default => $server_values['domain']
}

$home_dir     = "/home/${::ssh_username}"
$puppet_dir   = '/conf/puppet'
$puppet_files = "${puppet_dir}/files"

Class['apt::update'] -> Package <|
    title != 'python-software-properties'
and title != 'software-properties-common'
|>

Exec { path => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/', '/usr/local/bin', '/usr/local/sbin' ] }

include apt

if ! defined(Package['augeas-tools']) {
  package { 'augeas-tools':
    ensure => present,
  }
}

group { 'puppet':   ensure => present }
group { 'www-data': ensure => present }
group { 'www-user': ensure => present }

user { [ 'nginx', 'www-data']:
  shell  => '/bin/bash',
  ensure => present,
  groups => 'www-data',
  require => Group['www-data']
}

user { $::ssh_username:
  shell   => '/bin/bash',
  home    => $home_dir,
  ensure  => present,
  groups  => [ 'www-data', 'www-user' ],
  require => [ Group['www-data'], Group['www-user'] ]
}

file { $home_dir:
  ensure => directory,
  owner  => $::ssh_username,
}

# copy dot files to ssh user's home directory
exec { 'dotfiles':
  cwd     => $home_dir,
  command => "cp -r $puppet_files/dot/.[a-zA-Z0-9]* $home_dir/ \
              && chown -R ${::ssh_username} $home_dir/.[a-zA-Z0-9]* \
              && cp -r $puppet_files/dot/.[a-zA-Z0-9]* /root/",
  onlyif  => "test -d $puppet_files/dot",
  returns => [0, 1],
  require => User[$::ssh_username]
}

if is_array($server_values['packages']) and count($server_values['packages']) > 0 {
  each( $server_values['packages'] ) |$package| {
    if ! defined(Package[$package]) {
      package { "${package}":
        ensure => present
      }
    }
  }
}

include '::mongodb::server'
include 'scala'

class { 'nginx': }
class { 'ntp': }

file { '/var/www':
  ensure => 'directory'
}

class { 'hhvm':
  compile_from_source => false,
  port                => '9001',
  date_timezone       => "America/Los_Angeles",
  require             => File['/var/www/']
}

exec { 'hhvm-files':
  cwd     => $home_dir,
  command => "cp -r ${puppet_files}/hhvm/[a-zA-Z0-9]* /etc/hhvm/",
  onlyif  => "test -d ${puppet_files}/hhvm",
  returns => [0, 1],
  require => User[$::ssh_username]
}

class { "vim":
  user     => $::ssh_username,
  home_dir => $home_dir,
}

# Install vim plugins from config values.
if is_hash($server_values['vim']['plugins']) and count($server_values['vim']['plugins']) > 0 {
  create_resources(vim::plugin, $server_values['vim']['plugins'])
}

# Install .vimrc settings from config values.
if is_hash($server_values['vim']['rc']) and count($server_values['vim']['rc']) > 0 {
  create_resources(vim::rc, $server_values['vim']['rc'])
}

# Setting auto_update to true will cause issues with hhvm.
# To update composer, just remove the binary and reload --provision.
class { 'composer':
  auto_update => false,
  require     => Class['hhvm']
}

wget::fetch { 'composer-bash-completion':
  source      => 'https://raw.githubusercontent.com/iArren/composer-bash-completion/master/composer',
  destination => '/etc/bash_completion.d/composer',
  cache_file  => 'composer',
  require     => Class['composer']
}

$sbt_launch_version = '0.13.5'
$sbt_launch_dir     = "/usr/bin/.lib/${sbt_launch_version}"

file { [ '/usr/bin/.lib', $sbt_launch_dir]:
  ensure => 'directory',
  owner  => 'root',
  group  => 'root'
}

wget::fetch { 'sbt-launch':
  source      => "http://typesafe.artifactoryonline.com/typesafe/ivy-releases/org.scala-sbt/sbt-launch/${sbt_launch_version}/sbt-launch.jar",
  destination => "/usr/bin/.lib/${sbt_launch_version}/sbt-launch.jar",
  cache_file  => 'sbt-launch.jar',
  require     => File[$sbt_launch_dir]
}

$vindinium_base   = '/var/www/vindinium'
$vindinium_client = "${vindinium_base}/client"
$vindinium_target = "${vindinium_base}/target"
$vindinium_dist   = "${vindinium_target}/universal"

vcsrepo { 'vindinium-src':
  path     => $vindinium_base,
  ensure   => present,
  provider => git,
  source   => "git://github.com/ornicar/vindinium.git",
  owner    => $::ssh_username,
  group    => $::ssh_username,
  require  => [ Package['scala'], Wget::Fetch['sbt-launch'] ],
  notify   => Exec['sbt compile']
}

package { 'openjdk-7-jdk':
  ensure => present
}

class { '::nodejs':
  manage_package_repo       => false,
  legacy_debian_symlinks    => true,
  nodejs_dev_package_ensure => 'present',
  npm_package_ensure        => 'present',
}

package { 'grunt-cli':
  ensure   => 'present',
  provider => 'npm',
  require  => Class['::nodejs'],
}

exec { 'vindinium-client-build':
  command     => 'build.sh',
  cwd         => $vindinium_client,
  path        => ['/bin', '/usr/bin', '/usr/local/bin', $vindinium_client],
  timeout     => 600,
  tries       => 3,
  user        => $::ssh_username,
  group       => $::ssh_username,
  creates     => "${vindinium_base}/public/bundle.min.js",
  refreshonly => false,
  require     => [ Class['::nodejs'], Package['grunt-cli'] ]
}

exec { 'sbt compile':
  cwd         => $vindinium_base,
  timeout     => 10000,
  user        => $::ssh_username,
  group       => $::ssh_username,
  creates     => $vindinium_target,
  refreshonly => false,
  require     => [ Class['::nodejs'], Exec['vindinium-client-build'], Package['openjdk-7-jdk'] ]
}

exec { 'sbt stage':
  cwd         => $vindinium_base,
  timeout     => 10000,
  user        => $::ssh_username,
  group       => $::ssh_username,
  creates     => $vindinium_dist,
  refreshonly => false,
  require     => Exec['sbt compile']
}

nginx::resource::vhost { "${www_domain}":
  listen_port          => 80,
  use_default_location => false
}

nginx::resource::location { "${www_domain}--root":
  vhost                => "${www_domain}",
  location             => '/',
  proxy                => "http://127.0.0.1:9000/",
  proxy_read_timeout   => '24h',
  location_cfg_append  => {
    proxy_http_version => '1.1'
  }
}

file { 'vindinium-upstart':
  path    => '/etc/init/vindinium.conf',
  ensure  => 'file',
  owner   => 'root',
  group   => 'root',
  source  => "${puppet_files}/upstart/vindinium.conf",
  require => [ Exec['sbt stage'], Service['mongodb'], Nginx::Resource::Vhost["${www_domain}"] ]
}

service { 'vindinium':
  ensure     => running,
  enable     => true,
  hasstatus  => true,
  hasrestart => true,
  require    => File['vindinium-upstart']
}
