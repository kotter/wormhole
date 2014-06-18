#!/bin/bash

user=$1
pubkey=$2
if test -z $user ; then
  echo "Usage: $(basename $0) <username> <pubkey>" 2> /dev/null
  exit 1
fi

source ./global.conf

cat > data <<EOF
FROM   busybox
RUN    mkdir -p /home/user
VOLUME ["/home/user", "/media/state/etc/ssh"]
CMD    ["/bin/true"]
EOF

# build new data image and remove intermediate containers
docker rmi data 2> /dev/null
cat data | docker build --rm -t data -

# create tiny data container named $user-data
docker rm $user-data 2> /dev/null
docker run -v /home/user -v /media/state/etc/ssh --name $user-data busybox true

# remove the data image since we no longer need it
docker rmi data

# add contents of /etc/skel into data container
docker run --rm --volumes-from $user-data -u root $base_image cp /etc/skel/.bash* /home/user

# fix ownership of homedir
docker run --rm --volumes-from $user-data -u root $base_image chown -R user:user /home/user

# add sshd host keys
docker run --rm --volumes-from $user-data -u root $base_image ssh-keygen -q -f /media/state/etc/ssh/ssh_host_dsa_key -N '' -t dsa
docker run --rm --volumes-from $user-data -u root $base_image ssh-keygen -q -f /media/state/etc/ssh/ssh_host_rsa_key -N '' -t rsa

# add ssh keys
docker run --rm --volumes-from $user-data -u user $base_image mkdir -p /home/user/.ssh
docker run --rm --volumes-from $user-data -u user $base_image chmod 0700 /home/user/.ssh
docker run --rm --volumes-from $user-data -u user $base_image /bin/bash -c "echo $pubkey > /home/user/.ssh/authorized_keys"
docker run --rm --volumes-from $user-data -u user $base_image chmod 0600 /home/user/.ssh/authorized_keys

# create a container from the user image
docker run -d -t -m $max_ram --volumes-from $user-data -P -h $sandbox_hostname --name $user $base_image
port=$(docker port $user 22 | cut -d: -f2)
docker stop $user
docker rm $user

# Make the container persistent.
sudo cp -f wormhole@.service /etc/systemd/system/
sudo mkdir -p /etc/wormhole || :
echo -e "PORT=$port\n" | sudo tee /etc/wormhole/$user
sudo systemctl enable wormhole@$user
sudo systemctl start wormhole@$user
sleep 2
sudo systemctl status wormhole@$user
