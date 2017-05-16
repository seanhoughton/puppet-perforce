# perforce

Note: this is a fork of [alan_petersen-puppet](https://swarm.workshop.perforce.com/projects/alan_petersen-puppet) which has been updated to use the latest SDP along with some Puppet fixes.

#### Table of Contents
1. [Module Description - What the module does and why it is useful](#module-description)
1. [Setup - The basics of getting started with Perforce](#setup)
  * [Common Attributes - ](#common-attributes)
  * [Perforce Client (p4) - command-line client used to interact with a Perforce service](#perforce-client)
  * [Perforce Server (p4d) - the main Perforce service](#perforce-server)
  * [Perforce Broker (p4broker) - the Perforce broker component](#perforce-broker)
1. [Server Deployment Package - managing the SDP with Puppet](#server-deployment-package)
  * [Managing Instances - managing service (p4d and p4broker) instances](#managing-instances)

## Module Description

The Perforce module installs, configures, and manages the various Perforce components.

> NOTE: This module is currently under development. I thought I'd release it to the forge as it's
> progressed pretty well, but there are still several things that are being modified.
>
> Specifically:
> * Documentation -- docs are a work in progress (aren't they always??)
> * Tests -- basic unit tests are in the `examples` directory, but rspec tests are still forthcoming
> * Windows Support -- still needs some work so right now it's not enabled
> * Other Product Support -- later I want to expand this to Proxy (p4p), P4Web, etc. support but
> initially I am focussed on p4, p4d, and p4broker

This is the perforce module. It provides the ability to manage Perforce client
and server components, within an SDP (Server Deployment Package) environment.

## Setup

### Getting Started with Perforce

#### Perforce Client

##### Usage

If you want the Perforce command-line client (p4) managed with the default options you can declare

    include '::perforce::client

If you need to customize options, such as the p4 version to manage or the install location, you can pass in the attributes:


    class { '::perforce::client':
      p4_version    => '2016.2',
      install_dir   => '/usr/local/bin',
    }


When installing in an SDP (Server Deployment Package) environment, ensure that the `perforce::sdp_base` class is declared. If declared, then the client software will be installed in the /p4/common/bin directory and the associated version and symbolic links will be created. When installing in an SDP environment, do not specify the install_dir attribute, as the install location should be controlled by the SDP installation.


    include ::perforce::sdp_base
    include ::perforce::client


#### Perforce Server

> NOTE: This class is used to manage the p4d binaries on the node, but it does not manage an instance.
> Instances can be managed using the defined type `perforce::instance`, but this type does require
> that the SDP is also being managed.

##### Usage

If you want the Perforce service (p4d) managed with the default options you can declare

    include '::perforce::server'

If you need to customize options, such as the p4d version to manage or the install location, you can pass in the attributes:


    class { '::perforce::server':
      p4d_version   => '2016.2',
      install_dir   => '/usr/local/bin',
    }


When installing in an SDP (Server Deployment Package) environment, ensure that the `perforce::sdp_base` class is declared. If declared, then the software will be installed in the /p4/common/bin directory and the associated version and symbolic links will be created. When installing in an SDP environment, do not specify the install_dir attribute, as the install location should be controlled by the SDP installation.

The SDP requires that a Perforce client also be present, so typically the `perforce::client` class should also be declared

    include ::perforce::sdp_base
    include ::perforce::client
    include ::perforce::server


#### Perforce Broker

> NOTE: This class is used to manage the p4broker binaries on the node, but it does not manage an instance.
> Instances can be managed using the defined type `perforce::instance`, but this type does require
> that the SDP is also being managed.

##### Usage

If you want the Perforce broker service (p4broker) managed with the default options you can declare

    include '::perforce::broker'

If you need to customize options, such as the p4broker version to manage or the install location, you can pass in the attributes:


    class { '::perforce::broker':
      p4broker_version => '2016.2',
      install_dir      => '/usr/local/bin',
    }


When installing in an SDP (Server Deployment Package) environment, ensure that the `perforce::sdp_base` class is declared. If declared, then the software will be installed in the /p4/common/bin directory and the associated version and symbolic links will be created. When installing in an SDP environment, do not specify the install_dir attribute, as the install location should be controlled by the SDP installation.

The SDP requires that a Perforce client also be present, so typically the `perforce::client` class should also be declared


    include ::perforce::sdp_base
    include ::perforce::client
    include ::perforce::broker


### Server Deployment Package

The Perforce SDP provides a sample implementation of best practices, such as performing offline checkpoints, rotating logs and journals routinely, and doing a database sanity/safety check before starting the server. It is open source and available at [https://swarm.workshop.perforce.com/projects/perforce-software-sdp](https://swarm.workshop.perforce.com/projects/perforce-software-sdp)

#### SDP Commmon Files

##### Usage

The `perforce::sdp_base` class manages the base SDP installation. To declare this class and accept the default attribute values, you can use

    include '::perforce::sdp_base'

If you need to customize options, such as the OS user to manage or the install location, you can pass in the attributes:


    class { '::perforce::sdp_base':
      osuser => 'perforce',
      osgroup => 'perforce',
      p4_dir => '/p4',
    }


#### Managing Instances

##### Usage

Instances can only be managed within the context of an existing `perforce::sdp_base` installation. Managed instances can be server, broker, or both.

The `perforce::instance` defined type requires that

For example, to create a p4d instance called '1' with the server_id 'master', declare the following:


    include ::perforce::sdp_base
    include ::perforce::client
    include ::perforce::server

    ::perforce::instance {'1':
      server_id    => 'master',
      ensure       => 'running',
      p4port       => '1666',
    }




.
