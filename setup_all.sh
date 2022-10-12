#!/bin/bash

# Make a list of packages you may need. I like having vim... the others are bare minimum. 
# I recommend adding others as you find you need here so if you need to reinstall you're not losing anything.
yum install vim -y
yum install nano -y
yum install nfs-utils -y
yum install tk tcl tcsh -y

mkdir -p /apps

echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
      ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
      10.20.28.205 revontuli-hpl-instance" > /etc/hosts

# /etc/fstab tells the OS what to mount
echo "LABEL=cloudimg-rootfs / ext4 defaults 0 1" > /etc/fstab
echo "LABEL=MKFS_ESP /boot/efi vfat defaults 0 2" >> /etc/fstab
echo "revontuli-hpl-instance:/home /home nfs defaults 0 0" >> /etc/fstab
echo "revontuli-hpl-instance:/apps /apps nfs defaults 0 0" >> /etc/fstab

mount -a

# Copy our etc hosts over. Make sure you grab the version you just made.
cp /home/cc/setup/hosts /etc/
# Need to set a few things here to make slurm work
# Also having stack size set to unlimited is important. Super super common to run into problems without it.
cp /home/cc/setup/limits.conf /etc/security/

# These should already be present through NFS
useradd -m -u 1500 leopekka
useradd -m -u 1600 ilmari
useradd -m -u 1700 huy
useradd -m -u 1800 roope
useradd -m -u 1900 matias
useradd -m -u 2000 niklas

# This sets up the slurm users

export MUNGEUSER=1001
groupadd -g $MUNGEUSER munge
useradd  -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGEUSER -g munge  -s /sbin/nologin munge
export SLURMUSER=1002
groupadd -g $SLURMUSER slurm
useradd  -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSER -g slurm  -s /bin/bash slurm

# Installs packages and sets permissions

yum install munge munge-libs munge-devel -y

#####
#####
# Copy the headnode munge key into /home/cc and copy it here
#####
#####

cp /home/cc/munge.key /etc/munge

chown -R munge: /etc/munge/ /var/log/munge/ /var/lib/munge/ /run/munge/
chmod 0700 /etc/munge/ /var/log/munge/ /var/lib/munge/ /run/munge/
chmod 711 /run/munge/

systemctl enable munge
systemctl start munge

# Take the RPMs you built earlier and drop here, or change the cd below.
mkdir -p /home/cc/slurm_setup/rpms
cd /home/cc/slurm_setup/rpms

yum install perl openssl openssl-devel pam-devel rpm-build numactl numactl-devel hwloc hwloc-devel lua lua-devel readline-devel rrdtool-devel ncurses-devel man2html libibmad libibumad mysql-devel -y
wget https://download.schedmd.com/slurm/slurm-22.05.3.tar.bz2

rpmbuild -ta slurm-22.05.3.tar.bz2

cd /root/rpmbuild/RPMS/x86_64/

yum --nogpgcheck localinstall slurm-* -y

# Every node should have the same copy of slurm.conf. If you change it, be sure to copy it around
echo "AuthType=auth/munge
  DbdAddr=10.20.28.205
  DbdHost=revontuli-hpl-instance
  SlurmUser=slurm
  DebugLevel=4
  LogFile=/var/log/slurm/slurmdbd.log
  PidFile=/var/run/slurmdbd.pid
  StorageType=accounting_storage/mysql
  StorageHost=revontuli-hpl-instance
  StoragePass=some_pass
  StorageUser=slurm
  StorageLoc=slurm_acct_db" >> /etc/slurm/slurmdbd.conf

cp /home/cc/setup/slurm.conf /etc/slurm/

cp /home/cc/setup/cgroup.conf /etc/slurm/

mkdir /var/spool/slurmd
chown slurm: /var/spool/slurmd
chmod 755 /var/spool/slurmd
mkdir /var/log/slurm/
touch /var/log/slurm/slurmd.log
chown -R slurm:slurm /var/log/slurm/slurmd.log

systemctl enable slurmd.service
systemctl start slurmd.service


##
# Add a part for installing IB drivers for all nodes
##
