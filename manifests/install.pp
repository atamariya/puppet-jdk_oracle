define jdk_oracle::install(
  $version        = '8',
  $version_update = 'default',
  $version_build  = 'default',
  $install_dir    = '/opt',
  $use_cache      = false,
  $cache_source   = 'puppet:///modules/jdk_oracle/',
  $platform       = 'x64',
  $jce            = false,
  $default_java   = true,
  $create_symlink = true,
  $ensure         = 'installed'
  ) {

  $default_8_update = '11'
  $default_8_build  = '12'
  $default_7_update = '67'
  $default_7_build  = '01'
  $default_6_update = '45'
  $default_6_build  = '06'

  if $ensure == 'installed' {
    # Set default exec path for this module
    Exec { path  => ['/usr/bin', '/usr/sbin', '/bin'] }

    case $platform {
      'x64': { $plat_filename = 'x64' }
      'x86': { $plat_filename = 'i586' }
      default: { fail("Unsupported platform: ${platform}.  Implement me?") }
    }

    case $version {
      '8': {
        if ($version_update != 'default') {
          $version_u = $version_update
        } else {
          $version_u = $default_8_update
        }
        if ($version_build != 'default'){
          $version_b = $version_build
        } else {
          $version_b = $default_8_build
        }
        $javaDownloadURI = "http://download.oracle.com/otn-pub/java/jdk/${version}u${version_u}-b${version_b}/jdk-${version}u${version_u}-linux-${plat_filename}.tar.gz"
        $java_home = "${install_dir}/jdk1.${version}.0_${version_u}"
        $jceDownloadURI = 'http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip'
      }
      '7': {
        if ($version_update != 'default'){
          $version_u = $version_update
        } else {
          $version_u = $default_7_update
        }
        if ($version_build != 'default'){
          $version_b = $version_build
        } else {
          $version_b = $default_7_build
        }
        $javaDownloadURI = "http://download.oracle.com/otn-pub/java/jdk/${version}u${version_u}-b${version_b}/jdk-${version}u${version_u}-linux-${plat_filename}.tar.gz"
        $java_home = "${install_dir}/jdk1.${version}.0_${version_u}"
      }
      '6': {
        if ($version_update != 'default'){
          $version_u = $version_update
        } else {
          $version_u = $default_6_update
        }
        if ($version_build != 'default'){
          $version_b = $version_build
        } else {
          $version_b = $default_6_build
        }
        $javaDownloadURI = "https://edelivery.oracle.com/otn-pub/java/jdk/${version}u${version_u}-b${version_b}/jdk-${version}u${version_u}-linux-${plat_filename}.bin"
        $java_home = "${install_dir}/jdk1.${version}.0_${version_u}"
      }
      default: {
        fail("Unsupported version: ${version}.  Implement me?")
      }
    }

    if ! defined(File[$install_dir]) {
      file { $install_dir:
        ensure  => directory,
      }
    }

    $installerFilename = inline_template('<%= File.basename(@javaDownloadURI) %>')

    if ( $use_cache ){
      file { "${install_dir}/${installerFilename}":
        source  => "${cache_source}${installerFilename}",
        require => File[$install_dir],
      } ->
      exec { "get_jdk_installer_${version}":
        cwd     => $install_dir,
        creates => "${install_dir}/jdk_from_cache",
        command => 'touch jdk_from_cache',
      }
    } else {
      exec { "get_jdk_installer_${version}":
        cwd     => $install_dir,
        creates => "${install_dir}/${installerFilename}",
        command => "wget -c --no-check-certificate --header \"Cookie: oraclelicense=accept-securebackup-cookie\" \"${javaDownloadURI}\" -O ${installerFilename}",
        timeout => 600,
        require => Package['wget'],
      }

      file { "${install_dir}/${installerFilename}":
        mode    => '0755',
        require => Exec["get_jdk_installer_${version}"],
      }

      if ! defined(Package['wget']) {
        package { 'wget':
          ensure =>  present,
        }
      }
    }

    # Java 7/8 comes in a tarball so just extract it.
    if ( $version in [ '7', '8' ] ) {
      exec { "extract_jdk_${version}":
        cwd     => "${install_dir}/",
        command => "tar -xf ${installerFilename}",
        creates => $java_home,
        require => Exec["get_jdk_installer_${version}"],
      }
    }
    # Java 6 comes as a self-extracting binary
    if ( $version == '6' ) {
      exec { "extract_jdk_${version}":
        cwd     => "${install_dir}/",
        command => "${install_dir}/${installerFilename}",
        creates => $java_home,
        require => File["${install_dir}/${installerFilename}"],
      }
    }

    # Ensure that files belong to root
    file {$java_home:
      recurse   => true,
      owner     => root,
      group     => root,
      subscribe => Exec["extract_jdk_${version}"],
    }

    # Set links depending on osfamily or operating system fact
    case $::osfamily {
      'RedHat', 'Linux': {
        if ( $default_java ) {
          file { '/etc/alternatives/java':
            ensure  => link,
            target  => "${java_home}/bin/java",
            require => Exec["extract_jdk_${version}"],
          }
          file { '/etc/alternatives/javac':
            ensure  => link,
            target  => "${java_home}/bin/javac",
            require => Exec["extract_jdk_${version}"],
          }
          file { '/etc/alternatives/jar':
            ensure  => link,
            target  => "${java_home}/bin/jar",
            require => Exec["extract_jdk_${version}"],
          }
          file { '/usr/sbin/java':
            ensure  => link,
            target  => '/etc/alternatives/java',
            require => File['/etc/alternatives/java'],
          }
          file { '/usr/sbin/javac':
            ensure  => link,
            target  => '/etc/alternatives/javac',
            require => File['/etc/alternatives/javac'],
          }
          file { '/usr/sbin/jar':
            ensure  => link,
            target  => '/etc/alternatives/jar',
            require => File['/etc/alternatives/jar'],
          }
        }
        if ( $create_symlink ) {
          file { "${install_dir}/java_home":
            ensure  => link,
            target  => $java_home,
            require => Exec["extract_jdk_${version}"],
          }
          file { "${install_dir}/jdk-${version}":
            ensure  => link,
            target  => $java_home,
            require => Exec["extract_jdk_${version}"],
          }
        }
      }
      'Debian':  {
        #Accommodate variations in default install locations for some variants of Debian
        $path_to_updatealternatives_tool = $::lsbdistdescription ? {
          /Ubuntu 14\.04.*/ => '/usr/bin/update-alternatives',
          /Linux Mint 17\.*/ => '/usr/bin/update-alternatives',
          default           => '/usr/sbin/update-alternatives',
        }

        if ( $default_java ) {
          # create alternatives configuration for the specified version
          exec { "${path_to_updatealternatives_tool} --install /usr/bin/java java ${java_home}/bin/java 20000":
            require => Exec["extract_jdk_${version}"],
            unless  => "test $(readlink /etc/alternatives/java) = '${java_home}/bin/java'",
          }
          exec { "${path_to_updatealternatives_tool} --install /usr/bin/javac javac ${java_home}/bin/javac 20000":
            require => Exec["extract_jdk_${version}"],
            unless  => "test $(/bin/readlink /etc/alternatives/javac) = '${java_home}/bin/javac'",
          }
          exec { "${path_to_updatealternatives_tool} --install /usr/bin/jar jar ${java_home}/bin/jar 20000":
            require => Exec["extract_jdk_${version}"],
            unless  => "test $(/bin/readlink /etc/alternatives/jar) = '${java_home}/bin/jar'",
          }
          exec { "${path_to_updatealternatives_tool} --install /usr/bin/jstack jstack ${java_home}/bin/jstack 20000":
            require => Exec["extract_jdk_${version}"],
            unless  => "test $(/bin/readlink /etc/alternatives/jstack) = '${java_home}/bin/jstack'",
          }
          # activate new alternatives configuration (in case of a version change)
          exec { "${path_to_updatealternatives_tool} --set java ${java_home}/bin/java":
            require => Exec["${path_to_updatealternatives_tool} --install /usr/bin/java java ${java_home}/bin/java 20000"],
            onlyif  => "test $(readlink /etc/alternatives/java) != '${java_home}/bin/java'",
          }
          exec { "${path_to_updatealternatives_tool} --set javac ${java_home}/bin/javac":
            require => Exec["${path_to_updatealternatives_tool} --install /usr/bin/javac javac ${java_home}/bin/javac 20000"],
            onlyif  => "test $(/bin/readlink /etc/alternatives/javac) != '${java_home}/bin/javac'",
          }
          exec { "${path_to_updatealternatives_tool} --set jar ${java_home}/bin/jar":
            require => Exec["${path_to_updatealternatives_tool} --install /usr/bin/jar jar ${java_home}/bin/jar 20000"],
            onlyif  => "test $(/bin/readlink /etc/alternatives/jar) != '${java_home}/bin/jar'",
          }
          exec { "${path_to_updatealternatives_tool} --set jstack ${java_home}/bin/jstack":
            require => Exec["${path_to_updatealternatives_tool} --install /usr/bin/jstack jstack ${java_home}/bin/jstack 20000"],
            onlyif  => "test $(/bin/readlink /etc/alternatives/jstack) != '${java_home}/bin/jstack'",
          }
          augeas { 'environment':
            context => '/files/etc/environment',
            changes => [
              "set JAVA_HOME ${java_home}",
            ],
          }
        }
      }
      'Suse': {
        if ( $default_java ) {
          include 'jdk_oracle::suse'
        }
      }

      default:   { fail("Unsupported OS: ${::osfamily}.  Implement me?") }
    }

    if ( $jce and $version == '8' ) {

      $jceFilename = inline_template('<%= File.basename(@jceDownloadURI) %>')
      $jce_dir = 'UnlimitedJCEPolicyJDK8'

      if ( $use_cache ) {
        file { "${install_dir}/${jceFilename}":
          source  => "${cache_source}${jceFilename}",
          require => File[$install_dir],
        } ->
        exec { 'get_jce_package':
          cwd     => $install_dir,
          creates => "${install_dir}/jce_from_cache",
          command => 'touch jce_from_cache',
        }
      } else {
        exec { 'get_jce_package':
          cwd     => $install_dir,
          creates => "${install_dir}/${jceFilename}",
          command => "wget -c --no-cookies --no-check-certificate --header \"Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com\" --header \"Cookie: oraclelicense=accept-securebackup-cookie\" \"${jceDownloadURI}\" -O ${jceFilename}",
          timeout => 600,
          require => Package['wget'],
        }

        file { "${install_dir}/${jceFilename}":
          mode    => '0755',
          require => Exec['get_jce_package'],
        }

      }

      exec { 'extract_jce':
        cwd     => "${install_dir}/",
        command => "unzip ${jceFilename}",
        creates => "${install_dir}/${jce_dir}",
        require => [ Exec['get_jce_package'], Package['unzip'] ],
      }

      file { "${java_home}/jre/lib/security/README.txt":
        ensure  => 'present',
        source  => "${install_dir}/${jce_dir}/README.txt",
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        require => Exec['extract_jce'],
      }

      file { "${java_home}/jre/lib/security/local_policy.jar":
        ensure  => 'present',
        source  => "${install_dir}/${jce_dir}/local_policy.jar",
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        require => Exec['extract_jce'],
      }

      file { "${java_home}/jre/lib/security/US_export_policy.jar":
        ensure  => 'present',
        source  => "${install_dir}/${jce_dir}/US_export_policy.jar",
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        require => Exec['extract_jce'],
      }

    }

  }

}
