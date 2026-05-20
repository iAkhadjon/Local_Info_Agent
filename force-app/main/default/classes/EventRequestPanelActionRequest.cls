global class EventRequestPanelActionRequest {
    @InvocableVariable(label='User Message' description='Original user request or prompt, if available' required=false)
    global String userMessage;

    @InvocableVariable(label='Default Subject' description='Optional subject inferred by the agent' required=false)
    global String defaultSubject;
}
