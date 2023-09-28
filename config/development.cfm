<!--- Settings for development environment
	* Use this.config.#settingName# = "whatever value"; to define the setting. It will then set and be available as Application.config.#settingName#
	* You can also overwrite existing or set new TOP LEVEL settings, such as this.timezone = "Australia/Sydney";
--->
<cfscript>

// Use a longer session timeout on development environment (note: this app does not user session, so comment this out)
// this.sessionTimeout = createTimeSpan(0,8,0,0);

// Set the base app/server URL
if ( CGI.SERVER_PORT neq "80" and CGI.SERVER_PORT neq "8080" ) {
	this.config.serverUrl = "http://#CGI.SERVER_NAME#:#CGI.SERVER_PORT#/";
} else {
	this.config.serverUrl = "http://#CGI.SERVER_NAME#/";
}

// SMTP settings
this.config.smtpSettings = {
	"server" = "localhost",
	"port" = 1025,
	"username" = "",
	"password" = ""
};

// Proxy function settings
this.config.cfProxy = {};

this.config.cfProxy.useCfProxy = true; // Use this proxy app to relay CFHTTP calls? Set to false if you want to turn it off

this.config.cfProxy.cfProxyKey = "1234567890"; // The secret key for cf-proxy app/function
this.config.cfProxy.cfProxyHeaderNameForTargetURL = "X-Proxy-URL"; // The name of the header that contains the target URL
this.config.cfProxy.cfProxyHeaderNameForSecretKey = "X-Proxy-Secret"; // The name of the header that contains the secret key to use cf-proxy
this.config.cfProxy.cfProxyHeaderNameForTimeout = "X-Proxy-Timeout"; // The name of the header that contains the timeout value for cf-proxy making the http call

</cfscript>