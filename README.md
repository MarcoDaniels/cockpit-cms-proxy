# Cockpit CMS Proxy

A simple proxy to fetch assets from [Cockpit CMS](https://getcockpit.com/).

---

Install [nix package manager](https://nixos.org/download.html) to manage dependencies.

Start a [nix shell](https://nixos.org/manual/nix/unstable/command-ref/nix-shell.html#options) with

```shell
nix-shell
```

Set the environment variables for your Cockpit CMS:

```shell
export COCKPIT_BASE_URL=https://example.com
export COCKPIT_API_TOKEN=1234
export ASSET_PATH_PATTERN=/images/pattern
export TARGET_HOST=localhost
export TARGET_PORT=8080
export PORT=8000
```

Run the proxy with the command:

```shell
startDev
```
