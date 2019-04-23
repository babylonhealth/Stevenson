# iOS Build Distribution System

This is the repository containing the code for the `Stevenson` bot 🤖

## 🚀 Usage

🚧 WIP 🚧

## 💻 Development

To develop locally on this repo:

* [Install Vapor locally](http://docs.vapor.codes/3.0/install/macos/)
* Run `vapor xcode` to create the Xcode project
* Open the Xcode project and work in it
* You'll need to define some environment variables in your scheme if you want to try to run the app locally (those variables are defined in the Heroku instance as well).
  * `SLACK_TOKEN`: your access token for the Slack API of your team's Slack
  * `SLACK_CHANNEL` (optional): the name of the Slack channel to restrict the commands to be 
  * `GITHUB_USERNAME` and `GITHUB_TOKEN`: login and access token of a user having read access to those repositories
  * `CIRCLECI_TOKEN`: your access token for the CircleCI API
  * `JIRA_BASEURL`: host name of your Jira instance (e.g. `https://myorg.atlassian.net:443`)
  * `JIRA_USERNAME` and `JIRA_TOKEN`: login and access token for the API of your Jira instance
* Hit Cmd-R to run the Vapor server locally. It will listen at `http://localhost:8080`
* Try it out by sending fake Slack payloads mimicking a Slack slash command

For example to simulate `/fastlane somelane someargs`, use this (adapt the `&text=` value and the `/fastlane` endpoint to your needs)

```bash
curl --request POST \
  --url http://localhost:8080/fastlane \
  --header 'content-type: application/x-www-form-urlencoded' \
  --data 'token=__SLACK_TOKEN__&channel_name= __SLACK_CHANNEL__&text=somelane%20someargs'
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
 3. Open the project in Xcode and add a new the handler for the Slack command:
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

## ✨ Take a look at our other OSS projects!

* [Bento](https://github.com/Babylonpartners/Bento): Swift library for building component-based interfaces on top of UITableView and UICollectionView 🍱
* [DrawerKit](https://github.com/Babylonpartners/DrawerKit): DrawerKit lets an UIViewController modally present another UIViewController in a manner similar to the way Apple's Maps app works.
* [ReactiveFeedback](https://github.com/Babylonpartners/ReactiveFeedback): Unidirectional reactive architecture
* 🚧 [Wall-E](https://github.com/Babylonpartners/Wall-E): A bot that monitors and manages your pull requests by ensuring they are merged when they're ready and don't stack up in your repository 🤓
