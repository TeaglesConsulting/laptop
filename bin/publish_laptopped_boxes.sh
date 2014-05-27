#!/usr/bin/env sh
check_for_aws() {
  if ! command -v aws &>/dev/null; then
    failure_message 'You must install aws-cli to publish boxes'
    exit 1
  fi
}

message() {
  printf "\e[1;34m:: \e[1;37m%s\e[0m\n" "$*"
}

failure_message() {
  printf "\n\e[1;31mFAILURE\e[0m: \e[1;37m%s\e[0m\n\n" "$*" >&2;
}

upload_box_to_temp_location(){
  message "Uploading box to s3: $BOX"
  aws s3 cp "$BOX" "s3://laptop-boxes/$BOX.tmp" --acl public-read
}

move_box_into_place(){
  message "Removing existing box: $BOX"
  aws s3 rm "s3://laptop-boxes/$BOX" \
    || failure_message "Could not remove $BOX"

  message "Moving new box to correct location: $BOX"
  aws s3 mv "s3://laptop-boxes/$BOX.tmp" "s3://laptop-boxes/$BOX" \
    --acl public-read || failure_message 'Could not move new box into place on s3'
}

publish_box(){
  upload_box_to_temp_location && move_box_into_place
}

box_has_changed() {
  REMOTE_SIZE=`aws s3 ls "laptop-boxes/$BOX" | cut -f 3 -d ' '`
  LOCAL_SIZE=`stat -c %s "$BOX"`

  [ "$LOCAL_SIZE" -ne "$REMOTE_SIZE" ]
}

###################################

check_for_aws

for BOX in *.box; do
  if [ -e "$BOX" ]; then
    if box_has_changed; then
      echo "local copy of $BOX has a different size than the s3 remote copy, publishing"
      publish_box
    else
      echo "local copy of $BOX has the same size as the s3 remote copy, not publishing"
    fi
  fi
done
