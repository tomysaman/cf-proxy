<cfoutput>

<cfparam name="rc.pageTitle" default="#application.config.appName#">

<cfcontent reset="true"><!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8">
		<title>#rc.pageTitle#</title>
	</head>
	<body>
		<div class="container">
			#arguments.body#
		</div>
	</body>
</html></cfoutput>
