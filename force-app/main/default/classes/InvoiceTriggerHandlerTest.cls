@isTest
private class InvoiceTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        // Create a test account for invoice records
        Account testAccount = new Account(
            Name = 'Test Account for Invoice'
        );
        insert testAccount;

        // Create test users with different P21_Sales_Rep_ID__c patterns
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String timestamp = String.valueOf(System.now().getTime());

        // User with single salesperson ID
        User user1 = new User(
            FirstName = 'Test',
            LastName = 'User1',
            Email = 'testuser1' + timestamp + '@example.com',
            Username = 'testuser1' + timestamp + '@example.com.test',
            Alias = 'tus1',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            P21_Sales_Rep_ID__c = '1111',
            IsActive = true
        );

        // User with multiple semicolon-separated salesperson IDs
        User user2 = new User(
            FirstName = 'Test',
            LastName = 'User2',
            Email = 'testuser2' + timestamp + '@example.com',
            Username = 'testuser2' + timestamp + '@example.com.test',
            Alias = 'tus2',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            P21_Sales_Rep_ID__c = '2222;3333;4444',
            IsActive = true
        );

        // User with semicolon-separated IDs with spaces
        User user3 = new User(
            FirstName = 'Test',
            LastName = 'User3',
            Email = 'testuser3' + timestamp + '@example.com',
            Username = 'testuser3' + timestamp + '@example.com.test',
            Alias = 'tus3',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            P21_Sales_Rep_ID__c = '5555 ; 6666 ; 7777',
            IsActive = true
        );

        // Inactive user (should not be matched)
        User user4 = new User(
            FirstName = 'Test',
            LastName = 'User4',
            Email = 'testuser4' + timestamp + '@example.com',
            Username = 'testuser4' + timestamp + '@example.com.test',
            Alias = 'tus4',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            P21_Sales_Rep_ID__c = '9999',
            IsActive = false
        );

        insert new List<User>{ user1, user2, user3, user4 };
    }

    @isTest
    static void testSingleSalesPersonIdMatch() {
        User testUser = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '1111' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Invoice' LIMIT 1];

        Test.startTest();
        DUET__Invoice__c invoice = new DUET__Invoice__c(
            Sales_Rep__c = '1111',
            DUET__account__c = testAccount.Id
        );
        insert invoice;
        Test.stopTest();

        invoice = [SELECT Id, Sales_Rep__c, Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice.Id];
        System.assertEquals(testUser.Id, invoice.Sales_Rep_Name__c, 'Sales_Rep_Name__c should be populated with matching User');
    }

    @isTest
    static void testMultipleSalesPersonIdMatch() {
        User testUser = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '2222;3333;4444' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Invoice' LIMIT 1];

        Test.startTest();
        // Test matching the first ID in the semicolon-separated list
        DUET__Invoice__c invoice1 = new DUET__Invoice__c(
            Sales_Rep__c = '2222',
            DUET__account__c = testAccount.Id
        );
        insert invoice1;

        // Test matching the middle ID
        DUET__Invoice__c invoice2 = new DUET__Invoice__c(
            Sales_Rep__c = '3333',
            DUET__account__c = testAccount.Id
        );
        insert invoice2;

        // Test matching the last ID
        DUET__Invoice__c invoice3 = new DUET__Invoice__c(
            Sales_Rep__c = '4444',
            DUET__account__c = testAccount.Id
        );
        insert invoice3;
        Test.stopTest();

        invoice1 = [SELECT Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice1.Id];
        invoice2 = [SELECT Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice2.Id];
        invoice3 = [SELECT Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice3.Id];

        System.assertEquals(testUser.Id, invoice1.Sales_Rep_Name__c, 'Should match first ID in semicolon list');
        System.assertEquals(testUser.Id, invoice2.Sales_Rep_Name__c, 'Should match middle ID in semicolon list');
        System.assertEquals(testUser.Id, invoice3.Sales_Rep_Name__c, 'Should match last ID in semicolon list');
    }

    @isTest
    static void testSalesPersonIdWithSpaces() {
        User testUser = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '5555 ; 6666 ; 7777' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Invoice' LIMIT 1];

        Test.startTest();
        DUET__Invoice__c invoice = new DUET__Invoice__c(
            Sales_Rep__c = '6666',
            DUET__account__c = testAccount.Id
        );
        insert invoice;
        Test.stopTest();

        invoice = [SELECT Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice.Id];
        System.assertEquals(testUser.Id, invoice.Sales_Rep_Name__c, 'Should match ID even with spaces in User field');
    }

    @isTest
    static void testNoMatch() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Invoice' LIMIT 1];

        Test.startTest();
        DUET__Invoice__c invoice = new DUET__Invoice__c(
            Sales_Rep__c = '8888',
            DUET__account__c = testAccount.Id
        );
        insert invoice;
        Test.stopTest();

        invoice = [SELECT Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice.Id];
        System.assertEquals(null, invoice.Sales_Rep_Name__c, 'Sales_Rep_Name__c should be null when no match found');
    }

    @isTest
    static void testInactiveUserNotMatched() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Invoice' LIMIT 1];

        Test.startTest();
        DUET__Invoice__c invoice = new DUET__Invoice__c(
            Sales_Rep__c = '9999',
            DUET__account__c = testAccount.Id
        );
        insert invoice;
        Test.stopTest();

        invoice = [SELECT Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice.Id];
        System.assertEquals(null, invoice.Sales_Rep_Name__c, 'Inactive users should not be matched');
    }

    @isTest
    static void testBlankSalesRep() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Invoice' LIMIT 1];

        Test.startTest();
        DUET__Invoice__c invoice = new DUET__Invoice__c(
            Sales_Rep__c = '',
            DUET__account__c = testAccount.Id
        );
        insert invoice;
        Test.stopTest();

        invoice = [SELECT Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice.Id];
        System.assertEquals(null, invoice.Sales_Rep_Name__c, 'Sales_Rep_Name__c should be null when Sales_Rep__c is blank');
    }

    @isTest
    static void testUpdateInvoice() {
        User testUser1 = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '1111' LIMIT 1];
        User testUser2 = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '2222;3333;4444' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Invoice' LIMIT 1];

        // Insert invoice with first sales rep
        DUET__Invoice__c invoice = new DUET__Invoice__c(
            Sales_Rep__c = '1111',
            DUET__account__c = testAccount.Id
        );
        insert invoice;

        invoice = [SELECT Sales_Rep__c, Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice.Id];
        System.assertEquals(testUser1.Id, invoice.Sales_Rep_Name__c, 'Should initially match first user');

        Test.startTest();
        // Update to second sales rep
        invoice.Sales_Rep__c = '2222';
        update invoice;
        Test.stopTest();

        invoice = [SELECT Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice.Id];
        System.assertEquals(testUser2.Id, invoice.Sales_Rep_Name__c, 'Should update to match second user');
    }

    @isTest
    static void testBulkInsert() {
        User testUser1 = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '1111' LIMIT 1];
        User testUser2 = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '2222;3333;4444' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Invoice' LIMIT 1];

        List<DUET__Invoice__c> invoices = new List<DUET__Invoice__c>();

        // Create 200 invoices to test bulk processing
        for (Integer i = 0; i < 100; i++) {
            invoices.add(new DUET__Invoice__c(Sales_Rep__c = '1111', DUET__account__c = testAccount.Id));
            invoices.add(new DUET__Invoice__c(Sales_Rep__c = '2222', DUET__account__c = testAccount.Id));
        }

        Test.startTest();
        insert invoices;
        Test.stopTest();

        List<DUET__Invoice__c> insertedInvoices = [
            SELECT Sales_Rep__c, Sales_Rep_Name__c
            FROM DUET__Invoice__c
            WHERE Id IN :invoices
            ORDER BY Sales_Rep__c
        ];

        System.assertEquals(200, insertedInvoices.size(), 'Should insert all 200 invoices');

        Integer user1Matches = 0;
        Integer user2Matches = 0;

        for (DUET__Invoice__c inv : insertedInvoices) {
            if (inv.Sales_Rep__c == '1111') {
                System.assertEquals(testUser1.Id, inv.Sales_Rep_Name__c, 'Bulk insert should match user 1');
                user1Matches++;
            } else if (inv.Sales_Rep__c == '2222') {
                System.assertEquals(testUser2.Id, inv.Sales_Rep_Name__c, 'Bulk insert should match user 2');
                user2Matches++;
            }
        }

        System.assertEquals(100, user1Matches, 'Should have 100 invoices matched to user 1');
        System.assertEquals(100, user2Matches, 'Should have 100 invoices matched to user 2');
    }

    @isTest
    static void testClearLookupOnUpdate() {
        User testUser = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '1111' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Invoice' LIMIT 1];

        // Insert invoice with sales rep
        DUET__Invoice__c invoice = new DUET__Invoice__c(
            Sales_Rep__c = '1111',
            DUET__account__c = testAccount.Id
        );
        insert invoice;

        invoice = [SELECT Sales_Rep__c, Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice.Id];
        System.assertEquals(testUser.Id, invoice.Sales_Rep_Name__c, 'Should initially have user populated');

        Test.startTest();
        // Clear the sales rep
        invoice.Sales_Rep__c = '';
        update invoice;
        Test.stopTest();

        invoice = [SELECT Sales_Rep_Name__c FROM DUET__Invoice__c WHERE Id = :invoice.Id];
        System.assertEquals(null, invoice.Sales_Rep_Name__c, 'Should clear lookup when Sales_Rep__c is cleared');
    }
}
