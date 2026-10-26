/**
 * Agent action: verifies a healthcare professional (HCP) by work email.
 * Matches against Contacts, which are kept clean by Data 360 identity resolution
 * (see data360/SETUP.md). Runs in user mode so the agent user's permissions apply.
 */
public with sharing class GetHcpByEmail {

    public class Request {
        @InvocableVariable(label='Email' description='The HCP\'s work email address' required=true)
        public String email;
    }

    public class Response {
        @InvocableVariable(label='Found' description='True when a registered HCP matches the email')
        public Boolean found = false;
        @InvocableVariable(label='Contact Id' description='Salesforce Contact Id of the HCP')
        public String contactId = '';
        @InvocableVariable(label='HCP Name' description='Full name of the HCP')
        public String hcpName = '';
    }

    @InvocableMethod(label='Verify HCP by Email'
                     description='Finds a registered healthcare professional by work email before answering product questions')
    public static List<Response> run(List<Request> requests) {
        Set<String> emails = new Set<String>();
        for (Request r : requests) {
            if (String.isNotBlank(r.email)) {
                emails.add(r.email.trim().toLowerCase());
            }
        }

        Map<String, Contact> byEmail = new Map<String, Contact>();
        if (!emails.isEmpty()) {
            for (Contact c : [
                SELECT Id, Name, Email
                FROM Contact
                WHERE Email IN :emails AND Licence_Number__c != null
                WITH USER_MODE
            ]) {
                byEmail.put(c.Email.toLowerCase(), c);
            }
        }

        List<Response> results = new List<Response>();
        for (Request r : requests) {
            Response resp = new Response();
            Contact match = String.isBlank(r.email) ? null : byEmail.get(r.email.trim().toLowerCase());
            if (match != null) {
                resp.found = true;
                resp.contactId = match.Id;
                resp.hcpName = match.Name;
            }
            results.add(resp);
        }
        return results;
    }
}
