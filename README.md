# docker-rsync-cron

This is a fork of dkruger/docker-rsync-cron which adds the following features:

* The source and destination rsync directories can be configured
* Timezone is configurable
* SSH support for acting as either a remote source or remote destination

This is a cronjob docker container which is used to regularly sync two
docker volumes using rsync.

This image is based off of
[dkruger/cron](https://hub.docker.com/r/dkruger/cron/) which provides a simple
cron implementation. The cron daemon is used to execute `rsync` which will
copy the contents of the `rsync_src` volume to the `rsync_dst` volume. The
specific options are configurable via environment variables.

Checkout the [example docker-compose.yml](example/docker-compose.yml) for an
exmaple of setting up the container with named NFS volumes using `Netshare`.

## Using the image

The image is configurable via environment variables for configuring the rsync
command settings:

* `RSYNC_CRONTAB`: The crontab time entry, defaults to nightly at midnight
* `RSYNC_OPTIONS`: Flags passed to `rsync`, defaults to
`-av --stats --timeout=3600`
* `RSYNC_UID`: The UID to use when calling rsync, defaults to 0
* `RSYNC_GID`: The GID to use when calling rsync, defaults to 0
* `RSYNC_SRC`: The source directory used by rsync, defaults to `/rsync_src`
* `RSYNC_DEST`: The destination directory used by rsync, defaults to `/rsync_dst`
* `TZ`: The timezone used for the container as defined in the [list of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones), defaults to `UTC`

The image defines two volumes: `/rsync_src`, and `/rsync_dst`. The contents of
`/rsync_src` will be copied to `/rsync_dst` on the interval defined by the
crontab entry.

The `rsync` command is called using the format `rsync /rsync_src/ /rsync_dst`,
so that the *contents* of `/rsync_src` will be copied no the directory itself.

Here is an example command for executing the container two rsync two NFS mounts
using the `Netshare` volume plugin:
```bash
docker run \
    --name my-nfs-sync \
    --volume-driver=nfs \
    -v master-svr/volume1/master:/rsync_src \
    -v local-svr/export:/rsync_dst \
    -e RSYNC_OPTIONS="--archive --timeout=3600 --delete"
    dkruger/rsync-cron:latest
```

### SSH Example
This fork also spins up an SSH server, allowing for remote rsync connections.  There is a small bit of additional configuration:

For both the client and server containers, mount a volume to `/etc/ssh` which will store the configuration file, along with the private and public keys for the SSH server.  Upon start, it will auto-populate with the files.

For the server container, do the following:
* Expose port 22 from the container to any outside port number you wish.
* In the /etc/ssh/sshd_config, set the following:
  * PermitRootLogin yes
  * AuthorizedKeysfile /etc/ssh/authorized_keys
* Populate /etc/ssh/authorized keys with the public key that is in the client's `/etc/ssh` directory.

#### Docker Compose Server Example
This runs rsync locally at 2am eastern time as well as persists a SSH server on port 15050 for a remote client.

```
version: "2"
services:
  image: fdrake/rsync-cron
  environment:
      RSYNC_OPTIONS: -av --stats --timeout=3600
      RSYNC_CRONTAB: 0 2 * * *
      RSYNC_DEST: /rsync_dst/local_server
      TZ: America/New_York
    volumes:
      - backup_etcssh:/etc/ssh
      - local_data_volume_i_want_backed_up:/rsync_src/local_data_volume_i_want_backed_up
      - archive_volume:/rsync_dst
    ports:
      - 15050:22
    restart: unless-stopped
volumes:
	backup_etcssh:
	  external: true
	local_data_volume_i_want_backed_up:
	  external: true
	archive_volume:
	  external: true
```

#### Docker Compose Client Example
This connects to the server on 15050 and backs up the volumes local to this container over to the remote server's destination.

```
version: "2"
services:
  image: fdrake/rsync-cron
  environment:
    RSYNC_OPTIONS: -e "ssh -o StrictHostKeyChecking=no -i /etc/ssh/ssh_host_rsa_key -p 15050" -av --stats --timeout=3600
    RSYNC_CRONTAB: 30 0 * * *
    TZ: America/New_York
    RSYNC_DEST: root@server2:/rsync_dst/remote_server
  volumes:
    - client_backup_etcssh:/etc/ssh
    - data_i_want_backed_up:/rsync_src/data_i_want_backed_up
    - another_volume_i_want_backed_up:/rsync_src/another_volume_i_want_backed_up
  restart: unless-stopped
volumes:
  client_backup_etcssh:
    external: true
  data_i_want_backed_up:
    external: true
  another_volume_i_want_backed_up:
    external: true
```

## About permissions

Depending on your volume store, permissions might be an issue. For example some
NAS implementations are very picky when it comes to the UID and GID of the
process reading/writing. As such you may need to specify a UID and GID that has
the correct permissions for the volumes. Note that these are the ID numbers,
not the names.
