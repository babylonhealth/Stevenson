# iOS Build Distribution System

This is the repository containing the code for the `Stevenson` bot 🤖

## 🚀 Usage

🚧 WIP 🚧

## 💻 Development

To develop locally on this repo:

* [Install Vapor locally](http://docs.vapor.codes/3.0/install/macos/)
* [Run `vapor xcode`] to create the Xcode project
* Open the Xcode project and work in it
* You'll need to define some environment variables in your scheme if you want to try to run the app locally (those variables are defined in the Heroku instance as well).
  * `SLACK_TOKEN`, and optionally `SLACK_CHANNEL`
  * `GITHUB_REPO` (in the form of `OrgName/RepoName`, repo used by CIService)
  * `GITHUB_USERNAME` and `GITHUB_TOKEN`
  * `CIRCLECI_TOKEN`
  * `JIRA_BASEURL`, `JIRA_USERNAME` and `JIRA_TOKEN`
* Hit Cmd-R to run the Vapor server locally. It will listen at `http://localhost:8080`
* To try out by sending fake slack payloads mimicking a Slack slash command

For example to simiulate `/fastlane somelane someargs`, use this (adapt the `&command=` and `&text=` values and the `/fastlane` endpoint to your needs)

```bash
curl -v -d "token=__SLACK_TOKEN_FASTLANE__&team_id=T0001&team_domain=example&enterprise_id=E0001&enterprise_name=Globular%20Construct%20Inc&channel_id=C2147483705&channel_name=test&user_id=U2147483697&user_name=Olivier&command=/fastlane&text=somelane%20someargs&response_url=https://hooks.slack.com/commands/1234/5678&trigger_id=13345224609.738474920.8088930838d88f008e0" http://localhost:8080/fastlane
```

## ⚙️ Environment Variables

 To set the aforementioned environment variables with the real values on Heroku:

 * Go to your Heroku dashboard
 * Navigate to Settings
 * set the environment variables like `SLACK_TOKEN` etc

## 🕹 Create a new Slack command

If you need to create a new Slack command:

 1. Go to the Slack Commands config page for your team's Slack app: `https://api.slack.com/apps/<YourSlackAppID>/slash-commands`
 2. Click on "Create New Command"
   * Fill in the slash command (e.g. `/foo`)
   * Enter `https://<appname>.herokuapp.com/<command>` as the request URL, replacing `<appname>` with the name of your Heroku app instance (e.g. `stevenson-bot`) and `<command>` by the command name
   * Fill in the short description and the hint for the command
   * Hit "Save"
 3. Open the project in Xcode and add a new the handler for the slack command:
   * Open `commands.swift`
   * Add a new `static let <commandName> = SlackCommand(...)` for your new command, using `<command>` as it's name and the `SLACK_TOKEN` environment variable
   * Open `configure.swift` and add that newly-created command to the list of handled commands

   ```swift
   routes(router: router, slack: slack, commands: [
       .fastlane(ci), 
       ..., 
       <your command here>
   ])
   ```

## 🚢 Deployment

You can skip step 1 and 2 if you have already set it up locally.

1. Install the Heroku CLI.
   ```
   brew install heroku/brew/heroku
   heroku login
   ```
   
2. Navigate to the local repo, and configure the Heroku remote using the CLI.
   ```
   heroku git:remote -a <heroku-app-name>
   ```
   
3. Push the `master` branch to deploy.
   ```
   git checkout master
   git push heroku master
   ```

Alternatively, you can deploy a specific branch manually by going to the deploy page on Heroku dashboard and using the "Manual Deploy" section at the very bottom.

Once the app is deployed, if you need to debug things, you can see the logs using `heroku logs -a <heroku-app-name>`.

## 🌏 Hosting

The app is hosted on [Heroku](https://dashboard.heroku.com/apps).

## 📖 Documentation

Visit the Vapor web framework's [documentation](http://docs.vapor.codes) for instructions on how to use Vapor.

## 💧 Community

Join the welcoming community of fellow Vapor developers in [Slack](http://vapor.team) or [Discord](https://discord.gg/vapor).
