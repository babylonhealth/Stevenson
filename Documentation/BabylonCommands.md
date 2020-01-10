# Babylon's Stevenson Commands

This Vapor project consists actually of two projects:

 * The Stevenson framework, aimed to be reused so you can create your own bots interacting with Slack, GitHub, CircleCI and JIRA yourselves
 * The Stevenson Babylon app, which is the instance of the Bot we use at Babylon, based on the Stevenson framework, and which provides us with the Slack commands we need

# ⚙️ Environment Variables used by our app

The bot instance of Stevenson we use at Babylon uses environment variables to instantiate and configure the various services (see [README.md](../README.md#supported-services)).

See `app.swift` for declaration of those environment variables used in the app, and `configure.swift` for where they are used to instantiate the services.

ENV Var | Description
--------|--------------
`SLACK_TOKEN` | Your access token for the Slack API of your team's Slack
`GITHUB_USERNAME`<br/>`GITHUB_TOKEN`| Login and access token of a user having read access to those repositories
`CIRCLECI_TOKEN`| Your access token for the CircleCI API
`JIRA_BASEURL`| Host name of your Jira instance (e.g. `https://myorg.atlassian.net:443`)
`JIRA_USERNAME`<br/>`JIRA_TOKEN`| Login and access token for the API of your Jira instance

# 🕹 Commands implemented in the Babylon Bot

The Stevenson instance used at Babylon, whose code can be found in the `App/` directory, mainly consist of 3 main core features

## Invoking a `fastlane` command on CI via Slack

Allows us to use a slash command in our Slack to trigger CI workflows.

* Usage documentation can be found [here](https://github.com/babylonhealth/ios-playbook/blob/master/Cookbook/Technical-Documents/SlackCIIntegration.md)
* The `SlackCommand` is implemented in `SlackCommand+Fastlane.swift` and then handled in `SlackService.swift` by `func handle(command:on:)`.

Implementation is quite straightforward, parsing the slack command parameters then invoking `CircleCIService.runlane` with them.

Our Slack is configured with a Slack app to send webhooks for those slash commands to the URL of our bot for it to process those requests. See [main README.md](../README.md) for details about configuring your Slack app.

## Responding to a GitHub comment to trigger a CI pipeline

* Usage documentation can be found [here](https://github.com/babylonhealth/ios-playbook/blob/master/Cookbook/Technical-Documents/SlackCIIntegration.md)
* Implementation simply consists of a _route_ implemented in `routes.swift` and invoking `GitHubService.issueComment(on:ci:)` in `GitHubService+IssueComment.swift`.  
  The method parses the request headers and comment body, then calls `CircleCIService.runLane` or `CircleCIService.runPipeline` appropriately to trigger CI.

Our GitHub is then configured with a webhook on comments that sends the request to the URL of our bot so it can process it.

## Generating the CRP ticket

* The CRP process (usage documentation) is described [here in our playbook](https://github.com/babylonhealth/ios-playbook/blob/master/Cookbook/Technical-Documents/CRP-Bot.md)
* The code for this process is a bit more convoluted and spread out; [implementation details for the CRP code can be found here](CRP.md)
