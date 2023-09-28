component accessors=true {

	property name="fw";
	property name="beanFactory";
	property name="emailService";

	public void function before( struct rc={} ) {

	}

	public void function after( struct rc={} ) {

	}

	public void function default( struct rc={} ) {
		// Send error email if not in development environment
		if ( structKeyExists(request,"exception") ) {
			if ( application.environment neq "development" ) {
				var emailBody = '';
				savecontent variable="emailBody" {
					writeoutput("<h1>Error Message: #request.exception.message#</h1>");
					writeoutput("<h2>#request.exception.detail#</h2>");
					writedump(request.exception);
					//writeoutput("<h1>RC</h1>");
					//writedump(rc);
					writeoutput("<h1>SESSION</h1>");
					writeoutput("<em>Session is not enabled for this app</em>");
					//writedump(session);
					writeoutput("<h1>FORM</h1>");
					writedump(form);
					writeoutput("<h1>URL</h1>");
					writedump(url);
					writeoutput("<h1>CGI</h1>");
					writedump(cgi);
					//writeoutput("<h1>APPLICATION.CONFIG</h1>");
					//writedump(application.config);
				}
				emailService.sendEmail(
					server=application.config.smtpSettings.server,
					port=application.config.smtpSettings.port,
					username=application.config.smtpSettings.username,
					password=application.config.smtpSettings.password,
					from=application.config.systemEmails.error.from,
					to=application.config.systemEmails.error.to,
					subject=application.config.systemEmails.error.subject,
					htmlBody=emailBody
				);
			}
		}
	}

}