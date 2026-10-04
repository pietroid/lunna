# GitHub Actions Self-Hosted Runner on Raspberry Pi

Status: idea for later. Not implemented yet.

## Goal

Deploy the Flutter web app to the Raspberry Pi automatically from GitHub Actions, without opening SSH to the public internet.

## Why it is interesting

- No inbound ports required on the Pi.
- Native GitHub integration: push to `main` → deploy.
- The Pi connects outbound to GitHub over HTTPS, so the home router/firewall does not need port forwarding.
- Can split the workflow: build the web app on GitHub's runner, deploy on the Pi runner.

## How it works

1. Install the official GitHub Actions runner on the Pi.
2. Register it to the repository with a one-time token from GitHub settings.
3. The runner keeps an outbound HTTPS/WebSocket connection to GitHub.
4. GitHub queues a job with `runs-on: self-hosted`.
5. The Pi runner picks up the job and executes the deploy steps locally.

## Suggested workflow shape

Build on GitHub's runner (fast, no Flutter on Pi needed):

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.1'
      - run: flutter build web --release
      - uses: actions/upload-artifact@v4
        with:
          name: focus-web-build
          path: app/build/web/
```

Deploy on the Pi runner:

```yaml
  deploy:
    needs: build
    runs-on: self-hosted
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: focus-web-build
          path: /tmp/focus-web-build
      - run: sudo rsync -avz --delete /tmp/focus-web-build/ /opt/focus/web/
      - run: docker exec focus-web nginx -s reload
```

## Security notes

- The runner is authenticated with GitHub's runner token.
- No SSH key needs to be stored in GitHub secrets for the Pi connection.
- The Pi runner runs with the permissions of the user that installed it, so limit that user to only what is needed for deployment.

## Open questions

- Should the runner run as a dedicated `github-runner` user or as the existing `focus` user?
- Should the deploy step require `sudo` for writing to `/opt/focus/web`, or should that directory be owned by the runner user?
- How to handle runner updates automatically on the Pi?

## References

- GitHub Docs: "About self-hosted runners" — https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners
