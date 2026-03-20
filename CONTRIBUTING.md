# Contributing

Every contribution to Drift VPN is welcome, whether it is reporting a bug, submitting a fix, proposing new features, or just asking a question.

- [Feedback, Issues and Questions](#feedback-issues-and-questions)
- [Adding new Features](#adding-new-features)
- [Development](#development)
  - [Working with the Go Code](#working-with-the-go-code)
  - [Working with the Flutter Code](#working-with-the-flutter-code)
    - [Setting up the Environment](#setting-up-the-environment)
    - [Run Release Build on a Device](#run-release-build-on-a-device)
- [Release](#release)
- [Collaboration and Contact Information](#collaboration-and-contact-information)

## Feedback, Issues and Questions

If you encounter any issue, or you have an idea to improve, please:

- Search through [existing open and closed GitHub Issues](https://github.com/Chieff79/Drift/issues) for the answer first. If you find a relevant topic, please comment on the issue.
- If none of the issues are relevant, please add a new [issue](https://github.com/Chieff79/Drift/issues/new/choose) following the templates and provide as much relevant information as possible.

## Adding new Features

When contributing a complex change to the Drift repository, please discuss the change you wish to make within a GitHub issue with the owners of this repository before making the change.


## Development

### Adding Feature / Fix bug in Core:
Please follow our [Go Core Development repository](https://github.com/hiddify/hiddify-next-core/main/CONTRIBUTING.m).

### Working with the Flutter Code
Drift VPN uses [Flutter](https://flutter.dev), make sure that you have the correct version installed before starting development. You can use the following commands to check your installed version:

```shell
$ flutter --version

# example response
Flutter 3.38.5 • channel stable • https://github.com/flutter/flutter.git
```


We recommend using [Visual Studio Code](https://docs.flutter.dev/development/tools/vs-code) extensions for development.

#### Setting up the Environment

We have extensive use of code generation in the form of [freezed](https://github.com/rrousselGit/freezed), [riverpod](https://github.com/rrousselGit/riverpod), etc. So it's generate these before running the code. Execute the following make commands in order:
Assuming you have not built the `hiddify-core` and want to use [existing releases](https://github.com/hiddify/hiddify-next-core/releases), you should run the following command (based on your target platform):


- `make windows-prepare`
- `make linux-prepare`
- `make macos-prepare`
- `make ios-prepare`
- `make android-prepare`


##### build the `hiddify-core` from source (Optional)
If you want to build the `hiddify-core` from source after `make prepare`, use:
- `make build-windows-libs`
- `make build-linux-libs`
- `make build-macos-libs`
- `make build-ios-libs`
- `make build-android-libs`

#### Run Release Build on a Device

To run the release build on a device for testing, we have to get the Device ID first by running the following command:

```shell
$ flutter devices
```

Then we can use one of the listed devices and execute the following command to build and run the app on this device:

```shell
flutter run
# or
flutter run --device-id=<device-id>
```

## Release

We use [fastforge](https://pub.dev/packages/fastforge) for packaging. [GitHub action](https://github.com/Chieff79/Drift/blob/main/.github/workflows/build.yml) is triggered on every release tag and will create a new GitHub release.
After setting up the environment, use the following make commands to build the release version:

- `make windows-release`
- `make linux-release`
- `make macos-release`
- `make android-release`
- `make ios-release`

## Collaboration and Contact Information

We need your collaboration in order to develop this project. If you have experience in these areas, please do not hesitate to contact us.

- Flutter Development
- Swift Development
- Go Development

<div align=center>
</br>

[![Telegram](https://img.shields.io/badge/Telegram-@driftvpn-blue?style=flat-square&logo=telegram)](https://t.me/driftvpn)

</div>
