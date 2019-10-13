#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------

function ts {
  echo "[`date '+%Y-%m-%d %T'`] filebot.sh:"
}

#-----------------------------------------------------------------------------------------------------------------------

if [ "$SUBTITLE_LANG" == "" ];then
  SUBTITLE_OPTION=""
else
  SUBTITLE_OPTION="subtitles=$SUBTITLE_LANG"
fi

echo "$(ts) Import $CONFIG_DIR/filebot.conf variable info..."
. $CONFIG_DIR/filebot.conf

#************************************************************************
LOG_FILE=$CONFIG_DIR/logs/filebot.log
echo "$(ts) FileBot AMC script" | tee -a $LOG_FILE
# start filebot
case $2 in
  "Animes") DEF_UT_LABEL="ut_label=TV";;
  "TV Shows") DEF_UT_LABEL="ut_label=TV";;
  "Movies") DEF_UT_LABEL="ut_label=Movie";;
  "Musics") DEF_UT_LABEL="ut_label=Music music=y"
esac
mkdir -p "$OUTPUT_DIR/$2"
filebot -script fn:amc --output "$OUTPUT_DIR/$2" --log all --log-file $LOG_FILE --action move --lang fr --conflict skip -no-xattr -non-strict \
		--def ut_dir="$1" $DEF_UT_LABEL skipExtract=y unsorted=y artwork=n excludeList=$CONFIG_DIR/excludeList.txt reportError=y $MEDIACENTER_NOTIF_INSTRUCTION $SUBTITLE_OPTION \
		movieFormat="$MOVIE_FORMAT" musicFormat="$MUSIC_FORMAT" seriesFormat="$SERIES_FORMAT" animeFormat="$ANIME_FORMAT"
rc=$?
echo "$(ts) FileBot AMC script done! -> Return Code: $rc" | tee -a $LOG_FILE
#************************************************************************
echo "$(ts) FileBot Cleaner script..." | tee -a $LOG_FILE
filebot -script fn:cleaner "$1" --log all --log-file $LOG_FILE
echo "$(ts) FileBot Cleaner script done!" | tee -a $LOG_FILE
#************************************************************************

# mkdir -p ${WATCH_DIR}/Animes "${WATCH_DIR}/TV Shows" ${WATCH_DIR}/Movies ${WATCH_DIR}/Musics

echo "$(ts) Spliting log to keep usefull informations on '$LOG_FILE'..."
DATESTAMP=$(date '+%Y-%m-%d %T')
grep 'MOVE' $LOG_FILE | ( while read LINE; do echo "$DATESTAMP - $LINE"; done;)>$CONFIG_DIR/logs/Moved_Elements.log
grep 'Skipped\|Skip' $LOG_FILE | ( while read LINE; do echo "$DATESTAMP - $LINE"; done;)>$CONFIG_DIR/logs/Skipped_Elements.log
if [ $rc -ne 0 ]; then
	echo "$(ts) Filebot Error!!" | tee -a $LOG_FILE
	MAIL_SUBJECT='[DockerFilebot] Filebot traitement error'
else
	echo "$(ts) Filebot successfully ended!!" | tee -a $LOG_FILE
	MAIL_SUBJECT='[DockerFilebot] Filebot traitement successfully ended'
fi
if [ -f $CONFIG_DIR/muttrc ]
then
	if ! grep -q "No files selected for processing" $LOG_FILE ; then
		TO=`grep -oP '(?<=to=).*' $CONFIG_DIR/muttrc`
		cat $CONFIG_DIR/muttrc | head -n -1 > $CONFIG_DIR/muttrc1
		cat $LOG_FILE | /usr/bin/mutt -F $CONFIG_DIR/muttrc1 -s "$MAIL_SUBJECT" $TO
		if [ $? -ne 0 ]; then
			echo "$(ts) Error sending mail, Error code -> $RETURN_CODE"
		else
			echo "$(ts) Sending mail succeed!"
		fi
	fi
	echo "$(ts) Removing $LOG_FILE..."
	rm -rf $LOG_FILE
else
	echo "$(ts) Unable to find $CONFIG_DIR/muttrc file. Disable email notification."| tee -a $LOG_FILE
fi
echo "$(ts) Removing $CONFIG_DIR/muttrc1 and $CONFIG_DIR/excludeList.txt..."
rm -rf $CONFIG_DIR/muttrc1 $CONFIG_DIR/excludeList.txt
echo "$(ts) End of script"
echo "" | tee -a $LOG_FILE
echo "*********************************************************************************************************************************************************************************************************************************" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
