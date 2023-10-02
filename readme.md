# cfproxy

Lucee implementation of a http proxy. Inspired by Daniel McQuiston's [rest-proxy](https://github.com/danielmcq/rest-proxy) project

## Requirement

- CommandBox (version 5+ is recommended)
    - Lucee (version 4.5+ is recommended)

## Setup
- Add environment varialbe to set the app mode (production, testing, or development)
    - OPTION1: Add OS environment varialbe: `CFPROXY_ENV=development`
        - For Windows, see [here](https://docs.oracle.com/en/database/oracle/machine-learning/oml4r/1.5.1/oread/creating-and-modifying-environment-variables-on-windows.html)
        - For Mac & Linux see [here](https://blog.adamgamboa.dev/how-to-set-environment-variable-in-macos/)
            - Basically, add `export CFPROXY_ENV=development` to your `.zshrc` (if your shell type is zsh) or to your `.bashrc` (if your shell type is bash)
    - OPTION2: Change the value in `JVM` -> `args` -> `-Dau.com.centernet.cfproxy.environment=production` inside `/server.json` file
    - If nothing is set or changed, the app default is `production` mode
- Start the app with CommandBox using: `box server start`
- The app will be running at `http://localhost:65080`

## Usage

### Ask cfproxy to make a CFHTTP call

- Use action=**proxy.makeHttpRequest**
- Use header **X-Proxy-Secret** to pass the secret password to cfproxy, you can find it and change it in `/config` folder
- Use header **X-Proxy-URL** to specify the URL for cfproxy to make \<cfhttp\> request to
- Use header **X-Proxy-Timeout** to specify the cfproxy request timeout (default is 60s, if you expect the cfhttp call need longer time to finish, you can set a larger value with this header)

```
<cfhttp url="http://localhost:65080/index.cfm?action=proxy.makeHttpRequest" method="GET">
    <cfhttpparam type="header" name="X-Proxy-Secret" value="secret_password_set_in_your_config_file">
    <cfhttpparam type="header" name="X-Proxy-URL" value="https://official-joke-api.appspot.com/random_joke">
    <cfhttpparam type="header" name="X-Proxy-Timeout" value="60">
    <cfhttpparam type="header" name="User-Agent" value="Your application name">
</cfhttp>
<cfdump var="#CFHTTP#">
```
