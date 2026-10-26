@IsTest
private class CheckFdaLabelTest {

    private class LabelMock implements HttpCalloutMock {
        private Integer status;
        private String body;
        LabelMock(Integer status, String body) {
            this.status = status;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint().startsWith('callout:FDA_Lambda/label?drug='), 'Uses the Named Credential');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody(body);
            return res;
        }
    }

    private static CheckFdaLabel.Request request(String drug) {
        CheckFdaLabel.Request r = new CheckFdaLabel.Request();
        r.drug = drug;
        return r;
    }

    @IsTest
    static void returnsSummaryWhenLabelFound() {
        Test.setMock(HttpCalloutMock.class, new LabelMock(200,
            '{"drug":"metformin","labelEffectiveDate":"20250114","boxedWarning":"Lactic acidosis"}'));
        Test.startTest();
        List<CheckFdaLabel.Response> res = CheckFdaLabel.run(new List<CheckFdaLabel.Request>{ request('metformin') });
        Test.stopTest();
        Assert.areEqual(1, res.size());
        Assert.isTrue(res[0].summary.contains('2025-01-14'), res[0].summary);
        Assert.isTrue(res[0].summary.contains('Lactic acidosis'), res[0].summary);
    }

    @IsTest
    static void returnsNotFoundMessageOn404() {
        Test.setMock(HttpCalloutMock.class, new LabelMock(404, '{"error":"No FDA label found"}'));
        Test.startTest();
        List<CheckFdaLabel.Response> res = CheckFdaLabel.run(new List<CheckFdaLabel.Request>{ request('notadrug') });
        Test.stopTest();
        Assert.areEqual('No FDA label found for notadrug.', res[0].summary);
    }

    @IsTest
    static void handlesBlankDrugWithoutCallout() {
        List<CheckFdaLabel.Response> res = CheckFdaLabel.run(new List<CheckFdaLabel.Request>{ request('  ') });
        Assert.areEqual('Please provide a drug name.', res[0].summary);
    }

    @IsTest
    static void formatsDates() {
        Assert.areEqual('2024-03-09', CheckFdaLabel.formatDate('20240309'));
        Assert.areEqual('unknown', CheckFdaLabel.formatDate(null));
        Assert.areEqual('unknown', CheckFdaLabel.formatDate('2024'));
    }
}
