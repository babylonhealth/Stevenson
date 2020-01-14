# Babylon's Stevenson Commands

This Vapor project actually consists of two projects:

 * The Stevenson framework, aimed to be reused so you can create your own bots interacting with Slack, GitHub, CircleCI and JIRA yourselves
 * The Stevenson Babylon app, which is the instance of the Bot we use at Babylon, based on the Stevenson framework, and which provides us with commands we need

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

The Stevenson instance used at Babylon, whose code can be found in the `App/` directory, consist of 3 main core features

## Invoking a `fastlane` command on CI via Slack

Allows us to use a slash command in our Slack to trigger CI workflows.

* Usage and supported commands are documented [in our playbook here](https://github.com/babylonhealth/ios-playbook/blob/master/Cookbook/Technical-Documents/SlackCIIntegration.md).
* The commands are implemented/defined in `SlackCommand+Fastlane.swift` and then handled in `SlackService.swift` by `func handle(command:on:)`.

Implementation consists of parsing the slack command parameters, then invoking `CircleCIService.runlane` with the right arguments.

Our Slack is configured to send webhooks for those slash commands to the URL of our bot for it to process those requests – See [main README.md](../README.md) for details.

## Responding to a GitHub comment to trigger a CI pipeline

* Usage documentation can be found [here](https://github.com/babylonhealth/ios-playbook/blob/master/Cookbook/Technical-Documents/SlackCIIntegration.md)
* Implementation consists of a _route_ implemented in `routes.swift` and invoking `GitHubService.issueComment(on:ci:)` (in `GitHubService+IssueComment.swift`).  
  The method parses the webhook request headers and the comment body, then calls `CircleCIService.runLane` or `CircleCIService.runPipeline` appropriately to trigger the right CI workflow.

Our GitHub repository is then configured with a webhook on comments, which sends the request to the URL of our bot so it can process it.

## Generating the CRP ticket

The CRP process is a process specific to our company's SSDLC and documented in our Playbook repository:

* [Usage documentation is here](https://github.com/babylonhealth/ios-playbook/blob/master/Cookbook/Technical-Documents/CRP-Bot.md)
* [Implementation details for the CRP code has its own dedicated documentation here](https://github.com/babylonhealth/ios-playbook/blob/master/Cookbook/Technical-Documents/CRP-Bot-ImplementationDetails.md).
