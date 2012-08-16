#!/bin/bash
####################################################
# Collective-Intelligence-Framework/
# Website: http://code.google.com/p/collective-intelligence-framework/
#
# Script Written by Silas Cutler (Silas.Cutler@BlackListThisDomain.com)
#
# Dessigned for Automatic Building on Ubuntu 12.04 
# AMI: Ubuntu Cloud Guest AMI ID ami-82fa58eb (x86_64)
####################################################

clear
echo "WARNING: This script is not perfect.  Be sure you carefully watch for errors to ensure that nothing breaks.  Some user"
echo "         actions are required, so make sure you are watching for when you need to hit enter or answer some questions"
echo "         Also, this script can take up to 10 hours to run.  You may want to run it in a screen session"
echo "         "
echo "         Make sure you run as root"
echo "         "
echo "         For CPAN, when asks 'What approach do you want? ', select sudo "
echo "         "
sleep 10



##############################################
## Installing Needed Files
##############################################
clear
echo "Installing Needed Files"
apt-get update
apt-get install -y vim aptitude build-essential make gcc g++ libcrypt-ssleay-perl
aptitude install -y rng-tools postgresql apache2 apache2-threaded-dev gcc make libexpat-dev libapache2-mod-perl2 libclass-dbi-perl libdigest-sha1-perl libnet-cidr-perl libossp-uuid-perl libxml-libxml-perl libxml2-dev libmodule-install-perl libapache2-request-perl libdbd-pg-perl bind9 libregexp-common-perl libxml-rss-perl libapache2-mod-gnutls libapreq2-dev libjson-perl rsync libunicode-string-perl libconfig-simple-perl libmodule-pluggable-perl libmime-lite-perl libfile-type-perl libtext-csv-perl libio-socket-inet6-perl libapr1-dbg libhtml-table-perl libcrypt-ssleay-perl libdigest-sha-perl pkg-config torrus-common



cpan 
cpan CIF::Client
cpan LWP::Protocol::https
cpan Net::Abuse::Utils
cpan XML::Compile
cpan XML::IODEF
cpan XML::Malware
cpan DateTime::Format::DateParse
cpan Regexp::Common::net::CIDR
cpan Apache2::REST
cpan Text::Table
cpan Linux::Cpuinfo
cpan VT::API
cpan Date::Manip
cpan Class::Load::XS
##############################################
## Disk Layout
##############################################
clear
echo "Creating Disk Layout"

mkdir /opt/cif/
mkdir /opt/cif/archive
mkdir /opt/cif/index
chown postgres:postgres /opt/cif/index
chown postgres:postgres /opt/cif/archive
chmod 770 /opt/cif/index
chmod 770 /opt/cif/archive

##############################################
## Setting up Apache and DB
##############################################
clear
echo "Setting up Apache and DB config"

sudo a2ensite default-ssl
sudo a2enmod apreq
sudo a2enmod ssl
perl -pi -e "s/NameVirtualHost \*:80/#NameVirtualHost *:80/" /etc/apache2/ports.conf
perl -pi -e "s/Listen 80/#Listen 80/" /etc/apache2/ports.conf
perl -pi -e "s/<VirtualHost _default_:443>/<VirtualHost _default_:443>\n      PerlRequire \/opt\/cif\/bin\/webapi.pl\n      Include \/etc\/apache2\/cif.conf\n/" /etc/apache2/sites-enabled/default-ssl

echo '<Location /api> ' >> /etc/apache2/cif.conf
echo '    SetHandler perl-script' >> /etc/apache2/cif.conf
echo '    PerlSetVar Apache2RESTHandlerRootClass "CIF::WebAPI::Plugin"' >> /etc/apache2/cif.conf
echo '    PerlSetVar Apache2RESTAPIBase "/api"' >> /etc/apache2/cif.conf
echo '    PerlResponseHandler Apache2::REST' >> /etc/apache2/cif.conf
echo "    PerlSetVar Apache2RESTWriterDefault 'json'" >> /etc/apache2/cif.conf
echo "    PerlSetVar Apache2RESTAppAuth 'CIF::WebAPI::AppAuth'" >> /etc/apache2/cif.conf
echo ' ' >> /etc/apache2/cif.conf
echo '    # feed defaults' >> /etc/apache2/cif.conf
echo '    PerlSetVar CIFLookupLimitDefault 500' >> /etc/apache2/cif.conf
echo '    PerlSetVar CIFDefaultFeedSeverity "high"' >> /etc/apache2/cif.conf
echo ' ' >> /etc/apache2/cif.conf
echo '    # extra outputs ' >> /etc/apache2/cif.conf
echo "    PerlAddVar Apache2RESTWriterRegistry 'table'" >> /etc/apache2/cif.conf
echo "    PerlAddVar Apache2RESTWriterRegistry 'CIF::WebAPI::Writer::table'" >> /etc/apache2/cif.conf
echo '</Location>' >> /etc/apache2/cif.conf

sudo adduser www-data cif
service apache2 restart

mv /etc/postgresql/9.1/main/pg_hba.conf /etc/postgresql/9.1/main/pg_hba.conf.bak
echo "local   all         postgres                          trust " >> /etc/postgresql/9.1/main/pg_hba.conf 
echo "local   all         all                               trust " >> /etc/postgresql/9.1/main/pg_hba.conf 
echo "host    all         all         127.0.0.1/32          trust " >> /etc/postgresql/9.1/main/pg_hba.conf
echo "host    all         all         ::1/128               trust " >> /etc/postgresql/9.1/main/pg_hba.conf
sudo /etc/init.d/postgresql restart

##############################################
## Starting CIF 
##############################################
clear
echo "Starting CIF Install"

adduser --disabled-password --gecos '' cif
cd ~/
wget http://collective-intelligence-framework.googlecode.com/files/cif-0.02.tar.gz
tar -zxvf cif-0.02.tar.gz
cd cif-0.02
./configure
make testdeps
make fixdeps
sudo make install
sudo make initdb
make tables

cd /home/cif

su cif -c "echo '' >> ~/.profile"
su cif -c "echo 'if [ -d "/opt/cif/bin" ]; then ' >> ~/.profile"
su cif -c "echo '    PATH="/opt/cif/bin:$PATH" ' >> ~/.profile"
su cif -c "echo 'fi' >> ~/.profile"
su cif -c "echo '' >> ~/.profile"

su cif -c "echo '' >> ~/.bashrc"
su cif -c "echo 'if [ -d "/opt/cif/bin" ]; then ' >> ~/.bashrc"
su cif -c "echo '    PATH="/opt/cif/bin:$PATH" ' >> ~/.bashrc"
su cif -c "echo 'fi' >> ~/.bashrc"
su cif -c "echo '' >> ~/.bashrc"

su cif -c "mkdir backups"


su cif -c "/opt/cif/bin/cif_apikeys -u default_auto_get@localhost -a -g everyone -G everyone"
su cif -c "/opt/cif/bin/cif_apikeys -u role_everyone_feed -a -g everyone -G everyone"

su cif -c "KEY=`/opt/cif/bin/cif_apikeys -u cif -a -g everyone -G everyone | tail -n 1 | awk '{ print $2 }'`"

su cif -c 'echo "[client]" >> ~/.cif'
su cif -c 'echo "host = https://localhost:443/api" >> ~/.cif'
su cif -c 'echo "timeout = 60" >> ~/.cif'
su cif -c 'echo "verify_tls = 0" >> ~/.cif'
su cif -c 'echo "apikey = $KEY" >> ~/.cif'
su cif -c 'echo "" >> ~/.cif'
su cif -c 'echo "" >> ~/.cif'
su cif -c 'echo "[cif_feeds]" >> ~/.cif'
su cif -c 'echo "maxrecords = 10000" >> ~/.cif'
su cif -c 'echo "severity_feeds = high,medium" >> ~/.cif'
su cif -c 'echo "confidence_feeds = 95,85" >> ~/.cif'
su cif -c 'echo "apikeys = role_everyone_feed" >> ~/.cif'
su cif -c 'echo "max_days = 2" >> ~/.cif'
su cif -c 'echo "disabled_feeds = hash,rir,asn,countrycode,malware" >> ~/.cif'
su cif -c 'echo "" >> ~/.cif'
su cif -c 'echo "" >> ~/.cif'

cd /opt/cif/etc
su cif -c 'cp custom.cfg.example custom.cfg'
su cif -c 'chmod 660 custom.cfg'


##############################################
## Initializing CIF 
##############################################
clear
echo "Starting Initial processing"

KEY=`/opt/cif/bin/cif_apikeys -u cif -a -g everyone -G everyone | tail -n 1 | awk '{ print $2 }'`

echo "[client]" >> ~/.cif
echo "host = https://localhost:443/api" >> ~/.cif
echo "timeout = 60" >> ~/.cif
echo "verify_tls = 0" >> ~/.cif
echo "apikey = $KEY" >> ~/.cif
echo "" >> ~/.cif
echo "" >> ~/.cif
echo "[cif_feeds]" >> ~/.cif
echo "maxrecords = 10000" >> ~/.cif
echo "severity_feeds = high,medium" >> ~/.cif
echo "confidence_feeds = 95,85" >> ~/.cif
echo "apikeys = role_everyone_feed" >> ~/.cif
echo "max_days = 2" >> ~/.cif
echo "disabled_feeds = hash,rir,asn,countrycode,malware" >> ~/.cif
echo "" >> ~/.cif
echo "" >> ~/.cif


time /opt/cif/bin/cif_crontool -f -d && /opt/cif/bin/cif_crontool -d -p daily && /opt/cif/bin/cif_crontool -d -p hourly
time /opt/cif/bin/cif_analytic -d -t 5 -m 2500
time /opt/cif/bin/cif_feeds -d

echo "# set the path " >> /etc/cron.d/cif
echo "PATH=/bin:/usr/local/bin:/opt/cif/bin" >> /etc/cron.d/cif
echo "" >> /etc/cron.d/cif
echo "# run analytics" >> /etc/cron.d/cif
echo "*/2 * * * * /opt/cif/bin/cif_analytic -d -t 4 -m 4000 >> /home/cif/analytics.log 2>&1" >> /etc/cron.d/cif
echo "" >> /etc/cron.d/cif
echo "# pull feed data" >> /etc/cron.d/cif
echo "05     *       * * * /opt/cif/bin/cif_crontool -p hourly -T low >> /home/cif/crontool_hourly.log 2>&1" >> /etc/cron.d/cif
echo "30     00      * * * /opt/cif/bin/cif_crontool -p daily -T low >> /home/cif/crontool_daily.log 2>&1" >> /etc/cron.d/cif
echo "" >> /etc/cron.d/cif
echo "# update the feeds" >> /etc/cron.d/cif
echo "45     *       * * * /opt/cif/bin/cif_feeds >> /home/cif/feeds.log 2>&1" >> /etc/cron.d/cif

service cron restart
