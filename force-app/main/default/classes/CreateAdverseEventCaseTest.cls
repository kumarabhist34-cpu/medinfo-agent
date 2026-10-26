@IsTest
private class CreateAdverseEventCaseTest {

    private static CreateAdverseEventCase.Request request(String drug, String description, Id contactId) {
        CreateAdverseEventCase.Request r = new CreateAdverseEventCase.Request();
        r.drugName = drug;
        r.description = description;
        r.contactId = contactId;
        return r;
    }

    @IsTest
    static void createsHighPriorityCaseInQueue() {
        Contact hcp = new Contact(LastName = 'Rao', Email = 'asha.rao@cityhospital.example', Licence_Number__c = 'MCI-1');
        insert hcp;

        Test.startTest();
        List<CreateAdverseEventCase.Response> res = CreateAdverseEventCase.run(
            new List<CreateAdverseEventCase.Request>{
                request('metformin', 'Patient reported severe nausea after the first dose.', hcp.Id)
            });
        Test.stopTest();

        Case c = [SELECT CaseNumber, Priority, Is_Adverse_Event__c, Drug_Name__c, ContactId, OwnerId, Owner.Name
                  FROM Case WHERE CaseNumber = :res[0].caseNumber];
        Assert.areEqual('High', c.Priority);
        Assert.isTrue(c.Is_Adverse_Event__c);
        Assert.areEqual('metformin', c.Drug_Name__c);
        Assert.areEqual(hcp.Id, c.ContactId);

        List<Group> queue = [SELECT Id FROM Group WHERE Type = 'Queue'
                             AND DeveloperName = :CreateAdverseEventCase.QUEUE_NAME];
        if (!queue.isEmpty()) {
            Assert.areEqual(queue[0].Id, c.OwnerId, 'Case is routed to the Adverse Events queue');
        }
    }

    @IsTest
    static void handlesBulkWithoutContact() {
        List<CreateAdverseEventCase.Request> reqs = new List<CreateAdverseEventCase.Request>();
        for (Integer i = 0; i < 50; i++) {
            reqs.add(request('atorvastatin', 'Muscle pain report ' + i, null));
        }
        Test.startTest();
        List<CreateAdverseEventCase.Response> res = CreateAdverseEventCase.run(reqs);
        Test.stopTest();
        Assert.areEqual(50, res.size());
        Assert.areEqual(50, [SELECT COUNT() FROM Case WHERE Is_Adverse_Event__c = true]);
    }
}
