[![wercker status](https://app.wercker.com/status/446df94fe0566fad505da38719e7cce6/s/master "wercker status")](https://app.wercker.com/project/byKey/446df94fe0566fad505da38719e7cce6)

# wercker-kelevra-slack-notifier

A wercker after-step slack notifier written in bash and curl. Make sure you create a Slack webhook first (see the Slack integrations page to set one up).

This is based on the [official build step](https://github.com/wercker/step-slack). Why? as we have added the `notify_on` option `failed_or_passed_after_failed`.

# Options

Options are applied via organisation environment, pipeline environment or the `wercker.yml`.

|Option|Description|Environment|
|---|---|---|
|`url`|The Slack webhook URL (REQUIRED)<br/>The `url` parameter is the [slack webhook](https://api.slack.com/incoming-webhooks) that wercker should post to. You can create an _incoming webhook_ on your slack integration page.|`SLACK_NOTIFIER_URL`|
|`channel`|The Slack channel (excluding `#`)|`SLACK_NOTIFIER_CHANNEL`|
|`username`|Username of the notification message. i.e. who it is sent by.|`SLACK_NOTIFIER_USERNAME`|
|`icon_url`|A url that specifies an image to use as the user avatar icon in Slack|`SLACK_NOTIFIER_ICON_URL`|
|`notify_on`|If set. Possible values `failed`, `passed` or `failed_or_passed_after_failed`. <br />Default is `all`.<br /><ul><li>If set to `failed`, it will only notify on failed builds or deploys.</li><li>If set to `passed`, it will only notify on passed builds or deploys.</li><li>If set to `failed_and_passed_after_failed`, it will only notify on failed builds/deploys or passed after a failed. This requires the `wercker_token` option.</li></ul>|`SLACK_NOTIFIER_NOTIFY_ON`|
|`branch`|If set, it will only notify on the given branch|`SLACK_NOTIFIER_BRANCH`|
|`wercker_token`|This is a wercker API token that can access the application.<br/>Required for the`notify_on` value `failed_or_passed_after_failed`.|`SLACK_NOTIFIER_WERCKER_TOKEN`|

## Examples

Some examples

### Simple

```yaml
build:
  after-steps:
    - kingsquare/kelevra-slack-notifier:
        url: $SLACK_URL
        channel: notifications
        username: myamazingbotname
        branch: master
```

`SLACK_URL` is set in the pipeline or organisation environment.

### Use organisation defaults for easiest project integration

For easiest integration in to your application's `wercker.yml` add options as environment variables to your organisation. Then you can just:

```yaml
build:
  after-steps:
    - kingsquare/kelevra-slack-notifier
```

### notify on failed or passed when previous failed

```yaml
build:
  after-steps:
    - kingsquare/kelevra-slack-notifier
      notify_on: failed_or_passed_after_failed
```

# Testing

Using the wercker-cli

# License

The MIT License (MIT)

# Changelog

## 0.0.1

- Initial release based on the [official build step](https://github.com/wercker/step-slack)
