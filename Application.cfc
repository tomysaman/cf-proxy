/* Application.cfc for CFProxy project - using FW1 3.0.2 with Lucee 4.5 or up
	If you want to add logic to a CF lifecycle method, see below:
	- OnApplicationStart: Do it in setupApplication()
	- OnSessionStart: Do it in setupSession()
	- OnRequestStart: Do it in setupRequest()
	- OnRequest: DO NOT override
	- OnRequestEnd: Do it in setupResponse()
	- OnSessionEnd: Can override (actually no onSessionEnd in fw1)
	- OnApplicationEnd: Can override (actually no OnApplicationEnd in fw1)
	- onCFCRequest: Can override (actually no onCFCRequest in fw1) - probably won't have any reason to use this in fw1 app
	- onAbort: Can override (actually no onAbort in fw1)
	- onMissingTemplate: Can override (actually no onMissingTemplate in fw1) - probably won't have any reason to use this in fw1 app
	- onError: Can override, calling supper.onError() is optional
*/
component extends="lib.fw1.one" output="false" {

	// ************************ Application.cfc settings ************************
	// They can be set to different values base on the environment in setupEnvironment()

	this.appName = "CF Proxy";
	this.name = replace(lcase(this.appName)," ","-","all");

	// Timeout settings
	this.applicationTimeout = createTimeSpan(7,0,0,0);
	// We don't need user sessions
	this.sessionManagement = false;
	// this.sessionTimeout = createTimeSpan(0,1,0,0);
	this.requestTimeout = 60;

	// Other settings
	this.setClientCookies = true;
	this.setDomainCookies = false;
	this.locale = "English (Australian)"; // Lucee only
	this.timezone = "Australia/Sydney"; // Lucee only
	//this.compression = true; // Lucee only - Enable GZip compression.

	// Some security & compatibility settings
	this.scriptProtect = "all"; // all|none, or a combination of: form, url, cookie, cgi
	this.secureJSON = true; // Protection to JSON hijacking
	this.secureJSONPrefix = "//";
	this.xmlFeatures = {
		externalGeneralEntities = false, // Default is false
		secure = true, // Default is true
		disallowDoctypeDecl = false // Default is true, but XML with DTD will be blocked, so set it to false for more compatibility over security
	}

	this.webRoot = getDirectoryFromPath(getBaseTemplatePath()); // This is our htdocs/wwwroot folder, where Application.cfc and index.cfm are at
	this.appRoot = this.webRoot & "app/"; // This is our app folder where all controllers/models/beans/services are at

	// set up mappings
	this.mappings = {
		"/framework" = this.webRoot & "lib/fw1/",
		"/application" = this.appRoot
	};

	/* ************************ FW1 settings ************************ */
	variables.framework = {
		applicationKey = this.name & '_fw1',
		base = '/app',
		//action = 'action',
		//defaultSection = 'main',
		//defaultItem = 'default',
		usingSubsystems = false,
		home = 'main.default', // Default home action
		error = 'error.default', // Default error action
		generateSES = false, // if true, "/?action=main.about" becomes "/index.cfm/main/about"
		SESOmitIndex = false, // if true, "/?action=main.about" becomes "/main/about"
		diEngine = 'di1',
		diComponent = 'lib.fw1.ioc', // Path to DI/1 ioc.cfc
		diLocations = '/app/model', // Paths to fw1 model (beans and services) folders, this must be a web root relative path and must start with "/"
		//diConfig = { },
		cacheFileExists = false, // Cache the result of FileExists() calls to improve fw performance speeed (with this set to true, we will need to reload fw if we add any new cfc/view/layout files)
		//noLowerCase = false, // ALWAYS set this to false to enforce lower case on action url variable so it won't cause issue when we are on filename case sensitive OS
		unhandledPaths = '/admin,/api,/app,/assets,/common,/config,/css,/images,/js,/lib,/subsystems,/tests,/temp,/tools', // paths to excluded from being handled by fw1
		unhandledExtensions = 'cfc', // List of file extensions that FW/1 should not handle
		unhandledErrorCaught = false, // Set to true will have fw1's error handler to catch errors raised by unhandled requests (e.g. those generic CF errors that are outside of fw1's scope)
		//reload = 'reload', // fw reload url key
		//password = 'true', // fw reload url key's value/password => /?reload=#password#
		trace = false, // Display debug info at the end of display or not - Don't output any trace info in this app as it could mess up the output content (xml/json etc)
		reloadApplicationOnEveryRequest = false, // Set to true when in dev so don't need to call /?reload=1
		// Environment specific settings
		environments = {
			development = {
				// Development environment FW1 settings
				reloadApplicationOnEveryRequest = true
			},
			testing = {
				// Testing environment FW1 settings
			},
			production = {
				// Production environment FW1 settings
			}
		}
	};


	// ************************ Overriding FW1 Methods ************************

	// Note: getEnvironment() is called at the very beginning of OnApplicationStart(), OnSessionStart, and OnRequestStart()
	public string function getEnvironment() hint="Determine the environment and return a string in format of tier or tier:server - e.g. development, testing, production:win, production:mac" {
		// Return existing environment value, unless it hasn't been defined or we are reloading the app
		if ( isDefined("application.environment") AND not ( isDefined("URL.reload") && URL.reload ) ) {
			writeLog(file="app", text="Using environment from cache: application.environment = #application.environment#");
			return application.environment;
		}

		// Determine the environment
		local.javaSystem = createObject("java","java.lang.System");
		local.hostname = createObject("java","java.net.InetAddress").getLocalHost().getHostName();

		// OPTION 1: Using OS environment - Key name "CFPROXY_ENV"
		// Example: Put this in your MacOS .zprofile: "export CFPROXY_ENV=development"
		local.environmentVariableName = "CFPROXY_ENV";
		local.environmentVariableValue = local.javaSystem.getenv(local.environmentVariableName);
		if ( structKeyExists(local, "environmentVariableValue") and listFindNoCase("development,testing,production", local.environmentVariableValue) ) {
			writeLog(file="app", text="Setting environment from env var: #local.environmentVariableName# = #local.environmentVariableValue#");
			return local.environmentVariableValue;
		}

		// OPTION 2: Using Java system property - property name "au.com.tomy.cfproxy.environment"
		// Example: Put this in JVM config: "-Dau.com.tomy.cfproxy.environment=development"
		local.systemPropertyName = "au.com.tomy.cfproxy.environment";
		local.systemPropertyValue = local.javaSystem.getProperty(local.systemPropertyName);
		if ( structKeyExists(local, "systemPropertyValue") and listFindNoCase("development,testing,production", local.systemPropertyValue) ) {
			writeLog(file="app", text="Selecting environment from jvm property: #local.systemPropertyName# = #local.systemPropertyValue#");
			return local.systemPropertyValue;
		}

		// OPTION 3: Using computer name
		switch(local.hostname) {
			case 'dccf01':
			case 'dccf02':
			case 'dccf04':
				local.environmentSetByHostname = "production";
				break;
			case 'dccf03':
				local.environmentSetByHostname = "testing";
				break;
			case 'dev-pc-01':
			case 'it-pc-01':
			case 'support-pc-01':
			case 'DESKTOP-LUKAJSO': // Allen
			case 'DESKTOP-6UI11RC': // Aram
			case 'Tomys-Mac-mini.local':
				local.environmentSetByHostname = "development";
				break;
			default:
				// local.environmentSetByHostname = "production";
		}
		if ( isDefined("local.environmentSetByHostname") ) {
			writeLog(file="app", text="Selecting environment from hostname: #local.hostname# => #local.environmentSetByHostname#");
			return local.environmentSetByHostname;
		}

		// OPTION 4: Determine from URL
		// This option is not suitable for this app as it will be accessed by other production apps using http://localhost
		/* if ( findNoCase("dev.", CGI.SERVER_NAME) or findNoCase("local.", CGI.SERVER_NAME) or findNoCase("localhost", CGI.SERVER_NAME) or find("127.0.0.1", CGI.SERVER_NAME) ) {
			writeLog(file="app", text="Selecting environment bases on URL/domain => development");
			return "development";
		} else if ( findNoCase("staging.", CGI.SERVER_NAME) or findNoCase("stage.", CGI.SERVER_NAME) or or findNoCase("test.", CGI.SERVER_NAME) ) {
			writeLog(file="app", text="Selecting environment bases on URL/domain => testing");
			return "testing";
		} else {
			writeLog(file="app", text="Selecting environment bases on URL/domain => production");
			return "production";
		} */

		// DEAULT: If none of the above match, default environment to production
		writeLog(file="app", text="Selecting environment from default setting = production");
		return "production";
	}

	public void function setupEnvironment( string env ) hint="Can be used to provide additonal logic bases on the environemtn. This function is called during framework setup (after all framework settings are loaded into variables.framework scope)" {
		writelog(file="app", text="setupEnvironment() running - arguments.env = #arguments.env#");
		this.environment = arguments.env;
		// Environment based settings
		this.config = {};
		if ( arguments.env eq "development" ) {
			// Development environment settings
			include "config/development.cfm";
		} else if ( arguments.env eq "testing" ) {
			// Testing environment settings
			include "config/testing.cfm";
		} else {
			// Production environment settings
			include "config/production.cfm";
			// Can setup 301 redirects on production using fw1's routes system if needed, likes below:
			// arrayAppend( routes, { "/oldUrl" = "301:/newUrl" } )
		}
	}

	public void function setupApplication() hint="Application setup logic" {
		writelog(file="app", text="setupApplication() running");
		// Setup consts and settings
		application.environment = this.environment;
		application.serverOS = getServerOS();
		application.serverEngine = getServerEngine();
		application.config = {
			appName = this.appName,
			mode = this.environment,
			appRoot = this.appRoot,
			webRoot = this.webRoot,
			locale = this.locale,
			timezone = this.timezone,
			dateFormatStandard = "dd/mm/yyyy", // Standard CF date format
			dateFormatStandardJava = "dd/MM/yyyy", // Standard Java date format - used for LsParseDateTime(); Usually the month M must be in upper case
			dateFormatDatepicker = "dd/mm/yy", // The date picker JS date format - usually use yy instead of yyyy for full year
			dateFormatDisplay = "dd mmm yyyy", // Date format for displaying a date
			systemEmails = {
				"error" = { to="errors@yourdomain.com.au", subject="#this.appName# (#this.environment#) error", from="errors@yourdomain.com.au", fromName="errors@yourdomain.com.au" }
			},
			pw = "Centerne7" // A secret for hidden admin functions/pages
		};
		// Add environment based settings (they are in this.config are setup by setupEnvironment())
		structAppend( application.config, this.config, true );
		// Setup utilities
		application.utils = {
			nanoID = new lib.nanoId()
			//jwt = new lib.JsonWebTokens()
		};
		// Setup Java utilities
		/* application.javaUtils = {
			xxxxx = createObject("component", "lib.javaloader.JavaLoader").init( [expandPath("/lib/java/xxxxx.jar")] )
		} */
		// Reset cache & ORM (we are not using any of them so comment them out)
		// cacheRemove( arrayToList(cacheGetAllIds()) );
		// ormReload();
		application.config.initialisedAt = now();
		writelog(file="app", text="setupApplication() finished");
	}

	public void function setupSession() hint="Session start/setup logic" {
		// This app does not have user session
		/* session.user = {
			id = '',
			isLoggedIn = 0
		} */
	}

	/* public void function setupSubSystem ( required string subSystem ) hint="Called for each subsystem" {
		// WriteDump("setupSubSystem called");
	} */

	public void function setupRequest() hint="Setup logic to be executed before every requests" {
		request.requestID = application.utils.nanoID.generate();
		// Restart application vir url if needed
		if ( structKeyExists(url,"reload") ) {
			try {
				writelog(file="app", text="setupRequest() -> reloading app...");
				lock scope="application" timeout="30" type="exclusive" {
					super.onApplicationStart();
				}
			} catch(any e) {
				onError(e, "setupRequest_reloadApp");
				abort;
			}
		}
		// Force https
		/* if ( not isHttps() ) {
			var sslUrl = ("https://" & cgi.server_name & cgi.script_name & cgi.path_info & "?" & cgi.query_string );
			location(url=sslUrl, addtoken=false);
		} */
		// Trim form variables
		for (var formVar in FORM) {
			if ( not find(".",formVar) ) {
				form[formVar] = trim(form[formVar]);
			}
		}
	}

	public void function before( struct rc = {} ) hint="Similar to setupRequest(), but can access the rc scope. Setup any custom logic for the rc scope here" {

	}

	public void function after( struct rc = {} ) hint="Called after the controller item/method is executed" {

	}

	public void function setupView() hint="Called after controllers and services have completed but before any views are rendered" {

	}

	public void function setupResponse() hint="Called at the end of every requests, and right before redirection (if redirect() is used)" {
		// Show debug info on dev
		// Note: Don't output anything in the request before()/after()/setupView()/setupResponse()/layouts etc as this is a proxy app that any output can ruin the result content (such mess up the xml/json/binary content)
		/* if ( application.environment eq "development" ) {
			writeDump(var=rc, label="RC");
			//writeDump(var=form, label="FORM");
			//writeDump(var=session, label="SESSION");
			writeDump(var=application, label="APPLICATION");
		} */
	}

	/* public void function onMissingMethod( string method, struct missingMethodArguments ) hint="Can omit this, not really required for us" {
		WriteDump(method);
		WriteDump(missingMethodArguments);
	} */

	public string function onMissingView( struct rc = {} ) hint="Should be set to return some text/content to be used as a view (otherwise, by default fw1 throws an exception if a view is not found)" {
		// To prevent missingView from hidding the actual error, we check if there is any exception in request scope (which fw1 populates if there is an error), if there is then we call onError instead
		if ( structKeyExists(request,"exception") ) {
			onError(request.exception,"error_through_onMissingView");
			abort;
		}
		// Set 404 header
		var pcResponse = getPageContext().getResponse();
		pcResponse.setStatus(404);
		// Set 404 layout & content - note: setView() won't work here as fw has gone into the missingView stage
		setLayout("404.default");
		return view("404/default");
	}

	public void function onError( any exception, string eventName ) hint="On error method" {
		// Set 500 header
		var pcResponse = getPageContext().getResponse();
		pcResponse.setStatus(500);
		// Log error
		logError(argumentcollection=arguments);
		// If using subsystems, switch to show the subsystem's error layout/view bases on where the error is raised by changing the framework.error settings on the fly (this is safe, as it is in the variables scope, i.e. it is request based)
		//variables.framework.error = "#getSubsystem()#:error.default";
		super.onError( arguments.exception, arguments.eventName );
	}


	// ************************ Custom functions that you want to be available through variables.framework ************************

	public any function logError( any exception, string eventName ) {
		// If rootCause is there, it would be more useful
		if ( structKeyExists(arguments.exception, "rootCause") ) {
			local.exception = arguments.exception.rootCause;
		} else {
			local.exception = arguments.exception;
		}
		local.msg = "Error: #local.exception.message# | #local.exception.detail#";
		// Log the tagContext trace too (stacktrace of the request and the line numbers)
		if ( isDefined("local.exception.TagContext") AND isArray(local.exception.TagContext) ) {
			local.trace = "";
			for (var item in local.exception.TagContext) {
				local.thisTrace = listLast(item.Raw_Trace, "(");
				local.thisTrace = replace(local.thisTrace, ")", "", "all");
				if ( len(local.trace) ) {
					local.trace = local.trace & " <- ";
				}
				local.trace = local.trace & local.thisTrace;
			}
			local.msg = local.msg & " | #local.trace#";
		}
		writeLog(file="app", text="#local.msg#");
	}

	public any function setFormVars( struct rc={} ) hint="Copy the form variables into a structure under rc scope (so it will be easier to pass it around - especially when used in fw1's redirect function)" {
		rc.formVars = form;
		return rc;
	}

	public void function getFormVars( struct rc={} ) hint="Retreive the form variables stored in rc scope (by setFormVars function above) back to form scope" {
		if ( structKeyExists(rc, "formVars") ) {
			for (var formVar in rc.formVars) {
				if ( not find(".",formVar) ) {
					form[formVar] = rc.formVars[formVar];
				}
			}
		}
	}

	public boolean function isHttps() {
		if ( len(CGI.HTTPS) and listFindNoCase("Yes,On,True",CGI.HTTPS) ) {
			return true;
		} else if ( isBoolean(CGI.SERVER_PORT_SECURE) and CGI.SERVER_PORT_SECURE ) {
			return true;
		} else if ( len(CGI.SERVER_PORT) and CGI.SERVER_PORT eq "443" ) {
			return true;
		} else if ( structKeyExists(GetHttpRequestData().headers, "X-Forwarded-Proto") and GetHttpRequestData().headers["X-Forwarded-Proto"] eq "https" ) {
			return true;
		} else {
			return false;
		}
	}


	// ************************ Private functions for Application.cfc ************************

	private string function getServerOS() hint="Determine the OS" {
		var os = "";
		if ( isDefined("server.os.name") ) {
			os = server.os.name;
		}
		if ( findNoCase("linux", os) ) {
			os = "linux";
		} else if ( findNoCase("windows", os) ) {
			os = "win";
		} else if ( findNoCase("mac", os) ) {
			os = "mac";
		}
		return os;
	}

	private string function getServerEngine() hint="Determine if this app is running Lucee or AdobeCF" {
		var serverType = "";
		if ( structKeyExists(server,"lucee") and isStruct(server.lucee) ) {
			serverType = "lucee";
		} else if ( structKeyExists(server,"coldfusion") and isStruct(server.coldfusion) and structKeyExists(server.coldfusion,"productName") and findNoCase("lucee",server.coldfusion.productName) ) {
			serverType = "lucee";	
		} else {
			serverType = "coldfusion";
		}
		return serverType;
	}

	// Note: getCanonicalPath() is only available in Lucee; use this function if in CF
	private string function getCanonicalPathCF(required string rawPath) hint="CF implementation of getCanonicalPath() function" {
		var canonicalPath = createObject("java", "java.io.File").init(arguments.rawPath).getCanonicalPath();
		return canonicalPath;
	}

}