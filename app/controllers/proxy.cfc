/** Proxy
 * This controller functions as a proxy to make CFHTTP call for the caller and return the result to the caller
**/
component accessors=true {

	property name="fw";
	property name="beanFactory";
	property name="helperService";

	public void function before(required struct rc) {
		param name="arguments.rc.requestTimeout" type="numeric" default=60;

		// arguments.rc.eventTiming = { start = now() };

		writeLog(text="[#request.requestID#] proxy.cfc before(): setting request timeout to #arguments.rc.requestTimeout#", file="proxy");
		helperService.setRequestTimeout(arguments.rc.requestTimeout)
	}
	
	public void function after(required struct rc) {
		/* arguments.rc.eventTiming.end = now();
		arguments.rc.eventTiming.seconds = dateDiff('s', arguments.rc.eventTiming.start, arguments.rc.eventTiming.end);
		writeLog(text="[#request.requestID#] Request finished in #arguments.rc.eventTiming.seconds# s", file="proxy"); */
	}

	// ******************************************************************************* //
	// * Normal CFHTTP related proxy function *
	// ******************************************************************************* //

	// makeHttpRequest() - This is the main proxy function that makes the CFHTTP call for the caller while relaying the requests header/url/body. The it returns (render) the result content/headers back to caller
	public function makeHttpRequest() {
		var httpService = new http();
		var requestData = Duplicate(GetHttpRequestData());
		var responseHeaders = {};
		var responseBody = "";
		var responseStatus = 200;
		var responseMimeType = "text";
		var responseIsBinary = false;
		var httpResult = "";
		var httpDefaultTimeout = 60; // Default cfhttp timeout of the proxy call
		var headersNotToBeRelayed = "Host,Content-Length"; // The headers that we don't want to relayed from the caller to the destination
		var headersNotToBeSentBack = "status_code,explanation"; // The response headers that we don't want to pass back to caller (Note that those such as status_code would be set automatically when we set RepsponseStatus, if we pass it back again some versions of ColdFusion will make this header value a structure rather than a simple string, making an issue for the caller)
		var UrlParamsNotToBeRelayed = "action,requestTimeout"; // The URL params that we don't want to relayed from the caller to the destination (for example "action" as this function is being called by URL.action=proxy.makeHttpRequest)
		var headerName = "";
		var paramName = "";
		var pageContext = GetPageContext().getResponse();
		var UrlHeaderName = application.config.cfProxy.cfProxyHeaderNameForTargetURL;
		var keyHeaderName = application.config.cfProxy.cfProxyHeaderNameForSecretKey;
		var timeoutHeaderName = application.config.cfProxy.cfProxyHeaderNameForTimeout;

		requestData["UrlVars"] = Duplicate(URL);

		//writeLog(text="[#request.requestID#] requestData = #serializeJson(requestData)#", file="proxy");

		// If no destination URL is supplied, we are unable to make a cfhttp call, return 400 bad request
		if ( not (StructKeyExists(requestData.headers, UrlHeaderName) AND requestData.headers[UrlHeaderName] neq "") ) {
			variables.fw.renderData(
				type = "text",
				data = "400 Bad Request. #application.applicationName#: Must supply target URL in HTTP header [#UrlHeaderName#]",
				statusCode = 400
			);
			variables.fw.abortController();
		}

		var targetUrl = requestData.headers[UrlHeaderName];
		writeLog(text="[#request.requestID#] TargetUrl = #targetUrl#", file="proxy");

		// If secret key is not valid, return 401 unauthorised
		if ( not (StructKeyExists(requestData.headers, keyHeaderName) AND requestData.headers[keyHeaderName] eq application.config.cfProxy.cfProxyKey) ) {
			variables.fw.renderData(
				type = "text",
				data = "401 Unauthorized. #application.applicationName#: Secret key is inavlid.",
				statusCode = 401
			);
			variables.fw.abortController();
		}

		// If the proxy capability is disabled, don't make a proxy call, just redirect the request to the target URL
		if ( not application.config.cfProxy.useCfProxy) {
			header statuscode="302"; // Note: don't set "statustext" here as it could get carried over and replace the real status text of the destination URL
			header name="Location" value="#targetUrl#";
		}

		httpService.setUrl(targetUrl);
		httpService.setCharset("utf-8");
		// Set timeout value if it is being passed in as a header value, otherwise use a default setting
		if ( StructKeyExists(requestData.headers, timeoutHeaderName) ) {
			writeLog(text="[#request.requestID#] Set cfhttp timeout to #requestData.headers[timeoutHeaderName]#", file="proxy");
			httpService.setTimeout(requestData.headers[timeoutHeaderName]);
			// If a custom cfhttp request timeout is being used, use it as the request timeout
			//writeLog(text="[#request.requestID#] makeHttpRequest(): setting request timeout to same value as cfhttp timeout of #requestData.headers[timeoutHeaderName]#", file="proxy");
			//helperService.setRequestTimeout(requestData.headers[timeoutHeaderName]);
		} else {
			httpService.setTimeout(httpDefaultTimeout);
		}
		// Do the same method, fallback to GET if not present
		if ( StructKeyExists(requestData, "method") ) {
			httpService.setMethod(requestData.method);
		} else {
			httpService.setMethod("GET");
		}
		// Relay the headers (except those used by our proxy and those may cause issue if we relay them)
		StructDelete(requestData.headers, UrlHeaderName);
		StructDelete(requestData.headers, keyHeaderName);
		StructDelete(requestData.headers, timeoutHeaderName);
		for (headerName in requestData.headers) {
			if ( not listFindNoCase(headersNotToBeRelayed, headerName) AND isSimpleValue(requestData.headers[headerName]) ) {
				// writeLog(text="[#request.requestID#] Relay header #headerName#: #requestData.headers[headerName]#", file="proxy");
				httpService.addParam(type="header", name=headerName, value=requestData.headers[headerName]);
			}
		}
		// Relay the URL params
		for (paramName in requestData.UrlVars) {
			if ( not listFindNoCase(UrlParamsNotToBeRelayed, paramName) ) {
				// writeLog(text="[#request.requestID#] Relay URL param #paramName#: #requestData.UrlVars[paramName]#", file="proxy");
				httpService.addParam(type="URL", name=paramName, value=requestData.UrlVars[paramName]);
			}
		}
		// Relay the body content if present
		if ( StructKeyExists(requestData, "content") ) {
			httpService.addParam(type="body", value=requestData.content);
		}

		// Make the call and process the result
		httpResult = httpService.send().getPrefix();
		if ( StructKeyExists(httpResult, "statusCode") ) {
			writeLog(text="[#request.requestID#] httpResult.statusCode = #httpResult.statusCode#", file="proxy");
			responseStatus = val(httpResult.statusCode);
			// If Connection Failure happened, httpResult.statusCode will be something likes "Connection Failure. Status code unavailable." and will be 0 after val()
			if ( not isNumeric(responseStatus) OR responseStatus eq 0 ) {
				//responseStatus = "Connection Failure. Status code unavailable." // CF/Lucee will use this text as statusCode, but we cannot use that as FW1 won't accept non-numeric value
				// Return 502 if Connection Failure happened
				responseStatus = 502;
				responseBody = "Connection Failure";
			}
		} else {
			// No response status, so assume it is Connection Failure
			responseStatus = 502;
			responseBody = "Connection Failure";
		}
		if ( StructKeyExists( httpResult, "responseHeader" ) ) {
			for (headerName in httpResult.responseHeader) {
				responseHeaders[headerName] = httpResult.responseHeader[headerName];
			}
		}
		if ( StructKeyExists(httpResult, "fileContent") ) {
			try {
				//writeLog(text="[#request.requestID#] httpResult.fileContent: #httpResult.fileContent#", file="proxy");
				//responseBody = httpResult.fileContent.toString();
				responseBody = httpResult.fileContent;
			} catch (any e) {
				writeLog(text="[#request.requestID#] Error setting responseBody: #e.message# #e.detail#", file="proxy");
			}
		}
		// Return response headers
		for (headerName in responseHeaders) {
			if ( not listFindNoCase(headersNotToBeSentBack, headerName) AND isSimpleValue(responseHeaders[headerName]) ) {
				try {
					//writeLog(text="[#request.requestID#] Setting responseHeader #headerName#: #responseHeaders[headerName]#", file="proxy");
					pageContext.setHeader(headerName, responseHeaders[headerName]);
				} catch (any e) {
					writeLog(text="[#request.requestID#] Error setting responseHeader: #e.message# #e.detail#", file="proxy");
				}
			}
		}
		// Return status & content
		// pageContext.setStatus(responseStatus);
		// WriteOutput(responseBody);
		if ( StructKeyExists(httpResult, "mimetype") ) {
			if ( findNoCase("json", httpResult.mimetype) ) {
				responseMimeType = "json";
			} else if ( findNoCase("xml", httpResult.mimetype) ) {
				responseMimeType = "xml";
			} else if ( findNoCase("text", httpResult.mimetype) ) {
				responseMimeType = "text";
			} else if ( findNoCase("application", httpResult.mimetype) OR findNoCase("image", httpResult.mimetype) OR findNoCase("audio", httpResult.mimetype) OR findNoCase("video", httpResult.mimetype) ) {
				responseMimeType = "binary";
				if ( isBinary(responseBody) ) {
					responseIsBinary = true;
				}
			}
		}
		if ( isDefined("httpResult.mimetype") ) {
			writeLog(text="[#request.requestID#] httpResult.mimetype = #httpResult.mimetype#", file="proxy");
		}
		writeLog(text="[#request.requestID#] responseMimeType = #responseMimeType#", file="proxy");
		writeLog(text="[#request.requestID#] responseIsBinary = #responseIsBinary#", file="proxy");

		variables.fw.renderData(
			type = responseMimeType,
			data = responseBody,
			statusCode = responseStatus,
			outputAsBinary = responseIsBinary
		);

		// Abort the process - this has the benefit to avoid sending any additional output to mess up the xml/json content, but our after() won't run in this case
		variables.fw.abortController();
	}

}