#!/bin/bash

CONFIG_FILE=$CONFIG_FILE
NAME=$(basename $CONFIG_FILE .conf)

#-----------------------------------------------------------------------------------------------------------------------

function ts {
  echo "[`date '+%Y-%m-%d %T'`] monitor.sh:"
}

#-----------------------------------------------------------------------------------------------------------------------

function is_change_event {
  EVENT="$1"
  FILE="$2"
  WATCHED="$3"

  # File events
  if [ "$EVENT" == "MODIFY" ]
  then
    echo "$(ts) '$WATCHED' --> Detected '$FILE' file modifying"
  elif [ "$EVENT" == "CLOSE_WRITE,CLOSE" ]
  then
    EVENT=CLOSE_WRITE
    echo "$(ts) '$WATCHED' --> Detected new file '$FILE'"
  elif [ "$EVENT" == "MOVED_TO" ]
  then
     echo "$(ts) '$WATCHED' --> Detected moved to file '$FILE'"
  else
    return 1
  fi

  return 0
}

#-----------------------------------------------------------------------------------------------------------------------

function to_seconds {
  readarray elements < <(echo $1 | tr ':' '\n' | tac)

  SECONDS=0
  POWER=1

  for (( i=0 ; i<${#elements[@]}; i++ )) ; do
    SECONDS=$(( 10#$SECONDS + 10#${elements[i]} * 10#$POWER ))
    POWER=$(( 10#$POWER * 60 ))
  done

  echo "$SECONDS"
}

#-----------------------------------------------------------------------------------------------------------------------

function wait_for_events_to_stabilize {
  start_time=$(date +"%s")
  echo "$(ts) Waiting $(show_time $SETTLE_DURATION) for input directory to stabilize..."
  while true
  do
    if read -t $SETTLE_DURATION RECORD
    then
      end_time=$(date +"%s")

      if [ $(($end_time-$start_time)) -gt $MAX_WAIT_TIME ]
      then
        echo "$(ts) Input directory didn't stabilize after $(show_time $MAX_WAIT_TIME). Triggering command anyway."
        break
      fi
    else
      echo "$(ts) Input directory stabilized! Triggering command..."
      break
    fi
  done
}

#-----------------------------------------------------------------------------------------------------------------------

function wait_for_minimum_period {
  last_run_time=$1
  time_since_last_run=$(($(date +"%s")-$last_run_time))
  if [ $time_since_last_run -lt $MIN_PERIOD ]
  then
    remaining_time=$(($MIN_PERIOD-$time_since_last_run))
    show_remaining_time=$(show_time $remaining_time)
    echo "$(ts) Minimum period ($(show_time $MIN_PERIOD)) between runs not reached, waiting an additional $show_remaining_time before running command."
    # echo "$(ts) Waiting an additional $remaining_time seconds before running command"
    return 1
  fi
    return 0
  # Process events while we wait for $MIN_PERIOD to expire
  # while [ $time_since_last_run -lt $MIN_PERIOD ]
  # do
    # remaining_time=$(($MIN_PERIOD-$time_since_last_run))

    # read -t $remaining_time RECORD

    # time_since_last_run=$(($(date +"%s")-$last_run_time))
  # done
}

#-----------------------------------------------------------------------------------------------------------------------

function show_time () {
    num=$1
    min=0
    hour=0
    day=0
    if((num>59));then
        ((sec=num%60))
        ((num=num/60))
        if((num>59));then
            ((min=num%60))
            ((num=num/60))
            if((num>23));then
                ((hour=num%24))
                ((day=num/24))
            else
                ((hour=num))
            fi
        else
            ((min=num))
        fi
    else
        ((sec=num))
    fi
    echo "$day"d "$hour"h "$min"m "$sec"s
}

#-----------------------------------------------------------------------------------------------------------------------

function wait_for_command_to_complete {
  PID=$1

  while ps -p $PID > /dev/null
  do
    sleep .1

    if [[ "$IGNORE_EVENTS" == "1" ]]
    then
      # -t 0 didn't work for me. Seemed to return success with no RECORD
      while read -t 0.001 RECORD; do :; done
    fi
  done
}

#-----------------------------------------------------------------------------------------------------------------------

echo "$(ts) Starting inotifywait monitor $CONFIG_FILE at ${WATCH_DIR}"

COMMAND="bash $CONFIG_DIR/filebot.sh" ###change to Monitor Config

pipe=$(mktemp -u)
mkfifo $pipe

# inotifywait -r -m -q --format 'EVENT=%e WATCHED=%w FILE=%f' /input/Animes /input/TVShows /input/Movies >$pipe &
inotifywait -r -m -q -e MODIFY,MOVED_TO,CLOSE_WRITE --format 'EVENT=%e WATCHED=%w/%f' ${WATCH_DIR}/Animes "${WATCH_DIR}/TV Shows" ${WATCH_DIR}/Movies ${WATCH_DIR}/Musics >$pipe &
# inotifywait -r -m -q -e MODIFY,MOVED_TO,CLOSE_WRITE --format 'EVENT=%e WATCHED=%w/%f' /input >$pipe &
last_run_time=0

while true
do
  if read RECORD
  then
    #echo "$(ts) [DEBUG] $RECORD"

    EVENT=$(echo "$RECORD" | sed 's/EVENT=\([^ ]*\).*/\1/')
    FILE=$(echo "$RECORD" | sed 's/.*\/\///')
    WATCHED=$(echo "$RECORD" | sed 's/.*WATCHED=\([^ ]*\)/\1/' | sed 's/\/\/.*/\//')
	FLAG=${WATCHED/${WATCH_DIR}\//}
	FLAG=${FLAG::-1}


    if ! is_change_event "$EVENT" "$FILE" "$WATCHED"
    then
      continue
    fi
	
	tr -d '\r' < $CONFIG_FILE > /tmp/$NAME.conf
	. /tmp/$NAME.conf

	SETTLE_DURATION=$(to_seconds $SETTLE_DURATION)
	MAX_WAIT_TIME=$(to_seconds $MAX_WAIT_TIME)
	MIN_PERIOD=$(to_seconds $MIN_PERIOD)
	
     # Monster up as many events as possible, until we hit the either the settle duration, or the max wait threshold.
    # will be removed
    wait_for_events_to_stabilize

    # Wait until it's okay to run the command again, monstering up events as we do so
    if ! wait_for_minimum_period $last_run_time
    then
      echo "$(ts) Waiting for another event"
      continue
    fi
    
    echo "$(ts) Running command with user ID $USER_ID and group ID $GROUP_ID"
    #/sbin/setuser $USER_NAME $COMMAND &
    $COMMAND "$WATCHED" "$FLAG" &
    PID=$!
    last_run_time=$(date +"%s")

    wait_for_command_to_complete $PID
    echo "$(ts) Waiting for another event"
  fi
done <$pipe