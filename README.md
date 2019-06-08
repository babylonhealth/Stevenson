# iOS Build Distribution System

`Stevenson` is a Vapor framework designed to build integrations between Slack apps, Github, JIRA and CI services (CircleCI).
This project also contains implementation of the Slack app used by Babylon iOS team (if you want to know more about how our team works checkout our [playbook](https://github.com/Babylonpartners/ios-playbook))

## 🚀 Usage

To use `Stevenson` in your app add it as a dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Babylonpartners/Stevenson.git", .branch("master")),
]
```

and then import it to your project:

```swift
import Stevenson
```

### Supported services

`Stevenson` comes with implementation of Slack [slash commands](https://api.slack.com/slash-commands), GitHub, JIRA and CircleCI APIs. At the moment it does not implement complete set of these APIs but only provides bare minimum required for the functionality of the app. 
To create these services use corresponding type constructors providing required values. It's advised but not required to store these values in the environment variables:

```swift
let slack = SlackService(
    token: Environment.get("SLACK_TOKEN")
)

let ci = CircleCIService(
    token: Environment.get("CIRCLECI_TOKEN")
)

let jira = JiraService(
    baseURL: Environment.get("JIRA_BASE_URL").flatMap(URL.init(string:)),
    username: Environment.get("JIRA_USERNAME"),
    password: Environment.get("JIRA_TOKEN")
)

let github = GitHubService(
    username: Environment.get("GITHUB_USERNAME"),
    token: Environment.get("GITHUB_TOKEN")
)
```

### Creating a Slack command

To create a Slack [slash command](https://api.slack.com/slash-commands) start with registering it in your Slack app following Slack documentation. 

Note: instead of using your own Slack app you may use Slack Slash Commands app. In this case you will register your slash commands in this app but the process will be pretty much the same.

Then use the `SlackCommand` type to implement it:

```swift
let myAmazingCommand = SlackCommand(
    // This name should be the same name that you used to register a command in your Slack app
    name: "myAmazingCommand",
    // This message will be sent back to Slack when you call your command with `/myAmazingCommand help`
    help: "Some command usage instructions", 
    // This closure is where the command is actually implemented
    run: { metadata, request in
        /**
        Parse `metadata` here, do something useful, 
        i.e. invoke a CI job, and send a response back to Slack
        */
    }
)
```
 
 Then register a route in your app with a path that matches the command name (usually Slack sends commands as `POST` requests):
 
```swift
router.post(myAmazingCommand.name) { request -> Future<Response> in
    try slack.handle(command: myAmazingCommand, on: request)
}
```

For more details check the commands implemented in the app.

## 💻 Development

To develop locally on this repo:

* [Install Vapor locally](http://docs.vapor.codes/3.0/install/macos/)
* Run `vapor xcode` to create the Xcode project
* Open the Xcode project and work in it
* You'll need to define some environment variables in your scheme if you want to try to run the app locally (those variables are defined in the Heroku instance as well).
  * `SLACK_TOKEN`: your access token for the Slack API of your team's Slack
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

## 🕹 Adding a new Slack command to the app

If you need to create a new Slack command:

 1. Go to the Slack Commands config page for your team's Slack app: `https://api.slack.com/apps/<YourSlackAppID>/slash-commands`
 2. Click on "Create New Command"
   * Fill in the slash command (e.g. `/foo`)
   * Enter `https://<appname>.herokuapp.com/<command>` as the request URL, replacing `<appname>` with the name of your Heroku app instance (e.g. `stevenson-bot`) and `<command>` by the command name (e.g. `foo`)
   * Fill in the short description and the hint for the command
   * Hit "Save"
 3. Open the project in Xcode and add a new handler for the Slack command:
   * Open `commands.swift`
   * Implement your command as a static function in the `SlackCommand` namespace:
   
   ```swift
extension SlackCommand {
   static func <command>(/* optional params if needed */) { 
        SlackCommand(
            name: "<command>", 
            help: "...",
            allowedChannels: [...],
            run: { ... }
        ) 
    }
}
   ```
   
   * Open `configure.swift` and add that newly-created command to the list of handled commands

   ```swift
   routes(router: router, slack: slack, commands: [
       .fastlane(ci), 
       ..., 
       .<command>()
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

## ⚙️ Environment Variables

To set the aforementioned environment variables with the real values on Heroku:

* Go to your Heroku dashboard
* Navigate to Settings
* set the environment variables like `SLACK_TOKEN` etc

## 📖 Documentation

Visit the Vapor web framework's [documentation](http://docs.vapor.codes) for instructions on how to use Vapor.

## ✨ Take a look at our other OSS projects!

* [Bento](https://github.com/Babylonpartners/Bento): Swift library for building component-based interfaces on top of UITableView and UICollectionView 🍱
* [DrawerKit](https://github.com/Babylonpartners/DrawerKit): DrawerKit lets an UIViewController modally present another UIViewController in a manner similar to the way Apple's Maps app works.
* [ReactiveFeedback](https://github.com/Babylonpartners/ReactiveFeedback): Unidirectional reactive architecture
* 🚧 [Wall-E](https://github.com/Babylonpartners/Wall-E): A bot that monitors and manages your pull requests by ensuring they are merged when they're ready and don't stack up in your repository 🤓
