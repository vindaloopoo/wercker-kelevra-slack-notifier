#!/bin/bash
# ----------------------------------------------------------------------------------------------------------------------
#
# Wercker build step slack notifier
#
# ----------------------------------------------------------------------------------------------------------------------

#
# Fix env expectations
# This supports setting values through wercker environment and also overriding (or setting) them via the wercker.yml
#
# this is also for interchangeability of slack notifiers. i.e. can switch to this one from another based on the
# official notifier.
#
# e.g. Wanting the slack notifier url:
# 1. WERCKER_KELEVRA_SLACK_NOTIFIER_URL is set via option in wercker.yml as `kelevra-slack-notifier` is the step.
# 2. if WERCKER_KELEVRA_SLACK_NOTIFIER_URL is not set then SLACK_NOTIFIER_URL is used from ENV (pipeline else organisation)
# 3. else WERCKER_SLACK_NOTIFIER_URL is empty
#

WERCKER_SLACK_NOTIFIER_URL=${WERCKER_KELEVRA_SLACK_NOTIFIER_URL:-${SLACK_NOTIFIER_URL}}
WERCKER_SLACK_NOTIFIER_NOTIFY_ON=${WERCKER_KELEVRA_SLACK_NOTIFIER_NOTIFY_ON:-${SLACK_NOTIFIER_NOTIFY_ON}}
WERCKER_SLACK_NOTIFIER_CHANNEL=${WERCKER_KELEVRA_SLACK_NOTIFIER_CHANNEL:-${SLACK_NOTIFIER_CHANNEL}}
WERCKER_SLACK_NOTIFIER_USERNAME=${WERCKER_KELEVRA_SLACK_NOTIFIER_USERNAME:-${SLACK_NOTIFIER_USERNAME}}
WERCKER_SLACK_NOTIFIER_BRANCH=${WERCKER_KELEVRA_SLACK_NOTIFIER_BRANCH:-${SLACK_NOTIFIER_BRANCH}}
WERCKER_SLACK_NOTIFIER_WERCKER_TOKEN=${WERCKER_KELEVRA_SLACK_NOTIFIER_WERCKER_TOKEN:-${SLACK_NOTIFIER_WERCKER_TOKEN}}

# check if slack webhook url is present
if [ -z "$WERCKER_SLACK_NOTIFIER_URL" ]; then
  fail "Please provide a Slack webhook URL"
fi

# skip notifications if not interested in passed builds or deploys
if [ "$WERCKER_SLACK_NOTIFIER_NOTIFY_ON" = "failed" ]; then
	if [ "$WERCKER_RESULT" = "passed" ]; then
		return 0
	fi
fi

# skip notifications if not on the right branch
if [ -n "$WERCKER_SLACK_NOTIFIER_BRANCH" ]; then
    if [ "$WERCKER_SLACK_NOTIFIER_BRANCH" != "$WERCKER_GIT_BRANCH" ]; then
        return 0
    fi
fi

# skip notifications if not interested in passed builds or deploys
if [[ "$WERCKER_RESULT" = "passed" ] && [ ${WERCKER_SLACK_NOTIFIER_NOTIFY_ON} = "failed_or_passed_after_failed" ]]; then
    if [ -z ${WERCKER_SLACK_NOTIFIER_WERCKER_TOKEN} ]; then
        fail "No Wercker API token is specified."
    fi

    CURL="curl -H "Authorization: Bearer: ${WERCKER_SLACK_NOTIFIER_WERCKER_TOKEN}" https://app.wercker.com/api/v3"

    # get the current pipeline-id (as is not available in the wercker env)
    WERCKER_PIPELINE_ID=$(${CURL}/runs/${WERCKER_RUN_ID} | ./jq .pipeline.id )

    # get previous run result for the current pipeline & branch
    WERCKER_PREVIOUS_RESULT=$(${CURL}/runs/?&limit=1&status=finished&branch=${WERCKER_GIT_BRANCH}&pipelineId=${WERCKER_PIPELINE_ID} | ./jq .result)

    if [ ${WERCKER_PREVIOUS_RESULT} != 'failed']; then
        return 0;
    fi
fi

# check if a '#' was supplied in the channel name
if [ "${WERCKER_SLACK_NOTIFIER_CHANNEL:0:1}" = '#' ]; then
  export WERCKER_SLACK_NOTIFIER_CHANNEL=${WERCKER_SLACK_NOTIFIER_CHANNEL:1}
fi

# if no username is provided use the default - werckerbot
if [ -z "$WERCKER_SLACK_NOTIFIER_USERNAME" ]; then
  export WERCKER_SLACK_NOTIFIER_USERNAME=werckerbot
fi

# if no icon-url is provided for the bot use the default wercker icon
if [ -z "$WERCKER_SLACK_NOTIFIER_ICON_URL" ]; then
  export WERCKER_SLACK_NOTIFIER_ICON_URL="https://secure.gravatar.com/avatar/a08fc43441db4c2df2cef96e0cc8c045?s=140"
fi

# check if this event is a build or deploy
if [ -n "$DEPLOY" ]; then
  # its a deploy!
  export ACTION="deploy ($WERCKER_DEPLOYTARGET_NAME)"
  export ACTION_URL=$WERCKER_DEPLOY_URL
else
  # its a build!
  export ACTION="build"
  export ACTION_URL=$WERCKER_BUILD_URL
fi

export MESSAGE="<$ACTION_URL|$ACTION> for $WERCKER_APPLICATION_NAME by $WERCKER_STARTED_BY has $WERCKER_RESULT on branch $WERCKER_GIT_BRANCH"
export FALLBACK="$ACTION for $WERCKER_APPLICATION_NAME by $WERCKER_STARTED_BY has $WERCKER_RESULT on branch $WERCKER_GIT_BRANCH"
export COLOR="good"

if [ "$WERCKER_RESULT" = "failed" ]; then
  export MESSAGE="$MESSAGE at step: $WERCKER_FAILED_STEP_DISPLAY_NAME"
  export FALLBACK="$FALLBACK at step: $WERCKER_FAILED_STEP_DISPLAY_NAME"
  export COLOR="danger"
fi

# construct the json
json="{"

# channels are optional, dont send one if it wasnt specified
if [ -n "$WERCKER_SLACK_NOTIFIER_CHANNEL" ]; then
    json=$json"\"channel\": \"#$WERCKER_SLACK_NOTIFIER_CHANNEL\","
fi

json=$json"
    \"username\": \"$WERCKER_SLACK_NOTIFIER_USERNAME\",
    \"icon_url\":\"$WERCKER_SLACK_NOTIFIER_ICON_URL\",
    \"attachments\":[
      {
        \"fallback\": \"$FALLBACK\",
        \"text\": \"$MESSAGE\",
        \"color\": \"$COLOR\"
      }
    ]
}"

# post the result to the slack webhook
RESULT=$(curl -d "payload=$json" -s "$WERCKER_SLACK_NOTIFIER_URL" --output "$WERCKER_STEP_TEMP"/result.txt -w "%{http_code}")
cat "$WERCKER_STEP_TEMP/result.txt"

if [ "$RESULT" = "500" ]; then
  if grep -Fqx "No token" "$WERCKER_STEP_TEMP/result.txt"; then
    fail "No token is specified."
  fi

  if grep -Fqx "No hooks" "$WERCKER_STEP_TEMP/result.txt"; then
    fail "No hook can be found for specified subdomain/token"
  fi

  if grep -Fqx "Invalid channel specified" "$WERCKER_STEP_TEMP/result.txt"; then
    fail "Could not find specified channel for subdomain/token."
  fi

  if grep -Fqx "No text specified" "$WERCKER_STEP_TEMP/result.txt"; then
    fail "No text specified."
  fi
fi

if [ "$RESULT" = "404" ]; then
  fail "Subdomain or token not found."
fi