/**
 * Agent action: records a possible adverse event and routes it to human specialists.
 * This is deliberately deterministic: every call creates a high-priority Case owned by
 * the Adverse_Events queue. The LLM decides only when the report details are collected;
 * it never decides whether a report reaches pharmacovigilance.
 */
public with sharing class CreateAdverseEventCase {

    @TestVisible
    private static final String QUEUE_NAME = 'Adverse_Events';

    public class Request {
        @InvocableVariable(label='Drug Name' description='Product the HCP mentioned' required=true)
        public String drugName;
        @InvocableVariable(label='Description' description='What happened, in the HCP\'s own words' required=true)
        public String description;
        @InvocableVariable(label='Contact Id' description='Verified HCP Contact Id, if known')
        public String contactId;
    }

    public class Response {
        @InvocableVariable(label='Case Number' description='Number of the adverse event case created')
        public String caseNumber;
    }

    @InvocableMethod(label='Create Adverse Event Case'
                     description='Logs a possible adverse event as a high-priority Case and routes it to the Adverse Events queue')
    public static List<Response> run(List<Request> requests) {
        Id queueId = queueId();
        List<Case> cases = new List<Case>();
        for (Request r : requests) {
            Case c = new Case(
                Subject = 'Possible adverse event: ' + r.drugName,
                Description = r.description,
                Drug_Name__c = r.drugName,
                Is_Adverse_Event__c = true,
                Priority = 'High',
                Origin = 'Web',
                Status = 'New'
            );
            if (String.isNotBlank(r.contactId)) {
                c.ContactId = r.contactId;
            }
            if (queueId != null) {
                c.OwnerId = queueId;
            }
            cases.add(c);
        }
        insert as user cases;

        Map<Id, Case> withNumbers = new Map<Id, Case>([SELECT Id, CaseNumber FROM Case WHERE Id IN :cases]);
        List<Response> results = new List<Response>();
        for (Case c : cases) {
            Response resp = new Response();
            resp.caseNumber = withNumbers.get(c.Id).CaseNumber;
            results.add(resp);
        }
        return results;
    }

    private static Id queueId() {
        List<Group> queues = [
            SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :QUEUE_NAME LIMIT 1
        ];
        return queues.isEmpty() ? null : queues[0].Id;
    }
}
