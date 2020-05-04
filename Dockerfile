FROM dkruger/cron:latest

ENV \
    RSYNC_CRONTAB="0 0 * * *" \
    RSYNC_OPTIONS="-av --stats --timeout=3600" \
    RSYNC_UID="0" \
    RSYNC_GID="0" \
    RSYNC_SRC="/rsync_src" \
    RSYNC_DEST="/rsync_dst" \
    TZ="UTC" \

RUN set -x; \
    apk add --no-cache --update rsync sudo openssh tzdata \
    && rm -rf /tmp/* \
    && rm -rf /var/cache/apk/*

VOLUME ["/rsync_src", "/rsync_dst"]

COPY rsync-entrypoint.sh /entrypoint.d/rsync.sh
