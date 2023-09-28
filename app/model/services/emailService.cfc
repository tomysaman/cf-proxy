component accessors="true" {

	public void function sendEmail(
		required string from,
		required string to,
		required string subject,
		string cc = '',
		string bcc = '',
		string textBody = '',
		string htmlBody = '',
		array attachments = [],
		string server = '',
		string port = 1025,
		string username = '',
		string password = ''
	) {
		var mailObj = new mail();
		mailObj.setType("text/html");
		mailObj.setFrom(arguments.from);
		mailObj.setTo(arguments.to);
		mailObj.setSubject(arguments.subject);
		mailObj.setCC(arguments.cc);
		mailObj.setBCC(arguments.bcc);
		mailObj.addPart( type="text", body=arguments.textBody );
		mailObj.addPart( type="html", charset="utf-8", body=arguments.htmlBody );
		if ( len(arguments.server) ) {
			mailObj.setServer(arguments.server);
		}
		if ( len(arguments.port) ) {
			mailObj.setPort(arguments.port);
		}
		if ( len(arguments.username) ) {
			mailObj.setUsername(arguments.username);
		}
		if ( len(arguments.password) ) {
			mailObj.setPassword(arguments.password);
		}
		for ( var attachment in arguments.attachments ) {
			if ( fileExists(attachment) ) {
				mailObj.addParam( file=attachment, type="text/plain", remove=false );
			}
		}
		mailObj.send();
	}

}