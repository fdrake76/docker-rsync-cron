#!/bin/sh

set -e

# Make sure that the group and users specified by the user exist
if ! getent group "${RSYNC_GID}" &>/dev/null; then
    addgroup -g "${RSYNC_GID}" "rsynccron"
fi
RSYNC_GROUP="$(getent group "${RSYNC_GID}" | cut -d: -f1)"

if ! getent passwd "${RSYNC_UID}" &>/dev/null; then
    adduser -u "${RSYNC_UID}" -H "rsynccron" "${RSYNC_GROUP}"
fi
RSYNC_USER="$(getent passwd "${RSYNC_UID}" | cut -d: -f1)"

if ! getent group "${RSYNC_GROUP}" | grep "${RSYNC_USER}" &>/dev/null; then
    addgroup "${RSYNC_USER}" "${RSYNC_GROUP}"
fi

# Create a rsync script, makes it easier to sudo
cat << EOF > /run-rsync.sh
set -e
echo ""
echo "***********************"
echo "Running rsync process at \$(date)"
echo "***********************"
sudo -u "${RSYNC_USER}" -g "${RSYNC_GROUP}" \
    rsync \
        ${RSYNC_OPTIONS} \
        ${RSYNC_SRC}/ \
        ${RSYNC_DEST}
EOF
chmod +x /run-rsync.sh

# Setup our crontab entry
export CRONTAB_ENTRY="${RSYNC_CRONTAB} sh /run-rsync.sh"

echo "Setting Timezone..."
cp /usr/share/zoneinfo/${TZ} /etc/localtime
echo "${TZ}" > /etc/timezone
echo "Current time is now $(date)"

echo "Preparing SSH..."
ssh-keygen -A

echo "Starting SSH server..."
exec /usr/sbin/sshd -e &

echo "Initialization complete."
