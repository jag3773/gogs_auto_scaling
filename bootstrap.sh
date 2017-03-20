#!/bin/bash -xe

# Install necessary system packages
yum -y install rsync screen tmux vim-enhanced telnet wget mysql puppet git nfs-utils nginx

# Setup small swap space
dd if=/dev/zero of=/swapfile bs=1M count=512
chmod 600 /swapfile
mkswap /swapfile
echo '/swapfile   none        swap    sw              0   0' >> /etc/fstab
swapon -a

# Get latest puppet
chkconfig puppet off
rm -rf /etc/puppet
git clone https://github.com/unfoldingWord-dev/gogs_auto_scaling.git /etc/puppet

# Mount configuration volume
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone).fs-acfe3f05.efs.us-west-2.amazonaws.com:/ /config/

# Link SSH
rsync -havP --delete /config/ssh/ /etc/ssh/
service sshd restart
/bin/cp -f /config/private/authorized_keys /root/.ssh/
/bin/cp -f /config/private/authorized_keys /home/ec2-user/.ssh/
chown ec2-user:ec2-user /home/ec2-user/.ssh/authorized_keys
/bin/cp -f /config/private/my.cnf /etc/

# Run puppet
puppet apply /etc/puppet/manifests/site.pp --summarize
puppet apply /etc/puppet/manifests/site.pp -e 'include gogs' --summarize

# Add mount for EBS volume
echo 'UUID=feb25d8e-68b2-424c-a2cb-37619cd6741a /mnt ext4 defaults,noatime,nofail 0 2' >>/etc/fstab

# Reboot for good measure
reboot
