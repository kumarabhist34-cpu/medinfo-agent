/**
 * Agent action: returns the latest FDA label revision date and boxed warning for a drug.
 * Calls an AWS Lambda function (behind API Gateway) through the FDA_Lambda Named Credential.
 * The Atlas Reasoning Engine reads the label and description below to decide when to call it.
 */
public with sharing class CheckFdaLabel {

    public class Request {
        @InvocableVariable(label='Drug Name' description='Generic drug name, for example metformin' required=true)
        public String drug;
    }

    public class Response {
        @InvocableVariable(label='Label Summary' description='Latest FDA label revision date and boxed warning, or a not-found message')
        public String summary;
    }

    @InvocableMethod(label='Check Latest FDA Label'
                     description='Returns the latest FDA label revision date and boxed warning for a generic drug name')
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request r : requests) {
            Response resp = new Response();
            resp.summary = lookup(r.drug);
            results.add(resp);
        }
        return results;
    }

    private static String lookup(String drug) {
        if (String.isBlank(drug)) {
            return 'Please provide a drug name.';
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:FDA_Lambda/label?drug=' + EncodingUtil.urlEncode(drug.trim(), 'UTF-8'));
        req.setMethod('GET');
        req.setTimeout(10000);

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                return 'No FDA label found for ' + drug + '.';
            }
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String effective = formatDate((String) body.get('labelEffectiveDate'));
            String boxed = (String) body.get('boxedWarning');
            return 'Latest FDA label for ' + drug + ' is effective ' + effective
                + '. Boxed warning: ' + (String.isBlank(boxed) ? 'None' : boxed);
        } catch (Exception e) {
            return 'The FDA label service is unavailable right now. Please try again later.';
        }
    }

    /** openFDA returns dates as YYYYMMDD; show them as YYYY-MM-DD. */
    @TestVisible
    private static String formatDate(String raw) {
        if (String.isBlank(raw) || raw.length() != 8) {
            return 'unknown';
        }
        return raw.substring(0, 4) + '-' + raw.substring(4, 6) + '-' + raw.substring(6, 8);
    }
}
