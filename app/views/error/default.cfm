<cfoutput>
<cfif structKeyExists(request,"exception")>
	<h1>Error 500 Internal Server Error</h1>
	<p><strong>Error Message:</strong> #request.exception.message#</p>
	<!--- Show debug info when in development environment --->
	<cfif application.config.mode eq "development">
		<h4>#request.exception.detail#</h4>
		<h3>Exception Detail</h3>
		<cfdump var="#request.exception#">
		<!---<cftry>
			<h3>RC</h3>
			<cfdump var="#rc#">
			<cfcatch type="any">
				<em>RC is not available</em>
			</cfcatch>
		</cftry>--->
		<h3>SESSION</h3>
		<!---<cfdump var="#session#">--->
		<p>No session used in this app</p>
		<h3>FORM</h3>
		<cfdump var="#form#">
		<h3>URL</h3>
		<cfdump var="#url#">
		<h3>CGI</h3>
		<cfdump var="#cgi#">
		<h3>APPLICATION.CONFIG</h3>
		<cfdump var="#application.config#">
	</cfif>
</cfif>
</cfoutput>