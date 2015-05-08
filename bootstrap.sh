#!/bin/bash

TOGGLEFILE="/etc/default/vagrant-bootstrap-is-done"

# parameters
HOSTS=$(echo "$1" | tr ";" "\n")

# we want to add changes to /etc/hosts in every provision run
echo "Updating /etc/hosts"
cat /etc/hosts | grep -v 127.0.1.1 | grep -v localhost > /etc/hosts.new
echo "127.0.0.1 localhost" >> /etc/hosts.new

for HOST in $HOSTS
do
    echo "$HOST" | tr "," " " >> /etc/hosts.new
done

# remove duplicate lines
sort -u /etc/hosts.new > /etc/hosts

if ! test -e $TOGGLEFILE; then
  # yum conf
  yum clean all
cat >/etc/yum.repos.d/CentOS-Base.repo  <<"EOF"
# CentOS-Base.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the 
# remarked out baseurl= line instead.
#
#

[base]
name=CentOS-$releasever - Base
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os&infra=$infra
#baseurl=http://mirror.centos.org/centos/$releasever/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates 
[updates]
name=CentOS-$releasever - Updates
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates&infra=$infra
#baseurl=http://mirror.centos.org/centos/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras&infra=$infra
#baseurl=http://mirror.centos.org/centos/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus&infra=$infra
#baseurl=http://mirror.centos.org/centos/$releasever/centosplus/$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
  yum makecache
  yum -y install redhat-lsb-core tree bash-completion subversion git rsync vim gawk perl-XML-Simple perl-DBI
  yum -y update

  echo "Setting timezone"
  cp -fv /usr/share/zoneinfo/Europe/Berlin /etc/localtime
  echo 'ZONE="Europe/Berlin"'   >/etc/sysconfig/clock
  echo 'UTC=true'               >>/etc/sysconfig/clock
  echo 'ARC=false'              >>/etc/sysconfig/clock

  echo "Generating some locales"
  localedef -c -i de_DE -f UTF-8 de_DE.UTF-8

  echo "Prepare SPON bootstrap"
  cat >/usr/local/bin/spon_bootstrap.sh <<EOF
if test ! -f /etc/default/vagrant-spon-bootstrap-is-done; then
  groupadd -g 2020 deployuser
  groupadd -g 2000 spgroup
  useradd -u 2020 -g 2020 -d /home/deployuser -m deployuser
  mkdir -p /data/{cgi-bin,conf,dumps,export,import,install,logs,pages,src,status,virtual,jboss} /data/var/{apache,SPNET}
  mkdir -p /server/{ant,bin,etc,jar,jdk,lib,oracle,sql,www,xml} /server/www/apache
  chown -R deployuser:spgroup /data/{cgi-bin,conf,dumps,export,import,install,jboss,logs,pages,src,status,var,virtual} /server/{ant,bin,xml,etc,jar,jdk,lib,oracle,sql,www,xml} 
  chmod 2775 /data/status
  ln -s /server/lib /usr/share/perl5/SPIEGELNET
  ln -s /usr/bin/perl /usr/local/bin/perl
  touch /etc/profile.d/spon.sh
  chown deployuser:spgroup /etc/profile.d/spon.sh
  svn --no-auth-cache export http://svn.spiegel.de/repos/commons/admin/trunk/component/ALL /data/src/ALL
  rsync -r /data/src/ALL/server/. /server/.
  rsync -r /data/src/ALL/data/. /data/.
  rsync -r /data/src/ALL/etc/. /etc/.
  touch /etc/default/vagrant-spon-bootstrap-is-done
fi
EOF
  cat >>/home/vagrant/.bashrc <<EOF
if ! test -f /etc/default/vagrant-spon-bootstrap-is-done; then
  sudo sh /usr/local/bin/spon_bootstrap.sh
fi
EOF

  echo "Configuration done"
  touch $TOGGLEFILE
else
  echo "Togglefile $TOGGLEFILE found, assuming shell provision has already been executed."
  echo "You can remove $TOGGLEFILE to run the shell provision again."
fi
