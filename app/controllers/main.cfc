component accessors=true {

	property name="fw";
	property name="beanFactory";

	public void function before( struct rc={} ) {

	}

	public void function after( struct rc={} ) {

	}

	public void function default( struct rc={} ) {
		// This is the default public action, just don't do anything and don't show anything (the main proxy logic is in the proxy.cfc controller)
	}

}