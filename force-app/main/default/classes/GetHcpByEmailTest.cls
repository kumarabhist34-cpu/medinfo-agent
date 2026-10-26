@IsTest
private class GetHcpByEmailTest {

    @TestSetup
    static void setup() {
        insert new List<Contact>{
            new Contact(FirstName = 'Asha', LastName = 'Rao', Email = 'asha.rao@cityhospital.example',
                        Licence_Number__c = 'MCI-100234'),
            new Contact(FirstName = 'Not', LastName = 'AnHcp', Email = 'buyer@vendor.example')
        };
    }

    private static GetHcpByEmail.Request request(String email) {
        GetHcpByEmail.Request r = new GetHcpByEmail.Request();
        r.email = email;
        return r;
    }

    @IsTest
    static void findsRegisteredHcpIgnoringCase() {
        List<GetHcpByEmail.Response> res = GetHcpByEmail.run(
            new List<GetHcpByEmail.Request>{ request('  Asha.Rao@CityHospital.example ') });
        Assert.isTrue(res[0].found);
        Assert.areEqual('Asha Rao', res[0].hcpName);
        Assert.isTrue(String.isNotBlank(res[0].contactId));
    }

    @IsTest
    static void ignoresContactsWithoutLicence() {
        List<GetHcpByEmail.Response> res = GetHcpByEmail.run(
            new List<GetHcpByEmail.Request>{ request('buyer@vendor.example') });
        Assert.isFalse(res[0].found);
    }

    @IsTest
    static void handlesBulkAndBlankInput() {
        List<GetHcpByEmail.Response> res = GetHcpByEmail.run(new List<GetHcpByEmail.Request>{
            request('asha.rao@cityhospital.example'), request(''), request('unknown@x.example')
        });
        Assert.areEqual(3, res.size());
        Assert.isTrue(res[0].found);
        Assert.isFalse(res[1].found);
        Assert.isFalse(res[2].found);
    }
}
