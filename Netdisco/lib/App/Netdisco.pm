package App::Netdisco;

use strict;
use warnings FATAL => 'all';
use 5.010_000;

use File::ShareDir 'dist_dir';
use Path::Class;

our $VERSION = '2.018000_001';

BEGIN {
  if (not ($ENV{DANCER_APPDIR} || '')
      or not -f file($ENV{DANCER_APPDIR}, 'config.yml')) {

      my $auto = dir(dist_dir('App-Netdisco'))->absolute;
      my $home = ($ENV{NETDISCO_HOME} || $ENV{HOME});

      $ENV{DANCER_APPDIR}  ||= $auto->stringify;
      $ENV{DANCER_CONFDIR} ||= $auto->stringify;

      my $test_envdir = dir($home, 'environments')->stringify;
      $ENV{DANCER_ENVDIR} ||= (-d $test_envdir
        ? $test_envdir : $auto->subdir('environments')->stringify);

      $ENV{DANCER_ENVIRONMENT} ||= 'deployment';
      $ENV{PLACK_ENV} ||= $ENV{DANCER_ENVIRONMENT};

      $ENV{DANCER_PUBLIC} ||= $auto->subdir('public')->stringify;
      $ENV{DANCER_VIEWS}  ||= $auto->subdir('views')->stringify;
  }

  {
      # Dancer 1 uses the broken YAML.pm module
      # This is a global sledgehammer - could just apply to Dancer::Config
      use YAML;
      use YAML::XS;
      no warnings 'redefine';
      *YAML::LoadFile = sub { goto \&YAML::XS::LoadFile };
  }
}

# set up database schema config from simple config vars
use Dancer ':script';

if (ref {} eq ref setting('database')) {
    my $name = (setting('database')->{name} || 'netdisco');
    my $host = (setting('database')->{host} || 'localhost');
    my $user = (setting('database')->{user});
    my $pass = (setting('database')->{pass});

    # set up the netdisco schema now we have access to the config
    # but only if it doesn't exist from an earlier config style
    setting('plugins')->{DBIC}->{netdisco} ||= {
        dsn => (sprintf 'dbi:Pg:dbname=%s;host=%s', $name, $host),
        user => $user,
        pass => $pass,
        options => {
            AutoCommit => 1,
            RaiseError => 1,
            auto_savepoint => 1,
        },
        schema_class => 'App::Netdisco::DB',
    };

}

# static configuration for the in-memory local job queue
setting('plugins')->{DBIC}->{daemon} = {
    dsn => 'dbi:SQLite:dbname=:memory:',
    options => {
        AutoCommit => 1,
        RaiseError => 1,
        sqlite_use_immediate_transaction => 1,
    },
    schema_class => 'App::Netdisco::Daemon::DB',
};

=head1 NAME

App::Netdisco - An open source web-based network management tool.

=head1 Introduction

Netdisco is a web-based network management tool designed for network
administrators. Data is collected into a PostgreSQL database using SNMP.

Some of the things you can do with Netdisco:

=over 4

=item *

B<Locate> a machine on the network by MAC or IP and show the switch port it
lives at

=item *

B<Turn off> a switch port, or change the VLAN or PoE status of a port

=item *

B<Inventory> your network hardware by model, vendor, software and operating
system

=item *

B<Pretty pictures> of your network

=back

L<App::Netdisco> provides a web frontend with built-in web server, and a
backend daemon to handle interactive requests such as changing port or device
properties.

=over 4

=item *

See the demo at: L<http://netdisco2-demo.herokuapp.com/>

=back

If you have any trouble getting the frontend running, speak to someone in the
C<#netdisco> IRC channel (on freenode). Before installing or upgrading please
review the latest L<Release Notes|App::Netdisco::Manual::ReleaseNotes>.

=head1 Dependencies

Netdisco has several Perl library dependencies which will be automatically
installed. However it's I<strongly> recommended that you first install
L<DBD::Pg> and L<SNMP> using your operating system packages. The following
commands will test for the existence of them on your system:

 perl -MDBD::Pg\ 999
 perl -MSNMP\ 999

You'll also need a compiler for some of the other Perl dependencies. For
example on Ubuntu/Debian, install the C<build-essential> package. On
Fedora/Red-Hat, install C<make>, C<automake>, and C<gcc>.

With those installed, we can proceed...

Create a user on your system called C<netdisco> if one does not already exist.
We'll install Netdisco and its dependencies into this user's home area, which
will take about 250MB including MIB files.

 root:~# useradd -m -p x -s /bin/bash netdisco

Netdisco uses the PostgreSQL database server. Install PostgreSQL and then change
to the PostgreSQL superuser (usually C<postgres>). Create a new database and
PostgreSQL user for the Netdisco application:

 root:~# su - postgres
  
 postgres:~$ createuser -DRSP netdisco
 Enter password for new role:
 Enter it again:
  
 postgres:~$ createdb -O netdisco netdisco

=head1 Installation

The following is a general guide which works well in most circumstances. It
assumes you have a user C<netdisco> on your system, that you want to perform
an on-line installation, and have the application run self-contained from
within that user's home. There are alternatives: see the
L<Deployment|App::Netdisco::Manual::Deployment> documentation for further
details.

To avoid muddying your system, use the following script to download and
install Netdisco and its dependencies into the C<netdisco> user's home area
(C<~netdisco/perl5>):

 su - netdisco
 curl -L http://cpanmin.us/ | perl - --notest --verbose --local-lib ~/perl5 App::Netdisco

Link some of the newly installed apps into a handy location:

 mkdir ~/bin
 ln -s ~/perl5/bin/{localenv,netdisco-*} ~/bin/

Test the installation by running the following command, which should only
produce a status message (and throw up no errors):

 ~/bin/netdisco-daemon status

=head1 Configuration

Make a directory for your local configuration and copy the configuration
template from this distribution:

 mkdir ~/environments
 cp ~/perl5/lib/perl5/auto/share/dist/App-Netdisco/environments/deployment.yml ~/environments
 chmod +w ~/environments/deployment.yml

Edit the file and change the database connection parameters to match those for
your local system (that is, the C<name>, C<host>, C<user> and C<pass>).

In the same file uncomment and edit the C<domain_suffix> setting to be
appropriate for your local site. Optionally, set the C<no_auth> value to true
if you wish to skip user authentication in the web interface.

=head1 Bootstrap

The database either needs configuring if new, or updating from the current
release of Netdisco (1.x). You also need vendor MAC address prefixes (OUI
data) and some MIBs if you want to run the daemon. The following script will
take care of all this for you:

 ~/bin/netdisco-deploy

Answer yes to all questions, if this is a new installation of Netdisco 2.

=head1 Startup

Run the following command to start the web-app server as a backgrounded daemon
(listening on port 5000):

 ~/bin/netdisco-web start

If the Inventory is empty because this is a new installation, you probably
want to run some polling jobs. This can be done from from the web interface or
command-line (see L<netdisco-do>).

Run the following command to start the job control daemon (port control, etc):

 ~/bin/netdisco-daemon start

You should take care not to run this Netdisco daemon and the Netdisco 1.x
daemon at the same time. Similarly, if you use the device discovery with
Netdisco 2, disable your system's cron jobs for the Netdisco 1.x poller.

At this point you can revisit the C<~/environments/deployment.yml> file to
uncomment more configuration. Check out the community string settings, and
C<housekeeping> which enables the automatic periodic device discovery. See
L<Configuration|App::Netdisco::Manual::Configuration> for further details.

=head1 Upgrading

Before upgrading please review the latest L<Release
Notes|App::Netdisco::Manual::ReleaseNotes>. Then, the process is as follows:

 # upgrade Netdisco
 ~/bin/localenv cpanm --notest App::Netdisco
 
 # apply database schema updates
 ~/bin/netdisco-deploy
 
 # restart web service
 ~/bin/netdisco-web restart
 
 # restart job daemon (if you use it)
 ~/bin/netdisco-daemon restart

=head1 Tips and Tricks

=head2 Searching

The main black navigation bar has a search box which is smart enough to work
out what you're looking for in most cases. For example device names, node IP
or MAC addreses, VLAN numbers, and so on.

=head2 Command-Line Device and Port Actions

To run a device (discover, etc) or port control job from the command-line, use
the bundled L<netdisco-do> program. For example:

 ~/bin/netdisco-do -D discover -d 192.0.2.1

=head2 Import Topology

Netdisco 1.x had support for a topology information file to fill in device
port relations which could not be discovered. This is now stored in the
database (and edited in the web interface). To import a legacy topology file,
run:

 ~/bin/localenv nd-import-topology /path/to/netdisco-topology.txt

=head2 Deployment Scenarios

More documentation on how to deploy the application in other scenarios, for
example behind a web proxy, is in the
L<Deployment|App::Netdisco::Manual::Deployment> documentation.

=head2 Database API

Bundled with this distribution is a L<DBIx::Class> layer for the Netdisco
database. This abstracts away all the SQL into an elegant, re-usable OO
interface. See the L<Developer|App::Netdisco::Manual::Developing>
documentation for further information.

=head2 Plugins

Netdisco includes a Plugin subsystem for customizing the web user interface.
See L<App::Netdisco::Web::Plugin> for further information.

=head2 Developing

Lots of information about the architecture of this application is contained
within the L<Developer|App::Netdisco::Manual::Developing> documentation.

=head1 Caveats

The Wireless, IP Phone and NetBIOS Node properies are not yet shown.

=head1 AUTHOR

Oliver Gorwits <oliver@cpan.org>

=head1 COPYRIGHT AND LICENSE
 
This software is copyright (c) 2012, 2013 by The Netdisco Developer Team.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the Netdisco Project nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE NETDISCO DEVELOPER TEAM BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1;
