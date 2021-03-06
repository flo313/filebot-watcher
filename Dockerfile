FROM openjdk:8u222-jre-slim

# Set Global Variables used by this container
ENV FILEBOT_VERSION=4.7.9 \
    CONFIG_DIR="/data" \
    USER_ID="1000" \
    GROUP_ID="1000" \
    USER_NAME="filebot" \
    WATCH_DIR="/input" \
    OUTPUT_DIR="/output"

# Set Java (for filebot) and CONFIG_FILE variables. Both are based on the previously set CONFIG_DIR variable
ENV CONFIG_FILE="$CONFIG_DIR/filebot.conf" \
    JAVA_OPTS="-DuseGVFS=false -Djava.net.useSystemProxies=false -Dapplication.deployment=docker -Dapplication.dir=$CONFIG_DIR -Duser.home=$CONFIG_DIR -Djava.io.tmpdir=$CONFIG_DIR/tmp -Djava.util.prefs.PreferencesFactory=net.filebot.util.prefs.FilePreferencesFactory -Dnet.filebot.util.prefs.file=$CONFIG_DIR/prefs.properties"

# Install all requirement.
RUN apt-get update && apt-get install -y \
    mediainfo \
    libchromaprint-tools \
    file \
    procps \
    curl \
    sudo \
    mutt \
    inotify-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Filebot
RUN mkdir -p /usr/share/filebot && cd /usr/share/filebot \
    && FILEBOT_PACKAGE=filebot_${FILEBOT_VERSION}_amd64.deb \
    && curl -L -O https://downloads.sourceforge.net/project/filebot/filebot/FileBot_$FILEBOT_VERSION/$FILEBOT_PACKAGE \
    && dpkg -i $FILEBOT_PACKAGE \
    && rm $FILEBOT_PACKAGE \
    && cd /

# Add and make executable all needed script and default config files
ADD start.sh /start.sh
ADD filebot.sh /files/filebot.sh
ADD filebot.conf /files/filebot.conf
ADD monitor.sh /files/monitor.sh
RUN \
    chmod +x /start.sh /files/filebot.sh /files/monitor.sh \
    && chmod +rw /files/filebot.conf

# Expose CONFIG_DIR folder for persistance
VOLUME ["$CONFIG_DIR"]

# Launch start script
ENTRYPOINT ["/start.sh"]
