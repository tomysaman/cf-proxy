component accessors="true" {

	public void function setRequestTimeout( required numeric timeoutInSeconds ) hint="I set the request timeout for the request" {
		setting requesttimeout = arguments.timeoutInSeconds;
	}

}