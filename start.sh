#!/bin/bash

function ts {
  echo "[`date '+%Y-%m-%d %T'`] start.sh:"
}
#----------------------------------------------------------------------------------------------------
#function initialize_configuration {
#  if [ ! -f $CONFIG_DIR/filebot.conf ]
#  then
#    echo "$(ts) Creating default filebot.conf in User Dir"
#    cp /files/filebot.conf $CONFIG_DIR/filebot.conf
#    chmod a+w $CONFIG_DIR/filebot.conf
#  fi
#
#  if [ ! -f $CONFIG_DIR/filebot.sh ]
#  then
#    echo "$(ts) Creating default filebot.sh in User Dir"
#    cp /files/filebot.sh $CONFIG_DIR/filebot.sh
#  fi
#}
##----------------------------------------------------------------------------------------------------
#function check_filebot_sh_version {
#  USER_VERSION=$(grep '^VERSION=' $CONFIG_DIR/filebot.sh 2>/dev/null | sed 's/VERSION=//')
#  CURRENT_VERSION=$(grep '^VERSION=' /files/filebot.sh | sed 's/VERSION=//')
#
#  echo "$(ts) Comparing user's filebot.sh at version $USER_VERSION versus current version $CURRENT_VERSION"
#
#  if [ -z "$USER_VERSION" ] || [ "$USER_VERSION" -lt "$CURRENT_VERSION" ]
#  then
#    echo "$(ts)   Copying the new script to User Dir $CONFIG_DIR/filebot.sh.new"
#    echo "$(ts)   Save filebot.sh to reset its timestamp, then restart the container."
#    cp /files/filebot.sh $CONFIG_DIR/filebot.sh.new
#    exit 1
#  fi
#}
#---------------------------------------------------------------------------------------------------
#function setup_opensubtitles_account {
#  . $CONFIG_DIR/filebot.conf
#
#  if [ "$OPENSUBTITLES_USER" != "" ]; then
#    echo "$(ts) Configuring for OpenSubtitles user \"$OPENSUBTITLES_USER\""
#    echo -en "$OPENSUBTITLES_USER\n$OPENSUBTITLES_PASSWORD\n" | /files/runas.sh $USER_ID $GROUP_ID $UMASK filebot -script fn:configure
#  else
#    echo "$(ts) No OpenSubtitles user set. Skipping setup..."
#  fi
#}
#---------------------------------------------------------------------------------------------------
function check_config {
  if [[ ! -d "$WATCH_DIR" ]]; then
    echo "$(ts) WATCH_DIR specified in $CONFIG_FILE must be a directory."
    exit 1
  fi

  if [[ ! "$SETTLE_DURATION" =~ ^([0-9]{1,2}:){0,2}[0-9]{1,2}$ ]]; then
    echo "$(ts) SETTLE_DURATION must be defined in $CONFIG_FILE as HH:MM:SS or MM:SS or SS."
    exit 1
  fi

  if [[ ! "$MAX_WAIT_TIME" =~ ^([0-9]{1,2}:){0,2}[0-9]{1,2}$ ]]; then
    echo "$(ts) MAX_WAIT_TIME must be defined in $CONFIG_FILE as HH:MM:SS or MM:SS or SS."
    exit 1
  fi

  if [[ ! "$MIN_PERIOD" =~ ^([0-9]{1,2}:){0,2}[0-9]{1,2}$ ]]; then
    echo "$(ts) MIN_PERIOD must be defined in $CONFIG_FILE as HH:MM:SS or MM:SS or SS."
    exit 1
  fi

  if [[ ! "$USER_ID" =~ ^[0-9]{1,}$ ]]; then
    echo "$(ts) USER_ID must be defined in $CONFIG_FILE as a whole number."
    exit 1
  fi

  if [[ ! "$GROUP_ID" =~ ^[0-9]{1,}$ ]]; then
    echo "$(ts) GROUP_ID must be defined in $CONFIG_FILE as a whole number."
    exit 1
  fi
  echo "$(ts) $CONFIG_FILE Config checked"
}
#---------------------------------------------------------------------------------------------------



echo "$(ts) Starting init ..."

echo "$(ts)    Create user ${USER_NAME} and affect it to group ${GROUP_ID}..."
# Create User and make Premissions on Folders
addgroup --gid ${GROUP_ID} ${USER_NAME}
adduser --system --uid ${USER_ID} --ingroup ${USER_NAME} --home /home/${USER_NAME} --shell /bin/bash ${USER_NAME}

echo "$(ts) Check user write access on folders (user: ${USER_NAME} id ${USER_ID})"
for dir in $WATCH_DIR $OUTPUT_DIR $CONFIG_DIR; do
  echo "$(ts)    Check '$dir'..."
  [ ! -d "$dir" ] && echo "$(ts)      Folder doesn't exists, creating it..." && mkdir -p "${dir}"
  if sudo su - $USER_NAME -c "[ -w $dir ]" ; then
    echo "$(ts)    Write access -> OK"
  else
    echo "$(ts)    /!\ Write access -> KO /!\ "
    echo "$(ts)    Exiting script..."
    exit
  fi
done


echo "$(ts)    Create '${WATCH_DIR}' subtree and '${CONFIG_DIR}/logs' folders..."
mkdir -p ${WATCH_DIR}/Animes "${WATCH_DIR}/TV Shows" ${WATCH_DIR}/Movies ${WATCH_DIR}/Musics ${CONFIG_DIR}/logs

echo "$(ts) Give ownership for previously create user to $CONFIG_DIR folder (Recursively)..."
chown -R ${USER_NAME}:${USER_NAME} $CONFIG_DIR

echo "$(ts) Scanning '$CONFIG_DIR' folder for missing scripts..."
for file in filebot.sh filebot.conf monitor.sh; do
  echo "$(ts)    Check '$file'..."
  [ ! -f "$CONFIG_DIR/$file" ] && echo "$(ts)      File doesn't exists, copy it..." && cp "/files/$file" $CONFIG_DIR
done

#echo "$(ts)    Give ownership for previously create user to $WATCH_DIR, $OUTPUT_DIR /files folder (Recursively)..."
#chown -R ${USER_NAME}:${USER_NAME} $WATCH_DIR $OUTPUT_DIR /files
#echo "$(ts)    Set permission to u+rwx to ${WATCH_DIR} and /files folders (Recursively)..."
#chmod -R ug+rwx $WATCH_DIR /files
#echo "$(ts)    Set permission to u+rwx to ${OUTPUT_DIR} folders..."
#chmod ug+rwx $OUTPUT_DIR

. $CONFIG_DIR/filebot.conf
check_config

#SETTLE_DURATION=$(to_seconds $SETTLE_DURATION)
#MAX_WAIT_TIME=$(to_seconds $MAX_WAIT_TIME)
#MIN_PERIOD=$(to_seconds $MIN_PERIOD)

echo "$(ts) CONFIGURATION Variables:"
echo "$(ts)   WATCH_DIR=$WATCH_DIR"
echo "$(ts)   SETTLE_DURATION=$SETTLE_DURATION"
echo "$(ts)   MAX_WAIT_TIME=$MAX_WAIT_TIME"
echo "$(ts)   MIN_PERIOD=$MIN_PERIOD"
echo "$(ts)   USER_ID=$USER_ID"
echo "$(ts)   GROUP_ID=$GROUP_ID"
echo "$(ts)   QUOTE_FIXER=$QUOTE_FIXER"
echo "$(ts)   MUSIC_FORMAT=$MUSIC_FORMAT"
echo "$(ts)   MOVIE_FORMAT=$MOVIE_FORMAT"
echo "$(ts)   SERIES_FORMAT=$SERIES_FORMAT"
echo "$(ts)   ANIME_FORMAT=$ANIME_FORMAT"
echo "$(ts)   MEDIACENTER_NOTIF_INSTRUCTION=$MEDIACENTER_NOTIF_INSTRUCTION"
echo "$(ts) End of script"
echo ""



# echo "$(ts) Initializing configuration"
# initialize_configuration
# echo "$(ts) Checking filebot script version"
# check_filebot_sh_version
#. /files/pre-run.sh  # Download scripts and such.
# /files/checkconfig.sh
#setup_opensubtitles_account


# echo "$(ts) Running FileBot on startup"
# umask $UMASK

# $CONFIG_DIR/filebot.sh
# exec su -pc "$CONFIG_DIR/filebot.sh" $USER_NAME

echo "$(ts) Starting Monitoring"
exec su -pc "${CONFIG_DIR}/monitor.sh" $USER_NAME
echo "$(ts) End of script"
echo ""
