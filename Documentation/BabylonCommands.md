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

The Stevenson instance used at Babylon, whose code can be found in the `App/` directory, declares the features described below, which mainly consist of 3 main core features:

* Invoking a `fastlane` command on CI
* Responding to a GitHub comment to trigger a CI pipeline
* [Generating the CRP ticket](CRP.md)

## `/stevenson`

This is the main Slack command, used to namespace other commands. It's implemented in `MainCommand.swift`

This command expects one of the following sub-commands, which are described in more details below:

* `/stevenson fastlane …`
* `/stevenson appcenter …`
* `/stevenson testflight …`
* `/stevenson crp …`

## `/stevenson fastlane`

This and the 2 following commands are implemented in `SlackCommand+Fastlane.swift`
> Also still accessible via `/fastlane` directly, though deprecated in favor of being invoked as a `/stevenson` subcommand instead.

This command allows you to trigger a CircleCI job which will run the provided lane.

```
/stevenson fastlane <lane> [branch:<branch>] [target:<target>] [<other_options>]
```

* If `branch:` is not provided, defaults to running the lane on `develop`
* `target:` is only used by some lanes in Fastlane, like `appcenter` or `testflight`. In most cases it's not needed
* Any potential `<other_options>` depend on each lane. Check our Fastlane to see which are available for each. Examples include `version:` for `appcenter` and `testflight` lanes


## `/stevenson appcenter`

> Also still accessible via `/appcenter` directly, though deprecated in favor of being invoked as a `/stevenson` subcommand instead.


```
/stevenson appcenter <target> [version:<version>] [branch:<branch>]
```

* This command is just a convenience doing the same as `/stevenson fastlane appcenter target:<target> version:<version> branch:<branch>`
* If `branch:` is not provided, defaults to `release/<target>/<version>`

## `/stevenson testflight`

> Also still accessible via `/testflight` directly, though deprecated in favor of being invoked as a `/stevenson` subcommand instead.

```
/stevenson testflight <target> [version:<version>] [branch:<branch>]
```

* This command is just a convenience doing the same as `/stevenson fastlane testflight target:<target> version:<version> branch:<branch>`
* If `branch:` is not provided, defaults to `release/<target>/<version>`


## `/stevenson crp`

> Still accessible via `/crp` directly, though deprecated in favor of new name.

This command creates a "CRP Ticket" in our JIRA, which is a JIRA ticket gathering all the tickets that will be part of a release to the Stores in order to validate approval for that release. The creation and approval of this ticket to make a new release is part of our SSDLC. 

For more information about the CRP, visit [the dedicated page in your Playbook](https://github.com/babylonhealth/ios-playbook/blob/master/Cookbook/Technical-Documents/CRP-Bot.md).

```
/crp <repo> branch:<branch>
```

* `<repo>` should be one of the repositories declared in `RepoMapping.swift` – namely either `ios` or `android`.
* `<branch>` will typically be the name of a release branch, e.g. `release/babylon/<version>`

Execution of CRP process is composed of multiple subtasks (auto-gathering the list of tickets from the commits, creating the CRP ticket, creating JIRA versions on each relevant boards, setting the "Fix Version" field of all relevant tickets to the appropriate JIRA version…) and involves a good chunk of code. For implementation details of this part of the code, see [CRP implementation details](CRP.md)

## Responding to a GitHub comment `"@ios-bot-babylon …"`

Our bot also responds to a route to the `/github/comment` URL, which is sent by GitHub webhooks when a new comment is made on a GitHub issue or Pull Request.

We have configured our GitHub repo to send the webhook to the URL of our bot, which means our bot will handle every new comment made to any issue or PR and be able to act on it.

This route processes comments starting with `@ios-babylon-bot` (discarding any other kind of comments); it then invokes the workflow (whose name is provided in the comment) on the PR's branch in CircleCI.

```
@ios-bot-babylon <workflow_name>
```

This will simply run the workflow `<workflow_name>` on CircleCI, on the head branch of the PR this comment was made on.
